static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3454[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3758 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3758.x >= cbFI_DisplaySize.x, _3758.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3758] = float4(r_present_backbuffer.Load(int3(_3758, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3758] = float4(r_current_interpolation_source.Load(int3(_3758, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4174 = (float2(_3758) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4185 = int2(floor(_4174 * float2(cbFI_MvDepthLaneSize)));
        int2 _4190 = int2(floor(_4174 * float2(cbFI_FlowLaneSize)));
        float4 _6237 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4174 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6243 = r_warped_filled_flow_tm1.Load(int3(_4190, 0)).xy;
        float2 _6249 = r_warped_filled_motion_tp1.Load(int3(_4185, 0)).xy;
        bool _6271 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10502;
        if (_6271)
        {
            float _6284 = ((2.0f * _4174.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10502 = float2(atan(_6284) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4174.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6284 * _6284))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10502 = _4174;
        }
        bool _4211 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10523;
        bool _10544;
        int2 _10555;
        float3 _12061;
        if (_4211)
        {
            float _10504;
            float _10506;
            _10506 = 2.0f;
            _10504 = -1.0f;
            uint _3822[9];
            float _12514;
            float _12517;
            for (int _10503 = 0; _10503 < 9; _10506 = _12517, _10504 = _12514, _10503++)
            {
                _3822[_10503] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4185 + int2((_10503 % 3) - 1, (_10503 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3822[_10503] != 0u)
                {
                    float _12509;
                    if (_3822[_10503] == 0u)
                    {
                        _12509 = -1.0f;
                    }
                    else
                    {
                        _12509 = float((_3822[_10503] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12517 = min(_10506, _12509);
                    _12514 = max(_10504, _12509);
                }
                else
                {
                    _12517 = _10506;
                    _12514 = _10504;
                }
            }
            float _4257 = float(_10504 >= 0.0f);
            float3 _10289 = 0.0f.xxx;
            _10289.y = _4257;
            float2 _10524;
            bool _10545;
            int2 _10556;
            float3 _12062;
            if ((_10504 - _10506) > 0.0199999995529651641845703125f)
            {
                float _10512;
                int2 _10513;
                float2 _10514;
                int2 _10516;
                float2 _10522;
                _10522 = _6249;
                _10516 = _4185;
                _10514 = _6249;
                _10513 = _4185;
                _10512 = -1.0f;
                float _12522;
                int2 _12526;
                float2 _12537;
                int2 _12548;
                float2 _12581;
                float _12628;
                int _10511 = 0;
                float _12490 = 1000000000.0f;
                for (; _10511 < 9; _12490 = _12628, _10522 = _12581, _10516 = _12548, _10514 = _12537, _10513 = _12526, _10512 = _12522, _10511++)
                {
                    if (_3822[_10511] == 0u)
                    {
                        _12628 = _12490;
                        _12581 = _10522;
                        _12548 = _10516;
                        _12537 = _10514;
                        _12526 = _10513;
                        _12522 = _10512;
                        continue;
                    }
                    int2 _4292 = clamp(_4185 + int2((_10511 % 3) - 1, (_10511 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6359 = _3822[_10511] & 2147483647u;
                    uint _6391 = uint(max((int((_6359 >> 16u) & 15u) - 6), 0));
                    float2 _4298 = (float2(float((1 - (2 * int((_6359 >> 15u) & 1u))) * int(((_6359 >> uint(7)) & 127u) << _6391)), float((1 - (2 * int((_6359 >> 14u) & 1u))) * int((_6359 & 127u) << _6391))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12476;
                    if (_3822[_10511] == 0u)
                    {
                        _12476 = -1.0f;
                    }
                    else
                    {
                        _12476 = float((_3822[_10511] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4303 = _12476 - 0.100000001490116119384765625f;
                    float2 _12477;
                    if (_6271)
                    {
                        float2 _6468 = clamp((((_10502 + (_4298 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6471 = tan(_6468.x);
                        _12477 = (float2(_6471 / cbFI_DeviceToViewDepth.z, (tan(_6468.y) * sqrt(1.0f + (_6471 * _6471))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12477 = _10502 + (_4298 * cbFI_Timestep);
                    }
                    float _4310 = cbFI_Timestep - 1.0f;
                    float2 _12478;
                    if (_6271)
                    {
                        float2 _6539 = clamp((((_10502 + (_4298 * _4310)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6542 = tan(_6539.x);
                        _12478 = (float2(_6542 / cbFI_DeviceToViewDepth.z, (tan(_6539.y) * sqrt(1.0f + (_6542 * _6542))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12478 = _10502 + (_4298 * _4310);
                    }
                    bool _6575 = all(bool2(_12477.x > 0.0f.xx.x, _12477.y > 0.0f.xx.y));
                    bool _6581;
                    if (_6575)
                    {
                        _6581 = all(bool2(_12477.x < 1.0f.xx.x, _12477.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6581 = _6575;
                    }
                    float _12481;
                    if (_6581)
                    {
                        uint _6588_dummy_parameter;
                        _12481 = max((_4303 - (log(((r_depth_tm1.Load(int3(int2(floor(_12477 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6588_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12481 = 0.0f;
                    }
                    bool _6618 = all(bool2(_12478.x > 0.0f.xx.x, _12478.y > 0.0f.xx.y));
                    bool _6624;
                    if (_6618)
                    {
                        _6624 = all(bool2(_12478.x < 1.0f.xx.x, _12478.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6624 = _6618;
                    }
                    float _12482;
                    if (_6624)
                    {
                        uint _6631_dummy_parameter;
                        _12482 = _12481 + max((_4303 - (log(((r_depth_tp1.Load(int3(int2(floor(_12478 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6631_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12482 = _12481;
                    }
                    float _12523;
                    int2 _12527;
                    float2 _12538;
                    int2 _12549;
                    float2 _12582;
                    float _12629;
                    if (_12482 == 0.0f)
                    {
                        bool _4345 = _4303 > _10512;
                        bool2 _12637 = _4345.xx;
                        _12629 = _12490;
                        _12582 = float2(_12637.x ? _4298.x : _10522.x, _12637.y ? _4298.y : _10522.y);
                        _12549 = int2(_12637.x ? _4292.x : _10516.x, _12637.y ? _4292.y : _10516.y);
                        _12538 = _10514;
                        _12527 = _10513;
                        _12523 = _4345 ? _4303 : _10512;
                    }
                    else
                    {
                        bool _4354 = _12482 < _12490;
                        bool2 _12633 = _4354.xx;
                        _12629 = _4354 ? _12482 : _12490;
                        _12582 = _10522;
                        _12549 = _10516;
                        _12538 = float2(_12633.x ? _4298.x : _10514.x, _12633.y ? _4298.y : _10514.y);
                        _12527 = int2(_12633.x ? _4292.x : _10513.x, _12633.y ? _4292.y : _10513.y);
                        _12523 = _10512;
                    }
                    _12628 = _12629;
                    _12581 = _12582;
                    _12548 = _12549;
                    _12537 = _12538;
                    _12526 = _12527;
                    _12522 = _12523;
                }
                bool _4366 = _10512 < 0.0f;
                bool2 _12643 = _4366.xx;
                int2 _12646 = int2(_12643.x ? _10513.x : _10516.x, _12643.y ? _10513.y : _10516.y);
                _12062 = float3(1.0f, _4257, float(any(bool2(_12646.x != _4185.x, _12646.y != _4185.y))));
                _10556 = _12646;
                _10545 = _4366 ? false : true;
                _10524 = float2(_12643.x ? _10514.x : _10522.x, _12643.y ? _10514.y : _10522.y);
            }
            else
            {
                _12062 = _10289;
                _10556 = _4185;
                _10545 = false;
                _10524 = _6249;
            }
            _12061 = _12062;
            _10555 = _10556;
            _10544 = _10545;
            _10523 = _10524;
        }
        else
        {
            _12061 = 0.0f.xxx;
            _10555 = _4185;
            _10544 = false;
            _10523 = _6249;
        }
        float2 _10525;
        if (_6271)
        {
            float2 _6696 = clamp((((_10502 + (_10523 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6699 = tan(_6696.x);
            _10525 = (float2(_6699 / cbFI_DeviceToViewDepth.z, (tan(_6696.y) * sqrt(1.0f + (_6699 * _6699))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10525 = _10502 + (_10523 * cbFI_Timestep);
        }
        float _4389 = cbFI_Timestep - 1.0f;
        float2 _10527;
        if (_6271)
        {
            float2 _6767 = clamp((((_10502 + (_10523 * _4389)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6770 = tan(_6767.x);
            _10527 = (float2(_6770 / cbFI_DeviceToViewDepth.z, (tan(_6767.y) * sqrt(1.0f + (_6770 * _6770))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10527 = _10502 + (_10523 * _4389);
        }
        float _4394 = -cbFI_Timestep;
        float2 _10528;
        if (_6271)
        {
            float2 _6838 = clamp((((_10502 + (_6243 * _4394)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6841 = tan(_6838.x);
            _10528 = (float2(_6841 / cbFI_DeviceToViewDepth.z, (tan(_6838.y) * sqrt(1.0f + (_6841 * _6841))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10528 = _10502 + (_6243 * _4394);
        }
        float _4399 = 1.0f - cbFI_Timestep;
        float2 _10529;
        if (_6271)
        {
            float2 _6909 = clamp((((_10502 + (_6243 * _4399)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6912 = tan(_6909.x);
            _10529 = (float2(_6912 / cbFI_DeviceToViewDepth.z, (tan(_6909.y) * sqrt(1.0f + (_6912 * _6912))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10529 = _10502 + (_6243 * _4399);
        }
        float4 _6947 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10525, 0.0f);
        float3 _6948 = _6947.xyz;
        float4 _6955 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10527, 0.0f);
        float3 _6956 = _6955.xyz;
        float4 _6963 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10528, 0.0f);
        float3 _6964 = _6963.xyz;
        float4 _6971 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10529, 0.0f);
        float3 _6972 = _6971.xyz;
        float4 _6986 = exp(_6237 - max(max(max(_6237.x, _6237.y), _6237.z), _6237.w).xxxx);
        float4 _6993 = _6986 / (dot(_6986, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4418 = _4211 && (!_10544);
        bool _4427;
        if (_4418)
        {
            _4427 = (_6993.z + _6993.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4427 = _4418;
        }
        bool _4438;
        if (_4427)
        {
            _4438 = length((_10528 - _10525) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4438 = _4427;
        }
        bool _10568;
        if (_4438)
        {
            uint4 _7012 = r_warped_motion_qdata_tp1.Load(int3(_10555, 0));
            uint _7013 = _7012.x;
            bool _10571;
            if (_7013 != 0u)
            {
                float _10557;
                if (_7013 == 0u)
                {
                    _10557 = -1.0f;
                }
                else
                {
                    _10557 = float((_7013 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4448 = _10557 - 0.12000000476837158203125f;
                bool _7032 = all(bool2(_10528.x > 0.0f.xx.x, _10528.y > 0.0f.xx.y));
                bool _7038;
                if (_7032)
                {
                    _7038 = all(bool2(_10528.x < 1.0f.xx.x, _10528.y < 1.0f.xx.y));
                }
                else
                {
                    _7038 = _7032;
                }
                bool _4458;
                if (_7038)
                {
                    uint _7045_dummy_parameter;
                    _4458 = (log(((r_depth_tm1.Load(int3(int2(floor(_10528 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7045_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4448;
                }
                else
                {
                    _4458 = _7038;
                }
                bool _4472;
                if (!_4458)
                {
                    bool _7075 = all(bool2(_10529.x > 0.0f.xx.x, _10529.y > 0.0f.xx.y));
                    bool _7081;
                    if (_7075)
                    {
                        _7081 = all(bool2(_10529.x < 1.0f.xx.x, _10529.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7081 = _7075;
                    }
                    bool _4470;
                    if (_7081)
                    {
                        uint _7088_dummy_parameter;
                        _4470 = (log(((r_depth_tp1.Load(int3(int2(floor(_10529 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7088_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4448;
                    }
                    else
                    {
                        _4470 = _7081;
                    }
                    _4472 = _4470;
                }
                else
                {
                    _4472 = _4458;
                }
                _10571 = _4472;
            }
            else
            {
                _10571 = false;
            }
            _10568 = _10571;
        }
        else
        {
            _10568 = false;
        }
        bool _4477 = _10544 || _10568;
        bool _4482;
        if (_4477)
        {
            bool _7118 = all(bool2(_10525.x > 0.0f.xx.x, _10525.y > 0.0f.xx.y));
            bool _7124;
            if (_7118)
            {
                _7124 = all(bool2(_10525.x < 1.0f.xx.x, _10525.y < 1.0f.xx.y));
            }
            else
            {
                _7124 = _7118;
            }
            _4482 = _7124;
        }
        else
        {
            _4482 = _4477;
        }
        bool _4487;
        if (_4482)
        {
            bool _7129 = all(bool2(_10527.x > 0.0f.xx.x, _10527.y > 0.0f.xx.y));
            bool _7135;
            if (_7129)
            {
                _7135 = all(bool2(_10527.x < 1.0f.xx.x, _10527.y < 1.0f.xx.y));
            }
            else
            {
                _7135 = _7129;
            }
            _4487 = _7135;
        }
        else
        {
            _4487 = _4482;
        }
        float4 _10665;
        if (_4487)
        {
            float _4490 = _6993.x;
            float _4492 = _6993.y;
            float _4493 = _4490 + _4492;
            float _4498 = _6993.z + _6993.w;
            float _10586;
            if (_4493 > 0.001000000047497451305389404296875f)
            {
                _10586 = _4490 / _4493;
            }
            else
            {
                _10586 = _4399;
            }
            _10665 = float4(_4490 + (_4498 * _10586), _4492 + (_4498 * (1.0f - _10586)), 0.0f, 0.0f);
        }
        else
        {
            _10665 = _6993;
        }
        bool _7163 = (cbFI_pad0 & 1024u) != 0u;
        bool _7139 = !_7163;
        bool _7140 = !_7139;
        bool _7157;
        if (_7140)
        {
            _7157 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10555.y * cbFI_MvDepthLaneSize.x) + _10555.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _7157 = _7139;
        }
        bool _7189;
        if (_7140)
        {
            _7189 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4190.y * cbFI_FlowLaneSize.x) + _4190.x)) * 4 + 0) != 0u;
        }
        else
        {
            _7189 = _7139;
        }
        float _4533 = float(_7189);
        bool _10678;
        float4 _10709;
        float3 _11854;
        if (_7163)
        {
            bool _4543;
            if (_7157)
            {
                _4543 = all(bool2(_10525.x > 0.0f.xx.x, _10525.y > 0.0f.xx.y));
            }
            else
            {
                _4543 = _7157;
            }
            bool _4549;
            if (_4543)
            {
                _4549 = all(bool2(_10525.x < 1.0f.xx.x, _10525.y < 1.0f.xx.y));
            }
            else
            {
                _4549 = _4543;
            }
            bool _4556;
            if (_7157)
            {
                _4556 = all(bool2(_10527.x > 0.0f.xx.x, _10527.y > 0.0f.xx.y));
            }
            else
            {
                _4556 = _7157;
            }
            bool _4562;
            if (_4556)
            {
                _4562 = all(bool2(_10527.x < 1.0f.xx.x, _10527.y < 1.0f.xx.y));
            }
            else
            {
                _4562 = _4556;
            }
            bool _4569;
            if (_7189)
            {
                _4569 = all(bool2(_10528.x > 0.0f.xx.x, _10528.y > 0.0f.xx.y));
            }
            else
            {
                _4569 = _7189;
            }
            bool _4575;
            if (_4569)
            {
                _4575 = all(bool2(_10528.x < 1.0f.xx.x, _10528.y < 1.0f.xx.y));
            }
            else
            {
                _4575 = _4569;
            }
            bool _4582;
            if (_7189)
            {
                _4582 = all(bool2(_10529.x > 0.0f.xx.x, _10529.y > 0.0f.xx.y));
            }
            else
            {
                _4582 = _7189;
            }
            bool _4588;
            if (_4582)
            {
                _4588 = all(bool2(_10529.x < 1.0f.xx.x, _10529.y < 1.0f.xx.y));
            }
            else
            {
                _4588 = _4582;
            }
            bool _4590 = !_7157;
            if (_4590)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7231;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7231);
                }
            }
            bool _4595 = !_7189;
            if (_4595)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7241;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7241);
                }
            }
            if (_7157 && _4595)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7251;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7251);
                }
            }
            if (_4590 && _7189)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7261;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7261);
                }
            }
            float _4614 = float(_4549);
            float _4616 = float(_4562);
            bool _4619 = _4575 && _4588;
            float _10620;
            if (_4619)
            {
                _10620 = 1.0f;
            }
            else
            {
                _10620 = (_4575 || _4588) ? 0.5f : 0.0f;
            }
            bool _10625;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4549)) && (!_4562))
            {
                bool _4649;
                if (_4619)
                {
                    float _10623;
                    do
                    {
                        bool _7345 = all(bool2(_10528.x > 0.0f.xx.x, _10528.y > 0.0f.xx.y));
                        bool _7351;
                        if (_7345)
                        {
                            _7351 = all(bool2(_10528.x < 1.0f.xx.x, _10528.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7351 = _7345;
                        }
                        bool _7282 = !_7351;
                        bool _7289;
                        if (!_7282)
                        {
                            bool _7356 = all(bool2(_10529.x > 0.0f.xx.x, _10529.y > 0.0f.xx.y));
                            bool _7362;
                            if (_7356)
                            {
                                _7362 = all(bool2(_10529.x < 1.0f.xx.x, _10529.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7362 = _7356;
                            }
                            _7289 = !_7362;
                        }
                        else
                        {
                            _7289 = _7282;
                        }
                        if (_7289)
                        {
                            _10623 = 0.0f;
                            break;
                        }
                        uint _7369_dummy_parameter;
                        uint _7385_dummy_parameter;
                        float4 _7310 = mul(float4((float2(_10528.x, 1.0f - _10528.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10528 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7369_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7312 = _7310.w;
                        if (abs(_7312) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10623 = 0.0f;
                            break;
                        }
                        float _7323 = abs(cbFI_DeviceToViewDepth.y / ((_7310.z / _7312) - cbFI_DeviceToViewDepth.x));
                        float _7326 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10529 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7385_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10623 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7323 - _7326) / max(max(_7323, _7326), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4649 = _10623 >= 0.5f;
                }
                else
                {
                    _4649 = _4619;
                }
                bool _4657;
                if (_4649)
                {
                    _4657 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4657 = _4649;
                }
                bool _10626;
                if (_4657)
                {
                    uint _7435_dummy_parameter;
                    float2 _10624;
                    do
                    {
                        float _7461 = 1.0f - _10528.y;
                        float4 _7472 = mul(float4((float2(_10528.x, _7461) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10528 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7435_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7474 = _7472.w;
                        if (!(_7474 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10624 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7487 = ((_7472.xy / _7474.xx) + 1.0f.xx) * 0.5f;
                        _10624 = float2(_7487.x - _10528.x, _7461 - _7487.y);
                        break;
                    } while(false);
                    float2 _4670 = float2(cbFI_DisplaySize);
                    _10626 = length(((_10528 + _10624) - _10529) * _4670) <= ((0.100000001490116119384765625f * length(_10624 * _4670)) + 8.0f);
                }
                else
                {
                    _10626 = _4649;
                }
                _10625 = _10626;
            }
            else
            {
                _10625 = true;
            }
            bool _4684 = !_10625;
            bool _12647 = _4684 ? false : _4588;
            bool _12648 = _4684 ? false : _4575;
            bool _10679;
            float4 _10710;
            if (!(((_4549 && _4562) && _12648) && _12647))
            {
                float4 _4706 = _10665 * float4(_4614, _4616, float(_12648), float(_12647));
                float _4708 = dot(_4706, 1.0f.xxxx);
                bool _4711 = !(_4708 > 0.0f);
                float4 _10711;
                if (!_4711)
                {
                    _10711 = _4706 / _4708.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7509;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7509);
                    }
                    _10711 = 0.0f.xxxx;
                }
                _10710 = _10711;
                _10679 = _4711;
            }
            else
            {
                _10710 = _10665;
                _10679 = false;
            }
            _11854 = float3(_4614, _4616, _10620);
            _10709 = _10710;
            _10678 = _10679;
        }
        else
        {
            _11854 = float3(float(_7157), _4533, 0.0f);
            _10709 = _10665;
            _10678 = false;
        }
        bool _4729 = !_10678;
        float4 _10773;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4729)
        {
            float _4736 = _10709.x + _10709.y;
            float4 _10774;
            if (_4736 > 0.001000000047497451305389404296875f)
            {
                _10774 = float4(_10709.x / _4736, _10709.y / _4736, 0.0f, 0.0f);
            }
            else
            {
                _10774 = float4(_4399, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10773 = _10774;
        }
        else
        {
            _10773 = _10709;
        }
        float4 _10930;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4729) && _7157)
        {
            float _10768;
            do
            {
                uint4 _7649 = r_warped_motion_qdata_tp1.Load(int3(_10555, 0));
                uint _7650 = _7649.x;
                if (_7650 != 0u)
                {
                    float _10767;
                    if (_7650 == 0u)
                    {
                        _10767 = -1.0f;
                    }
                    else
                    {
                        _10767 = float((_7650 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10768 = _10767;
                    break;
                }
                int _10750;
                uint _10751;
                _10751 = _7650;
                _10750 = -1;
                uint _10766;
                for (; _10750 <= 1; _10751 = _10766, _10750++)
                {
                    _10766 = _10751;
                    for (int _10764 = -1; _10764 <= 1; )
                    {
                        _10766 = max(_10766, r_warped_motion_qdata_tp1.Load(int3(clamp(_10555 + int2(_10764, _10750), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10764++;
                        continue;
                    }
                }
                if (_10751 != 0u)
                {
                    float _10763;
                    if (_10751 == 0u)
                    {
                        _10763 = -1.0f;
                    }
                    else
                    {
                        _10763 = float((_10751 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10768 = _10763;
                    break;
                }
                uint _10753;
                _10753 = 4294967295u;
                uint _12618;
                for (int _10752 = 0; _10752 < 8; _10753 = _12618, _10752++)
                {
                    int _10756 = 0;
                    for (;;)
                    {
                        if (_10756 < 5)
                        {
                            int2 _7600 = _10555 + (_1093[_10752] * _1102[_10756].xx);
                            bool _7603 = any(bool2(_7600.x < int2(0, 0).x, _7600.y < int2(0, 0).y));
                            bool _7611;
                            if (!_7603)
                            {
                                _7611 = any(bool2(_7600.x >= cbFI_MvDepthLaneSize.x, _7600.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7611 = _7603;
                            }
                            if (_7611)
                            {
                                _12618 = _10753;
                                break;
                            }
                            uint4 _7689 = r_warped_motion_qdata_tp1.Load(int3(_7600, 0));
                            uint _7690 = _7689.x;
                            if (_7690 != 0u)
                            {
                                _12618 = min(_10753, _7690);
                                break;
                            }
                            _10756++;
                            continue;
                        }
                        else
                        {
                            _12618 = _10753;
                            break;
                        }
                    }
                }
                float _10755;
                if (_10753 == 4294967295u)
                {
                    _10755 = -1.0f;
                }
                else
                {
                    float _10754;
                    if (_10753 == 0u)
                    {
                        _10754 = -1.0f;
                    }
                    else
                    {
                        _10754 = float((_10753 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10755 = _10754;
                }
                _10768 = _10755;
                break;
            } while(false);
            float _4772 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4774 = _10768 < 0.0f;
            bool _4779;
            if (_4774)
            {
                bool _7709 = all(bool2(_10525.x > 0.0f.xx.x, _10525.y > 0.0f.xx.y));
                bool _7715;
                if (_7709)
                {
                    _7715 = all(bool2(_10525.x < 1.0f.xx.x, _10525.y < 1.0f.xx.y));
                }
                else
                {
                    _7715 = _7709;
                }
                _4779 = _7715;
            }
            else
            {
                _4779 = _4774;
            }
            bool _4784;
            if (_4779)
            {
                bool _7720 = all(bool2(_10527.x > 0.0f.xx.x, _10527.y > 0.0f.xx.y));
                bool _7726;
                if (_7720)
                {
                    _7726 = all(bool2(_10527.x < 1.0f.xx.x, _10527.y < 1.0f.xx.y));
                }
                else
                {
                    _7726 = _7720;
                }
                _4784 = _7726;
            }
            else
            {
                _4784 = _4779;
            }
            float4 _10830;
            if (_4784)
            {
                uint _7733_dummy_parameter;
                float _7757 = log(((r_depth_tm1.Load(int3(int2(floor(_10525 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7733_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _7765_dummy_parameter;
                float _7789 = log(((r_depth_tp1.Load(int3(int2(floor(_10527 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7765_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _4795 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4802;
                if (_4795)
                {
                    _4802 = _7789 > (_7757 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4802 = _4795;
                }
                float4 _10804;
                if (_4802)
                {
                    _10804 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10804 = 1.0f.xxxx;
                }
                bool _4809 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4816;
                if (_4809)
                {
                    _4816 = _7757 > (_7789 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4816 = _4809;
                }
                float4 _10833;
                if (_4816)
                {
                    float4 _10359 = _10804;
                    _10359.x = 0.0f;
                    _10833 = _10359;
                }
                else
                {
                    _10833 = _10804;
                }
                _10830 = _10833;
            }
            else
            {
                bool _4824 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4830;
                if (_4824)
                {
                    _4830 = _10773.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4830 = _4824;
                }
                bool _4835;
                if (_4830)
                {
                    bool _7795 = all(bool2(_10527.x > 0.0f.xx.x, _10527.y > 0.0f.xx.y));
                    bool _7801;
                    if (_7795)
                    {
                        _7801 = all(bool2(_10527.x < 1.0f.xx.x, _10527.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7801 = _7795;
                    }
                    _4835 = _7801;
                }
                else
                {
                    _4835 = _4830;
                }
                float4 _10831;
                if (_4835)
                {
                    float _10791;
                    if (_10768 >= 0.0f)
                    {
                        _10791 = _10768 - _4772;
                    }
                    else
                    {
                        float _10787;
                        _10787 = 2.0f;
                        float _7858;
                        for (int _10786 = 0; _10786 < 24; _10787 = _7858, _10786++)
                        {
                            float _7822 = float(_10786 & 7) * 0.785398185253143310546875f;
                            int _7824 = _10786 >> 3;
                            int _10788;
                            if (_7824 == 0)
                            {
                                _10788 = 16;
                            }
                            else
                            {
                                _10788 = (_7824 == 1) ? 48 : 96;
                            }
                            uint _7890_dummy_parameter;
                            _7858 = min(_10787, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10527 + ((cbFI_MvDepthLaneSizeRcp * float(_10788)) * float2(cos(_7822), sin(_7822))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7890_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10791 = _10787;
                    }
                    uint _7922_dummy_parameter;
                    float4 _10832;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_10527 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7922_dummy_parameter))))), 0)).x) > ((exp((_10791 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10832 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10832 = 1.0f.xxxx;
                    }
                    _10831 = _10832;
                }
                else
                {
                    _10831 = 1.0f.xxxx;
                }
                _10830 = _10831;
            }
            bool _4861 = _10768 >= 0.0f;
            bool _4868;
            if (_4861)
            {
                _4868 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4868 = _4861;
            }
            bool _4874;
            if (_4868)
            {
                _4874 = _10773.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4874 = _4868;
            }
            bool _4879;
            if (_4874)
            {
                bool _7947 = all(bool2(_10525.x > 0.0f.xx.x, _10525.y > 0.0f.xx.y));
                bool _7953;
                if (_7947)
                {
                    _7953 = all(bool2(_10525.x < 1.0f.xx.x, _10525.y < 1.0f.xx.y));
                }
                else
                {
                    _7953 = _7947;
                }
                _4879 = _7953;
            }
            else
            {
                _4879 = _4874;
            }
            float4 _10847;
            if (_4879)
            {
                float _10824;
                if (_4861)
                {
                    _10824 = _10768 - _4772;
                }
                else
                {
                    float _10820;
                    _10820 = 2.0f;
                    float _8010;
                    for (int _10819 = 0; _10819 < 24; _10820 = _8010, _10819++)
                    {
                        float _7974 = float(_10819 & 7) * 0.785398185253143310546875f;
                        int _7976 = _10819 >> 3;
                        int _10821;
                        if (_7976 == 0)
                        {
                            _10821 = 16;
                        }
                        else
                        {
                            _10821 = (_7976 == 1) ? 48 : 96;
                        }
                        uint _8026_dummy_parameter;
                        _8010 = min(_10820, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10525 + ((cbFI_MvDepthLaneSizeRcp * float(_10821)) * float2(cos(_7974), sin(_7974))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8026_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10824 = _10820;
                }
                uint _8074_dummy_parameter;
                float4 _10848;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_10525 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8074_dummy_parameter))))), 0)).x) > ((exp((_10824 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10365 = _10830;
                    _10365.x = 0.0f;
                    _10848 = _10365;
                }
                else
                {
                    _10848 = _10830;
                }
                _10847 = _10848;
            }
            else
            {
                _10847 = _10830;
            }
            float4 _10860;
            if (_4861)
            {
                float _8101 = (exp(((_10768 - _4772) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _4914 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4920;
                if (_4914)
                {
                    _4920 = _10773.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4920 = _4914;
                }
                bool _4925;
                if (_4920)
                {
                    bool _8106 = all(bool2(_10529.x > 0.0f.xx.x, _10529.y > 0.0f.xx.y));
                    bool _8112;
                    if (_8106)
                    {
                        _8112 = all(bool2(_10529.x < 1.0f.xx.x, _10529.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8112 = _8106;
                    }
                    _4925 = _8112;
                }
                else
                {
                    _4925 = _4920;
                }
                bool _4933;
                if (_4925)
                {
                    uint _8119_dummy_parameter;
                    _4933 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10529 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8119_dummy_parameter))))), 0)).x) > _8101;
                }
                else
                {
                    _4933 = _4925;
                }
                float4 _10858;
                if (_4933)
                {
                    float4 _10368 = _10847;
                    _10368.w = 0.0f;
                    _10858 = _10368;
                }
                else
                {
                    _10858 = _10847;
                }
                bool _4940 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4946;
                if (_4940)
                {
                    _4946 = _10773.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4946 = _4940;
                }
                bool _4951;
                if (_4946)
                {
                    bool _8137 = all(bool2(_10528.x > 0.0f.xx.x, _10528.y > 0.0f.xx.y));
                    bool _8143;
                    if (_8137)
                    {
                        _8143 = all(bool2(_10528.x < 1.0f.xx.x, _10528.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8143 = _8137;
                    }
                    _4951 = _8143;
                }
                else
                {
                    _4951 = _4946;
                }
                bool _4959;
                if (_4951)
                {
                    uint _8150_dummy_parameter;
                    _4959 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10528 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8150_dummy_parameter))))), 0)).x) > _8101;
                }
                else
                {
                    _4959 = _4951;
                }
                float4 _10861;
                if (_4959)
                {
                    float4 _10371 = _10858;
                    _10371.z = 0.0f;
                    _10861 = _10371;
                }
                else
                {
                    _10861 = _10858;
                }
                _10860 = _10861;
            }
            else
            {
                _10860 = _10847;
            }
            float4 _10931;
            if (any(bool4(_10860.x < 1.0f.xxxx.x, _10860.y < 1.0f.xxxx.y, _10860.z < 1.0f.xxxx.z, _10860.w < 1.0f.xxxx.w)))
            {
                float4 _4970 = _10773 * _10860;
                float _4972 = dot(_4970, 1.0f.xxxx);
                float4 _10932;
                if (_4972 > 0.0f)
                {
                    _10932 = _4970 / _4972.xxxx;
                }
                else
                {
                    bool _4983 = _10860.y == 0.0f;
                    bool _4989;
                    if (_4983)
                    {
                        _4989 = _10860.x > 0.0f;
                    }
                    else
                    {
                        _4989 = _4983;
                    }
                    bool _4994;
                    if (_4989)
                    {
                        bool _8168 = all(bool2(_10525.x > 0.0f.xx.x, _10525.y > 0.0f.xx.y));
                        bool _8174;
                        if (_8168)
                        {
                            _8174 = all(bool2(_10525.x < 1.0f.xx.x, _10525.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8174 = _8168;
                        }
                        _4994 = _8174;
                    }
                    else
                    {
                        _4994 = _4989;
                    }
                    float4 _10933;
                    if (_4994)
                    {
                        _10933 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4999 = _10860.x == 0.0f;
                        bool _5005;
                        if (_4999)
                        {
                            _5005 = _10860.y > 0.0f;
                        }
                        else
                        {
                            _5005 = _4999;
                        }
                        bool _5010;
                        if (_5005)
                        {
                            bool _8179 = all(bool2(_10527.x > 0.0f.xx.x, _10527.y > 0.0f.xx.y));
                            bool _8185;
                            if (_8179)
                            {
                                _8185 = all(bool2(_10527.x < 1.0f.xx.x, _10527.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _8185 = _8179;
                            }
                            _5010 = _8185;
                        }
                        else
                        {
                            _5010 = _5005;
                        }
                        bool4 _12649 = _5010.xxxx;
                        _10933 = float4(_12649.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10773.x, _12649.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10773.y, _12649.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10773.z, _12649.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10773.w);
                    }
                    _10932 = _10933;
                }
                _10931 = _10932;
            }
            else
            {
                _10931 = _10773;
            }
            _10930 = _10931;
        }
        else
        {
            _10930 = _10773;
        }
        float4 _11518;
        bool _11538;
        float3 _11652;
        if (((cbFI_pad0 & 32768u) != 0u) && _4729)
        {
            bool _5027 = _10930.x > 0.00999999977648258209228515625f;
            bool _5030 = _10930.y > 0.00999999977648258209228515625f;
            bool _5039 = (_10930.z + _10930.w) > 0.0199999995529651641845703125f;
            bool _5045;
            if (_5039)
            {
                bool _8190 = all(bool2(_10528.x > 0.0f.xx.x, _10528.y > 0.0f.xx.y));
                bool _8196;
                if (_8190)
                {
                    _8196 = all(bool2(_10528.x < 1.0f.xx.x, _10528.y < 1.0f.xx.y));
                }
                else
                {
                    _8196 = _8190;
                }
                _5045 = _8196;
            }
            else
            {
                _5045 = _5039;
            }
            bool _5050;
            if (_5045)
            {
                bool _8201 = all(bool2(_10529.x > 0.0f.xx.x, _10529.y > 0.0f.xx.y));
                bool _8207;
                if (_8201)
                {
                    _8207 = all(bool2(_10529.x < 1.0f.xx.x, _10529.y < 1.0f.xx.y));
                }
                else
                {
                    _8207 = _8201;
                }
                _5050 = _8207;
            }
            else
            {
                _5050 = _5045;
            }
            bool _5057;
            if (_5050)
            {
                float _10941;
                do
                {
                    bool _8290 = all(bool2(_10528.x > 0.0f.xx.x, _10528.y > 0.0f.xx.y));
                    bool _8296;
                    if (_8290)
                    {
                        _8296 = all(bool2(_10528.x < 1.0f.xx.x, _10528.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8296 = _8290;
                    }
                    bool _8227 = !_8296;
                    bool _8234;
                    if (!_8227)
                    {
                        bool _8301 = all(bool2(_10529.x > 0.0f.xx.x, _10529.y > 0.0f.xx.y));
                        bool _8307;
                        if (_8301)
                        {
                            _8307 = all(bool2(_10529.x < 1.0f.xx.x, _10529.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8307 = _8301;
                        }
                        _8234 = !_8307;
                    }
                    else
                    {
                        _8234 = _8227;
                    }
                    if (_8234)
                    {
                        _10941 = 0.0f;
                        break;
                    }
                    uint _8314_dummy_parameter;
                    uint _8330_dummy_parameter;
                    float4 _8255 = mul(float4((float2(_10528.x, 1.0f - _10528.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10528 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8314_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _8257 = _8255.w;
                    if (abs(_8257) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10941 = 0.0f;
                        break;
                    }
                    float _8268 = abs(cbFI_DeviceToViewDepth.y / ((_8255.z / _8257) - cbFI_DeviceToViewDepth.x));
                    float _8271 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10529 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8330_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10941 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8268 - _8271) / max(max(_8268, _8271), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5057 = _10941 < 0.5f;
            }
            else
            {
                _5057 = _5050;
            }
            float4 _10956;
            if (_5057)
            {
                uint _8380_dummy_parameter;
                uint _8411_dummy_parameter;
                float4 _10957;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10528 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8380_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10529 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8411_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10957 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10957 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10956 = _10957;
            }
            else
            {
                _10956 = 1.0f.xxxx;
            }
            bool _5081;
            if (_7157)
            {
                bool _8440 = all(bool2(_10525.x > 0.0f.xx.x, _10525.y > 0.0f.xx.y));
                bool _8446;
                if (_8440)
                {
                    _8446 = all(bool2(_10525.x < 1.0f.xx.x, _10525.y < 1.0f.xx.y));
                }
                else
                {
                    _8446 = _8440;
                }
                _5081 = _8446;
            }
            else
            {
                _5081 = _7157;
            }
            bool _5087;
            if (_7157)
            {
                bool _8451 = all(bool2(_10527.x > 0.0f.xx.x, _10527.y > 0.0f.xx.y));
                bool _8457;
                if (_8451)
                {
                    _8457 = all(bool2(_10527.x < 1.0f.xx.x, _10527.y < 1.0f.xx.y));
                }
                else
                {
                    _8457 = _8451;
                }
                _5087 = _8457;
            }
            else
            {
                _5087 = _7157;
            }
            bool _5093;
            if (_7189)
            {
                bool _8462 = all(bool2(_10528.x > 0.0f.xx.x, _10528.y > 0.0f.xx.y));
                bool _8468;
                if (_8462)
                {
                    _8468 = all(bool2(_10528.x < 1.0f.xx.x, _10528.y < 1.0f.xx.y));
                }
                else
                {
                    _8468 = _8462;
                }
                _5093 = _8468;
            }
            else
            {
                _5093 = _7189;
            }
            bool _5099;
            if (_7189)
            {
                bool _8473 = all(bool2(_10529.x > 0.0f.xx.x, _10529.y > 0.0f.xx.y));
                bool _8479;
                if (_8473)
                {
                    _8479 = all(bool2(_10529.x < 1.0f.xx.x, _10529.y < 1.0f.xx.y));
                }
                else
                {
                    _8479 = _8473;
                }
                _5099 = _8479;
            }
            else
            {
                _5099 = _7189;
            }
            bool _5102 = _5093 != _5099;
            bool _5108;
            if (_5102)
            {
                _5108 = _5081 || _5087;
            }
            else
            {
                _5108 = _5102;
            }
            float4 _11065;
            if (_5108)
            {
                float4 _10398 = _10956;
                _10398.z = 0.0f;
                _10398.w = 0.0f;
                _11065 = _10398;
            }
            else
            {
                _11065 = _10956;
            }
            bool _5115 = _5081 && _5027;
            bool _5118 = _5087 && _5030;
            float4 _11170;
            float3 _11752;
            if (_5115 || _5118)
            {
                float _11060;
                do
                {
                    uint4 _8618 = r_warped_motion_qdata_tp1.Load(int3(_10555, 0));
                    uint _8619 = _8618.x;
                    if (_8619 != 0u)
                    {
                        float _11059;
                        if (_8619 == 0u)
                        {
                            _11059 = -1.0f;
                        }
                        else
                        {
                            _11059 = float((_8619 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11060 = _11059;
                        break;
                    }
                    int _11042;
                    uint _11043;
                    _11043 = _8619;
                    _11042 = -1;
                    uint _11058;
                    for (; _11042 <= 1; _11043 = _11058, _11042++)
                    {
                        _11058 = _11043;
                        for (int _11056 = -1; _11056 <= 1; )
                        {
                            _11058 = max(_11058, r_warped_motion_qdata_tp1.Load(int3(clamp(_10555 + int2(_11056, _11042), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11056++;
                            continue;
                        }
                    }
                    if (_11043 != 0u)
                    {
                        float _11055;
                        if (_11043 == 0u)
                        {
                            _11055 = -1.0f;
                        }
                        else
                        {
                            _11055 = float((_11043 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11060 = _11055;
                        break;
                    }
                    uint _11045;
                    _11045 = 4294967295u;
                    uint _12619;
                    for (int _11044 = 0; _11044 < 8; _11045 = _12619, _11044++)
                    {
                        int _11048 = 0;
                        for (;;)
                        {
                            if (_11048 < 5)
                            {
                                int2 _8569 = _10555 + (_1093[_11044] * _1102[_11048].xx);
                                bool _8572 = any(bool2(_8569.x < int2(0, 0).x, _8569.y < int2(0, 0).y));
                                bool _8580;
                                if (!_8572)
                                {
                                    _8580 = any(bool2(_8569.x >= cbFI_MvDepthLaneSize.x, _8569.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8580 = _8572;
                                }
                                if (_8580)
                                {
                                    _12619 = _11045;
                                    break;
                                }
                                uint4 _8658 = r_warped_motion_qdata_tp1.Load(int3(_8569, 0));
                                uint _8659 = _8658.x;
                                if (_8659 != 0u)
                                {
                                    _12619 = min(_11045, _8659);
                                    break;
                                }
                                _11048++;
                                continue;
                            }
                            else
                            {
                                _12619 = _11045;
                                break;
                            }
                        }
                    }
                    float _11047;
                    if (_11045 == 4294967295u)
                    {
                        _11047 = -1.0f;
                    }
                    else
                    {
                        float _11046;
                        if (_11045 == 0u)
                        {
                            _11046 = -1.0f;
                        }
                        else
                        {
                            _11046 = float((_11045 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11047 = _11046;
                    }
                    _11060 = _11047;
                    break;
                } while(false);
                bool _5126 = _11060 < 0.0f;
                float _11061;
                if (_5126)
                {
                    _11061 = 0.0f;
                }
                else
                {
                    _11061 = _11060 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8680_dummy_parameter;
                uint _8712_dummy_parameter;
                float4 _11098;
                if ((_5126 && _5115) && _5118)
                {
                    uint _8744_dummy_parameter;
                    float _8768 = log(((r_depth_tm1.Load(int3(int2(floor(_10525 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8744_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8776_dummy_parameter;
                    float _8800 = log(((r_depth_tp1.Load(int3(int2(floor(_10527 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8776_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _11099;
                    if (_8768 > (_8800 + 0.07999999821186065673828125f))
                    {
                        float4 _10402 = _11065;
                        _10402.x = 0.0f;
                        _11099 = _10402;
                    }
                    else
                    {
                        float4 _11100;
                        if (_8800 > (_8768 + 0.07999999821186065673828125f))
                        {
                            float4 _10404 = _11065;
                            _10404.y = 0.0f;
                            _11100 = _10404;
                        }
                        else
                        {
                            _11100 = _11065;
                        }
                        _11099 = _11100;
                    }
                    _11098 = _11099;
                }
                else
                {
                    _11098 = _11065;
                }
                float _5178 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5180 = _11060 >= 0.0f;
                float _11081;
                if (_5180)
                {
                    _11081 = _11060 - _5178;
                }
                else
                {
                    float _11077;
                    if (_5115)
                    {
                        float _11076;
                        _11076 = 2.0f;
                        float _8858;
                        for (int _11075 = 0; _11075 < 24; _11076 = _8858, _11075++)
                        {
                            float _8822 = float(_11075 & 7) * 0.785398185253143310546875f;
                            int _8824 = _11075 >> 3;
                            int _11078;
                            if (_8824 == 0)
                            {
                                _11078 = 16;
                            }
                            else
                            {
                                _11078 = (_8824 == 1) ? 48 : 96;
                            }
                            uint _8874_dummy_parameter;
                            _8858 = min(_11076, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10525 + ((cbFI_MvDepthLaneSizeRcp * float(_11078)) * float2(cos(_8822), sin(_8822))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8874_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11077 = _11076;
                    }
                    else
                    {
                        _11077 = 0.0f;
                    }
                    _11081 = _11077;
                }
                float _11088;
                if (_5180)
                {
                    _11088 = _11060 - _5178;
                }
                else
                {
                    float _11084;
                    if (_5118)
                    {
                        float _11083;
                        _11083 = 2.0f;
                        float _8972;
                        for (int _11082 = 0; _11082 < 24; _11083 = _8972, _11082++)
                        {
                            float _8936 = float(_11082 & 7) * 0.785398185253143310546875f;
                            int _8938 = _11082 >> 3;
                            int _11085;
                            if (_8938 == 0)
                            {
                                _11085 = 16;
                            }
                            else
                            {
                                _11085 = (_8938 == 1) ? 48 : 96;
                            }
                            uint _9004_dummy_parameter;
                            _8972 = min(_11083, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10527 + ((cbFI_MvDepthLaneSizeRcp * float(_11085)) * float2(cos(_8936), sin(_8936))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9004_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11084 = _11083;
                    }
                    else
                    {
                        _11084 = 0.0f;
                    }
                    _11088 = _11084;
                }
                float _11089;
                if (_5115)
                {
                    uint _9036_dummy_parameter;
                    _11089 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_10525 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9036_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11089 = 0.0f;
                }
                float _11090;
                if (_5118)
                {
                    uint _9056_dummy_parameter;
                    _11090 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_10527 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9056_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11090 = 0.0f;
                }
                bool _5235;
                if (_5115)
                {
                    _5235 = _11089 > ((exp((_11081 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5235 = _5115;
                }
                float4 _11106;
                if (_5235)
                {
                    float4 _10406 = _11098;
                    _10406.x = 0.0f;
                    _11106 = _10406;
                }
                else
                {
                    _11106 = _11098;
                }
                bool _5247;
                if (_5118)
                {
                    _5247 = _11090 > ((exp((_11088 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5247 = _5118;
                }
                float4 _11108;
                if (_5247)
                {
                    float4 _10408 = _11106;
                    _10408.y = 0.0f;
                    _11108 = _10408;
                }
                else
                {
                    _11108 = _11106;
                }
                float4 _11171;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5180)
                {
                    bool _5267;
                    if (_5115)
                    {
                        _5267 = _11089 < ((exp((_11081 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5267 = _5115;
                    }
                    float4 _11110;
                    if (_5267)
                    {
                        float4 _10410 = _11108;
                        _10410.x = 0.0f;
                        _11110 = _10410;
                    }
                    else
                    {
                        _11110 = _11108;
                    }
                    bool _5279;
                    if (_5118)
                    {
                        _5279 = _11090 < ((exp((_11088 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5279 = _5118;
                    }
                    float4 _11172;
                    if (_5279)
                    {
                        float4 _10412 = _11110;
                        _10412.y = 0.0f;
                        _11172 = _10412;
                    }
                    else
                    {
                        _11172 = _11110;
                    }
                    _11171 = _11172;
                }
                else
                {
                    _11171 = _11108;
                }
                _11752 = float3(_11061, log(((r_depth_tm1.Load(int3(int2(floor(_10525 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8680_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_10527 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8712_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _11170 = _11171;
            }
            else
            {
                _11752 = float3(0.0f, 0.0f, 0.5f);
                _11170 = _11065;
            }
            bool _5290 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5039;
            bool _5296;
            if (_5290)
            {
                _5296 = _5093 || _5099;
            }
            else
            {
                _5296 = _5290;
            }
            float4 _11193;
            if (_5296)
            {
                float _11165;
                do
                {
                    uint4 _9236 = r_warped_motion_qdata_tp1.Load(int3(_10555, 0));
                    uint _9237 = _9236.x;
                    if (_9237 != 0u)
                    {
                        float _11164;
                        if (_9237 == 0u)
                        {
                            _11164 = -1.0f;
                        }
                        else
                        {
                            _11164 = float((_9237 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11165 = _11164;
                        break;
                    }
                    int _11147;
                    uint _11148;
                    _11148 = _9237;
                    _11147 = -1;
                    uint _11163;
                    for (; _11147 <= 1; _11148 = _11163, _11147++)
                    {
                        _11163 = _11148;
                        for (int _11161 = -1; _11161 <= 1; )
                        {
                            _11163 = max(_11163, r_warped_motion_qdata_tp1.Load(int3(clamp(_10555 + int2(_11161, _11147), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11161++;
                            continue;
                        }
                    }
                    if (_11148 != 0u)
                    {
                        float _11160;
                        if (_11148 == 0u)
                        {
                            _11160 = -1.0f;
                        }
                        else
                        {
                            _11160 = float((_11148 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11165 = _11160;
                        break;
                    }
                    uint _11150;
                    _11150 = 4294967295u;
                    uint _12620;
                    for (int _11149 = 0; _11149 < 8; _11150 = _12620, _11149++)
                    {
                        int _11153 = 0;
                        for (;;)
                        {
                            if (_11153 < 5)
                            {
                                int2 _9187 = _10555 + (_1093[_11149] * _1102[_11153].xx);
                                bool _9190 = any(bool2(_9187.x < int2(0, 0).x, _9187.y < int2(0, 0).y));
                                bool _9198;
                                if (!_9190)
                                {
                                    _9198 = any(bool2(_9187.x >= cbFI_MvDepthLaneSize.x, _9187.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _9198 = _9190;
                                }
                                if (_9198)
                                {
                                    _12620 = _11150;
                                    break;
                                }
                                uint4 _9276 = r_warped_motion_qdata_tp1.Load(int3(_9187, 0));
                                uint _9277 = _9276.x;
                                if (_9277 != 0u)
                                {
                                    _12620 = min(_11150, _9277);
                                    break;
                                }
                                _11153++;
                                continue;
                            }
                            else
                            {
                                _12620 = _11150;
                                break;
                            }
                        }
                    }
                    float _11152;
                    if (_11150 == 4294967295u)
                    {
                        _11152 = -1.0f;
                    }
                    else
                    {
                        float _11151;
                        if (_11150 == 0u)
                        {
                            _11151 = -1.0f;
                        }
                        else
                        {
                            _11151 = float((_11150 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11152 = _11151;
                    }
                    _11165 = _11152;
                    break;
                } while(false);
                float4 _11194;
                if (_11165 >= 0.0f)
                {
                    float _9298 = (exp((_11165 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5315;
                    if (_5093)
                    {
                        uint _9305_dummy_parameter;
                        _5315 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10528 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9305_dummy_parameter))))), 0)).x) > _9298;
                    }
                    else
                    {
                        _5315 = _5093;
                    }
                    float4 _11183;
                    if (_5315)
                    {
                        float4 _10414 = _11170;
                        _10414.z = 0.0f;
                        _11183 = _10414;
                    }
                    else
                    {
                        _11183 = _11170;
                    }
                    bool _5327;
                    if (_5099)
                    {
                        uint _9325_dummy_parameter;
                        _5327 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10529 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9325_dummy_parameter))))), 0)).x) > _9298;
                    }
                    else
                    {
                        _5327 = _5099;
                    }
                    float4 _11195;
                    if (_5327)
                    {
                        float4 _10416 = _11183;
                        _10416.w = 0.0f;
                        _11195 = _10416;
                    }
                    else
                    {
                        _11195 = _11183;
                    }
                    _11194 = _11195;
                }
                else
                {
                    _11194 = _11170;
                }
                _11193 = _11194;
            }
            else
            {
                _11193 = _11170;
            }
            bool _5335 = _5081 != _5087;
            bool _5342;
            if (_5335)
            {
                _5342 = _5081 ? _5027 : _5030;
            }
            else
            {
                _5342 = _5335;
            }
            bool _5349;
            if (_5342)
            {
                _5349 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5349 = _5342;
            }
            float4 _11278;
            if (_5349)
            {
                bool2 _5354 = _5081.xx;
                float2 _5355 = float2(_5354.x ? _10525.x : _10527.x, _5354.y ? _10525.y : _10527.y);
                float _11185;
                if (_5081)
                {
                    uint _9345_dummy_parameter;
                    _11185 = r_depth_tm1.Load(int3(int2(floor(_5355 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9345_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9361_dummy_parameter;
                    _11185 = r_depth_tp1.Load(int3(int2(floor(_5355 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9361_dummy_parameter))))), 0)).x;
                }
                float4x4 _11186;
                if (_5081)
                {
                    _11186 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _11186 = cbFI_MotionTP1ToTM1;
                }
                float2 _11187;
                do
                {
                    float _9388 = _5355.x;
                    float _9391 = 1.0f - _5355.y;
                    float4 _9402 = mul(float4((float2(_9388, _9391) * 2.0f) - 1.0f.xx, _11185, 1.0f), _11186);
                    float _9404 = _9402.w;
                    if (!(_9404 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11187 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9417 = ((_9402.xy / _9404.xx) + 1.0f.xx) * 0.5f;
                    _11187 = float2(_9417.x - _9388, _9391 - _9417.y);
                    break;
                } while(false);
                float2 _5385 = float2(cbFI_DisplaySize);
                float4 _11279;
                if (!(length(((_5355 + _11187) - float2(_5354.x ? _10527.x : _10525.x, _5354.y ? _10527.y : _10525.y)) * _5385) <= ((0.100000001490116119384765625f * length(_11187 * _5385)) + 8.0f)))
                {
                    float4 _11280;
                    if (_5081)
                    {
                        float4 _10426 = _11193;
                        _10426.x = 0.0f;
                        _11280 = _10426;
                    }
                    else
                    {
                        float4 _10428 = _11193;
                        _10428.y = 0.0f;
                        _11280 = _10428;
                    }
                    _11279 = _11280;
                }
                else
                {
                    _11279 = _11193;
                }
                _11278 = _11279;
            }
            else
            {
                _11278 = _11193;
            }
            float4 _5410 = _10930 * _11278;
            float _5412 = dot(_5410, 1.0f.xxxx);
            float4 _11519;
            bool _11539;
            if (_5412 > 0.0f)
            {
                _11539 = _10678;
                _11519 = _5410 / _5412.xxxx;
            }
            else
            {
                bool _5423 = any(bool4(_11278.x < 1.0f.xxxx.x, _11278.y < 1.0f.xxxx.y, _11278.z < 1.0f.xxxx.z, _11278.w < 1.0f.xxxx.w));
                if (_5423)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9439;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9439);
                    }
                }
                bool4 _12652 = _5423.xxxx;
                _11539 = _5423 ? true : _10678;
                _11519 = float4(_12652.x ? 0.0f.xxxx.x : _10930.x, _12652.y ? 0.0f.xxxx.y : _10930.y, _12652.z ? 0.0f.xxxx.z : _10930.z, _12652.w ? 0.0f.xxxx.w : _10930.w);
            }
            _11652 = _11752;
            _11538 = _11539;
            _11518 = _11519;
        }
        else
        {
            _11652 = float3(0.0f, 0.0f, 0.5f);
            _11538 = _10678;
            _11518 = _10930;
        }
        uint _5432 = (cbFI_pad0 >> 24u) & 31u;
        uint _5436 = (cbFI_pad0 >> 16u) & 255u;
        bool _5438 = _5432 != 0u;
        bool _5440 = _5436 == 12u;
        bool _5443 = _5436 == 13u;
        float4 _11535;
        if ((_5438 || _5440) || _5443)
        {
            float _11281;
            do
            {
                bool _9523 = all(bool2(_10528.x > 0.0f.xx.x, _10528.y > 0.0f.xx.y));
                bool _9529;
                if (_9523)
                {
                    _9529 = all(bool2(_10528.x < 1.0f.xx.x, _10528.y < 1.0f.xx.y));
                }
                else
                {
                    _9529 = _9523;
                }
                bool _9460 = !_9529;
                bool _9467;
                if (!_9460)
                {
                    bool _9534 = all(bool2(_10529.x > 0.0f.xx.x, _10529.y > 0.0f.xx.y));
                    bool _9540;
                    if (_9534)
                    {
                        _9540 = all(bool2(_10529.x < 1.0f.xx.x, _10529.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9540 = _9534;
                    }
                    _9467 = !_9540;
                }
                else
                {
                    _9467 = _9460;
                }
                if (_9467)
                {
                    _11281 = 0.0f;
                    break;
                }
                uint _9547_dummy_parameter;
                uint _9563_dummy_parameter;
                float4 _9488 = mul(float4((float2(_10528.x, 1.0f - _10528.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10528 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9547_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9490 = _9488.w;
                if (abs(_9490) < 9.9999999747524270787835121154785e-07f)
                {
                    _11281 = 0.0f;
                    break;
                }
                float _9501 = abs(cbFI_DeviceToViewDepth.y / ((_9488.z / _9490) - cbFI_DeviceToViewDepth.x));
                float _9504 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10529 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9563_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _11281 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9501 - _9504) / max(max(_9501, _9504), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9611 = all(bool2(_10529.x > 0.0f.xx.x, _10529.y > 0.0f.xx.y));
            bool _9617;
            if (_9611)
            {
                _9617 = all(bool2(_10529.x < 1.0f.xx.x, _10529.y < 1.0f.xx.y));
            }
            else
            {
                _9617 = _9611;
            }
            float _11282;
            if (_9617)
            {
                uint _9624_dummy_parameter;
                _11282 = length((_6243 + (r_motion_tp1.Load(int3(int2(floor(_10529 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9624_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _11282 = 1000000.0f;
            }
            float _11293;
            if ((_5432 & 1u) != 0u)
            {
                _11293 = _11281;
            }
            else
            {
                _11293 = 1.0f;
            }
            float _11294;
            if ((_5432 & 2u) != 0u)
            {
                _11294 = _11293 * (1.0f - smoothstep(2.0f, 8.0f, _11282));
            }
            else
            {
                _11294 = _11293;
            }
            float _11295;
            if ((_5432 & 4u) != 0u)
            {
                _11295 = _11294 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6964 - _6972) - length(_6948 - _6956))));
            }
            else
            {
                _11295 = _11294;
            }
            float _11529;
            if ((_5432 & 8u) != 0u)
            {
                _11529 = lerp(1.0f, _11295, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6948 - _6956)));
            }
            else
            {
                _11529 = _11295;
            }
            bool _5518 = (_5432 & 16u) != 0u;
            bool _5527;
            if (_5518)
            {
                _5527 = length(_10523 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5527 = _5518;
            }
            float _12654 = _5527 ? 1.0f : _11529;
            bool _5533 = _5438 && _7157;
            bool _5538;
            if (_5533)
            {
                bool _9649 = all(bool2(_10525.x > 0.0f.xx.x, _10525.y > 0.0f.xx.y));
                bool _9655;
                if (_9649)
                {
                    _9655 = all(bool2(_10525.x < 1.0f.xx.x, _10525.y < 1.0f.xx.y));
                }
                else
                {
                    _9655 = _9649;
                }
                _5538 = _9655;
            }
            else
            {
                _5538 = _5533;
            }
            bool _5543;
            if (_5538)
            {
                bool _9660 = all(bool2(_10527.x > 0.0f.xx.x, _10527.y > 0.0f.xx.y));
                bool _9666;
                if (_9660)
                {
                    _9666 = all(bool2(_10527.x < 1.0f.xx.x, _10527.y < 1.0f.xx.y));
                }
                else
                {
                    _9666 = _9660;
                }
                _5543 = _9666;
            }
            else
            {
                _5543 = _5538;
            }
            float4 _11536;
            if (_5543)
            {
                float _5549 = _11518.x + _11518.y;
                float _5558 = (_11518.z + _11518.w) * (1.0f - _12654);
                float _11532;
                if (_5549 > 9.9999997473787516355514526367188e-06f)
                {
                    _11532 = _11518.x / _5549;
                }
                else
                {
                    _11532 = _4399;
                }
                _11536 = float4(_11518.x + (_5558 * _11532), _11518.y + (_5558 * (1.0f - _11532)), _11518.zw * _12654);
            }
            else
            {
                _11536 = _11518;
            }
            _11535 = _11536;
        }
        else
        {
            _11535 = _11518;
        }
        float3 _12422;
        if (_11538)
        {
            float3 _9672 = r_current_interpolation_source.Load(int3(_3758, 0)).xyz;
            float3 _12423;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _7157)
            {
                uint _9679_dummy_parameter;
                float _11643;
                _11643 = r_depth_tm1.Load(int3(int2(floor(_10525 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9679_dummy_parameter))))), 0)).x;
                float _5670;
                for (int _11642 = 0; _11642 < 24; _11643 = _5670, _11642++)
                {
                    float _5642 = float(_11642 & 7) * 0.785398185253143310546875f;
                    int _5644 = _11642 >> 3;
                    int _12473;
                    if (_5644 == 0)
                    {
                        _12473 = 16;
                    }
                    else
                    {
                        _12473 = (_5644 == 1) ? 48 : 96;
                    }
                    uint _9699_dummy_parameter;
                    _5670 = max(_11643, r_depth_tm1.Load(int3(int2(floor(clamp(_10525 + ((cbFI_MvDepthLaneSizeRcp * float(_12473)) * float2(cos(_5642), sin(_5642))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9699_dummy_parameter))))), 0)).x);
                }
                float2 _11644;
                do
                {
                    float _9721 = 1.0f - _10525.y;
                    float4 _9732 = mul(float4((float2(_10525.x, _9721) * 2.0f) - 1.0f.xx, _11643, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9734 = _9732.w;
                    if (!(_9734 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11644 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9747 = ((_9732.xy / _9734.xx) + 1.0f.xx) * 0.5f;
                    _11644 = float2(_9747.x - _10525.x, _9721 - _9747.y);
                    break;
                } while(false);
                float2 _5681 = _10525 + _11644;
                bool _9765 = all(bool2(_5681.x > 0.0f.xx.x, _5681.y > 0.0f.xx.y));
                bool _9771;
                if (_9765)
                {
                    _9771 = all(bool2(_5681.x < 1.0f.xx.x, _5681.y < 1.0f.xx.y));
                }
                else
                {
                    _9771 = _9765;
                }
                float3 _12424;
                if (_9771)
                {
                    float _5687 = abs(cbFI_DeviceToViewDepth.y / (_11643 - cbFI_DeviceToViewDepth.x));
                    uint _9791_dummy_parameter;
                    int2 _9791 = int2(spvTextureSize(r_depth_m2, uint(0), _9791_dummy_parameter));
                    float _5691 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5681 * float2(_9791))), int2(0, 0), _9791 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12429;
                    if (abs(_5691 - _5687) <= (0.20000000298023223876953125f * max(_5691, _5687)))
                    {
                        uint _9825_dummy_parameter;
                        int2 _9825 = int2(spvTextureSize(r_colour_m2, uint(0), _9825_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9848;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9848);
                        }
                        _12429 = r_colour_m2.Load(int3(clamp(int2(floor(_5681 * float2(_9825))), int2(0, 0), _9825 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9858;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9858);
                        }
                        _12429 = _9672;
                    }
                    _12424 = _12429;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9868;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9868);
                    }
                    _12424 = _9672;
                }
                _12423 = _12424;
            }
            else
            {
                _12423 = _9672;
            }
            _12422 = _12423;
        }
        else
        {
            _12422 = (((_6948 * _11535.x) + (_6956 * _11535.y)) + (_6964 * _11535.z)) + (_6972 * _11535.w);
        }
        uint _5719 = cbFI_pad0 & 255u;
        bool _12314;
        float3 _12421;
        if (_5719 != 0u)
        {
            float3 _5724 = r_present_backbuffer.Load(int3(_3758, 0)).xyz;
            float3 _5728 = r_current_interpolation_source.Load(int3(_3758, 0)).xyz;
            float3 _5732 = abs(_5724 - _5728);
            float3 _11647;
            if (_5719 == 2u)
            {
                _11647 = (abs(_5728) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11647 = 0.000244140625f.xxx;
            }
            bool _5748 = any(bool3(_5732.x > _11647.x, _5732.y > _11647.y, _5732.z > _11647.z));
            bool3 _12655 = _5748.xxx;
            _12421 = float3(_12655.x ? _5724.x : _12422.x, _12655.y ? _5724.y : _12422.y, _12655.z ? _5724.z : _12422.z);
            _12314 = _5748;
        }
        else
        {
            _12421 = _12422;
            _12314 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9883;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9883);
        }
        float3 _12404;
        if (_5436 == 1u)
        {
            _12404 = lerp(_6948, _6956, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12405;
            if (_5436 == 2u)
            {
                _12405 = lerp(_6964, _6972, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12406;
                if (_5436 == 3u)
                {
                    _12406 = float(_12314).xxx;
                }
                else
                {
                    float3 _12407;
                    if (_5436 == 4u)
                    {
                        _12407 = float3(((_10523 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12408;
                        if (_5436 == 5u)
                        {
                            _12408 = float3(((_6243 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12409;
                            if (_5436 == 6u)
                            {
                                _12409 = float3(_11535.xy, _11535.z + _11535.w);
                            }
                            else
                            {
                                float3 _12410;
                                if (_5436 == 7u)
                                {
                                    _12410 = r_current_interpolation_source.Load(int3(_3758, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12411;
                                    if (_5436 == 8u)
                                    {
                                        _12411 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4174, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12412;
                                        if (_5440)
                                        {
                                            uint _9905_dummy_parameter;
                                            uint _9937_dummy_parameter;
                                            _12412 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4174 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9905_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4174 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9937_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12413;
                                            if (_5443)
                                            {
                                                _12413 = _6964;
                                            }
                                            else
                                            {
                                                float3 _12414;
                                                if (_5436 == 20u)
                                                {
                                                    _12414 = _6948;
                                                }
                                                else
                                                {
                                                    float3 _12415;
                                                    if (_5436 == 21u)
                                                    {
                                                        _12415 = _6956;
                                                    }
                                                    else
                                                    {
                                                        float3 _12416;
                                                        if (_5436 == 22u)
                                                        {
                                                            _12416 = _6972;
                                                        }
                                                        else
                                                        {
                                                            float3 _12417;
                                                            if (_5436 == 18u)
                                                            {
                                                                _12417 = _12061;
                                                            }
                                                            else
                                                            {
                                                                float3 _12418;
                                                                if (_5436 == 19u)
                                                                {
                                                                    _12418 = _11854;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12657 = (_5436 == 23u).xxx;
                                                                    _12418 = float3(_12657.x ? _11652.x : _12421.x, _12657.y ? _11652.y : _12421.y, _12657.z ? _11652.z : _12421.z);
                                                                }
                                                                _12417 = _12418;
                                                            }
                                                            _12416 = _12417;
                                                        }
                                                        _12415 = _12416;
                                                    }
                                                    _12414 = _12415;
                                                }
                                                _12413 = _12414;
                                            }
                                            _12412 = _12413;
                                        }
                                        _12411 = _12412;
                                    }
                                    _12410 = _12411;
                                }
                                _12409 = _12410;
                            }
                            _12408 = _12409;
                        }
                        _12407 = _12408;
                    }
                    _12406 = _12407;
                }
                _12405 = _12406;
            }
            _12404 = _12405;
        }
        float3 _12403;
        if ((_5436 >= 9u) && (_5436 <= 11u))
        {
            uint _5912 = 64u + uint((_10555.y * cbFI_MvDepthLaneSize.x) + _10555.x);
            uint _5916 = rw_nfru_diagnostics.Load<uint>(_5912 * 4 + 0) & 15u;
            float3 _12434;
            if (_5436 == 10u)
            {
                float3 _12402;
                if ((rw_nfru_diagnostics.Load<uint>(_5912 * 4 + 0) & 32u) != 0u)
                {
                    _12402 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12401;
                    if ((rw_nfru_diagnostics.Load<uint>(_5912 * 4 + 0) & 16u) != 0u)
                    {
                        _12401 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5937 = ((rw_nfru_diagnostics.Load<uint>(_5912 * 4 + 0) & 64u) != 0u).xxx;
                        _12401 = float3(_5937.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5937.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5937.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12402 = _12401;
                }
                _12434 = _12402;
            }
            else
            {
                float3 _12435;
                if (_5436 == 11u)
                {
                    uint _5950 = (rw_nfru_diagnostics.Load<uint>(_5912 * 4 + 0) >> 8u) & 15u;
                    uint _5953 = (rw_nfru_diagnostics.Load<uint>(_5912 * 4 + 0) >> 12u) & 15u;
                    float3 _12394;
                    if ((_5916 == 2u) || (_5916 == 3u))
                    {
                        _12394 = _3454[_5916];
                    }
                    else
                    {
                        bool _5965 = _5950 == 3u;
                        bool _5967 = _5953 == 3u;
                        float3 _12395;
                        if (_5965 && _5967)
                        {
                            _12395 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12396;
                            if (_5965)
                            {
                                _12396 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12397;
                                if (_5967)
                                {
                                    _12397 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12398;
                                    if ((_5950 == 4u) || (_5953 == 4u))
                                    {
                                        _12398 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12399;
                                        if ((_5950 == 1u) || (_5953 == 1u))
                                        {
                                            _12399 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12659 = (_5916 == 1u).xxx;
                                            _12399 = float3(_12659.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12659.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12659.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12398 = _12399;
                                    }
                                    _12397 = _12398;
                                }
                                _12396 = _12397;
                            }
                            _12395 = _12396;
                        }
                        _12394 = _12395;
                    }
                    _12435 = _12394;
                }
                else
                {
                    _12435 = _3454[min(_5916, 7u)];
                }
                _12434 = _12435;
            }
            _12403 = _12434;
        }
        else
        {
            _12403 = _12404;
        }
        float4 _12438;
        if ((_5436 >= 14u) && (_5436 <= 16u))
        {
            float2 _12436;
            if (_5436 == 14u)
            {
                uint _6023_dummy_parameter;
                uint _6029_dummy_parameter;
                _12436 = r_flow_tm1.Load(int3(clamp(int2(floor(_4174 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6023_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6029_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12437;
                if (_5436 == 16u)
                {
                    uint _9988 = r_warped_flow_qdata_tm1.Load(int3(_4190, 0)).x & 2147483647u;
                    uint _10020 = uint(max((int((_9988 >> 16u) & 15u) - 6), 0));
                    _12437 = ((float2(float((1 - (2 * int((_9988 >> 15u) & 1u))) * int(((_9988 >> uint(7)) & 127u) << _10020)), float((1 - (2 * int((_9988 >> 14u) & 1u))) * int((_9988 & 127u) << _10020))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12437 = _6243 * float2(cbFI_DisplaySize);
                }
                _12436 = _12437;
            }
            uint2 _6062 = uint2(clamp(round(_12436 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6064 = _6062.x;
            uint _6071 = _6062.y;
            _12438 = float4(float(_6064 & 255u), float((_6064 >> 8u) | ((_6071 & 15u) << 4u)), float(_6071 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12439;
            if (_5436 == 17u)
            {
                _12439 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4190, 0)).x != 0u), _4533, 0.0f, 1.0f);
            }
            else
            {
                _12439 = float4(_12403, 1.0f);
            }
            _12438 = _12439;
        }
        rw_output[_3758] = _12438.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6115 = ((uint(_3758.y) * uint(cbFI_DisplaySize.x)) + uint(_3758.x)) * 6u;
            uint _10066 = spvPackHalf2x16(clamp(_6947.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6115 * 4 + 0, (((_10066 & 32767u) >> 4u) | ((((_10066 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6947.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10101 = spvPackHalf2x16(clamp(_6955.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6115 + 1u) * 4 + 0, (((_10101 & 32767u) >> 4u) | ((((_10101 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6955.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10136 = spvPackHalf2x16(clamp(_6963.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6115 + 2u) * 4 + 0, (((_10136 & 32767u) >> 4u) | ((((_10136 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6963.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10171 = spvPackHalf2x16(clamp(_6971.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6115 + 3u) * 4 + 0, (((_10171 & 32767u) >> 4u) | ((((_10171 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6971.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _10198 = r_current_interpolation_source.Load(int3(_3758, 0));
            uint _10212 = spvPackHalf2x16(clamp(_10198.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6115 + 4u) * 4 + 0, (((_10212 & 32767u) >> 4u) | ((((_10212 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10198.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12472;
            if (_12314 || (_5436 != 0u))
            {
                _12472 = 4294967295u;
            }
            else
            {
                uint _10247 = spvPackHalf2x16(clamp(_12438.xy, 0.0f.xx, 65000.0f.xx));
                _12472 = (((_10247 & 32767u) >> 4u) | ((((_10247 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12438.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6115 + 5u) * 4 + 0, _12472);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3758] = float4(r_current_interpolation_source.Load(int3(_3758, 0)).xyz, 1.0f).xyz;
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
