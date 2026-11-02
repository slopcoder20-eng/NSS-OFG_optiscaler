static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3448[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3735 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3735.x >= cbFI_DisplaySize.x, _3735.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3735] = float4(r_present_backbuffer.Load(int3(_3735, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4141 = (float2(_3735) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4152 = int2(floor(_4141 * float2(cbFI_MvDepthLaneSize)));
        int2 _4157 = int2(floor(_4141 * float2(cbFI_FlowLaneSize)));
        float4 _6190 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4141 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6196 = r_warped_filled_flow_tm1.Load(int3(_4157, 0)).xy;
        float2 _6202 = r_warped_filled_motion_tp1.Load(int3(_4152, 0)).xy;
        bool _6224 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10447;
        if (_6224)
        {
            float _6237 = ((2.0f * _4141.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10447 = float2(atan(_6237) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4141.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6237 * _6237))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10447 = _4141;
        }
        bool _4178 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10468;
        bool _10489;
        int2 _10500;
        float3 _12040;
        if (_4178)
        {
            float _10449;
            float _10451;
            _10451 = 2.0f;
            _10449 = -1.0f;
            uint _3797[9];
            float _12494;
            float _12497;
            for (int _10448 = 0; _10448 < 9; _10451 = _12497, _10449 = _12494, _10448++)
            {
                _3797[_10448] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4152 + int2((_10448 % 3) - 1, (_10448 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3797[_10448] != 0u)
                {
                    float _12489;
                    if (_3797[_10448] == 0u)
                    {
                        _12489 = -1.0f;
                    }
                    else
                    {
                        _12489 = float((_3797[_10448] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12497 = min(_10451, _12489);
                    _12494 = max(_10449, _12489);
                }
                else
                {
                    _12497 = _10451;
                    _12494 = _10449;
                }
            }
            float _4224 = float(_10449 >= 0.0f);
            float3 _10238 = 0.0f.xxx;
            _10238.y = _4224;
            float2 _10469;
            bool _10490;
            int2 _10501;
            float3 _12041;
            if ((_10449 - _10451) > 0.0199999995529651641845703125f)
            {
                float _10457;
                int2 _10458;
                float2 _10459;
                int2 _10461;
                float2 _10467;
                _10467 = _6202;
                _10461 = _4152;
                _10459 = _6202;
                _10458 = _4152;
                _10457 = -1.0f;
                float _12502;
                int2 _12506;
                float2 _12517;
                int2 _12528;
                float2 _12561;
                float _12608;
                int _10456 = 0;
                float _12470 = 1000000000.0f;
                for (; _10456 < 9; _12470 = _12608, _10467 = _12561, _10461 = _12528, _10459 = _12517, _10458 = _12506, _10457 = _12502, _10456++)
                {
                    if (_3797[_10456] == 0u)
                    {
                        _12608 = _12470;
                        _12561 = _10467;
                        _12528 = _10461;
                        _12517 = _10459;
                        _12506 = _10458;
                        _12502 = _10457;
                        continue;
                    }
                    int2 _4259 = clamp(_4152 + int2((_10456 % 3) - 1, (_10456 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6312 = _3797[_10456] & 2147483647u;
                    uint _6344 = uint(max((int((_6312 >> 16u) & 15u) - 6), 0));
                    float2 _4265 = (float2(float((1 - (2 * int((_6312 >> 15u) & 1u))) * int(((_6312 >> uint(7)) & 127u) << _6344)), float((1 - (2 * int((_6312 >> 14u) & 1u))) * int((_6312 & 127u) << _6344))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12456;
                    if (_3797[_10456] == 0u)
                    {
                        _12456 = -1.0f;
                    }
                    else
                    {
                        _12456 = float((_3797[_10456] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4270 = _12456 - 0.100000001490116119384765625f;
                    float2 _12457;
                    if (_6224)
                    {
                        float2 _6421 = clamp((((_10447 + (_4265 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6424 = tan(_6421.x);
                        _12457 = (float2(_6424 / cbFI_DeviceToViewDepth.z, (tan(_6421.y) * sqrt(1.0f + (_6424 * _6424))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12457 = _10447 + (_4265 * cbFI_Timestep);
                    }
                    float _4277 = cbFI_Timestep - 1.0f;
                    float2 _12458;
                    if (_6224)
                    {
                        float2 _6492 = clamp((((_10447 + (_4265 * _4277)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6495 = tan(_6492.x);
                        _12458 = (float2(_6495 / cbFI_DeviceToViewDepth.z, (tan(_6492.y) * sqrt(1.0f + (_6495 * _6495))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12458 = _10447 + (_4265 * _4277);
                    }
                    bool _6528 = all(bool2(_12457.x > 0.0f.xx.x, _12457.y > 0.0f.xx.y));
                    bool _6534;
                    if (_6528)
                    {
                        _6534 = all(bool2(_12457.x < 1.0f.xx.x, _12457.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6534 = _6528;
                    }
                    float _12461;
                    if (_6534)
                    {
                        uint _6541_dummy_parameter;
                        _12461 = max((_4270 - (log(((r_depth_tm1.Load(int3(int2(floor(_12457 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6541_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12461 = 0.0f;
                    }
                    bool _6571 = all(bool2(_12458.x > 0.0f.xx.x, _12458.y > 0.0f.xx.y));
                    bool _6577;
                    if (_6571)
                    {
                        _6577 = all(bool2(_12458.x < 1.0f.xx.x, _12458.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6577 = _6571;
                    }
                    float _12462;
                    if (_6577)
                    {
                        uint _6584_dummy_parameter;
                        _12462 = _12461 + max((_4270 - (log(((r_depth_tp1.Load(int3(int2(floor(_12458 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6584_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12462 = _12461;
                    }
                    float _12503;
                    int2 _12507;
                    float2 _12518;
                    int2 _12529;
                    float2 _12562;
                    float _12609;
                    if (_12462 == 0.0f)
                    {
                        bool _4312 = _4270 > _10457;
                        bool2 _12617 = _4312.xx;
                        _12609 = _12470;
                        _12562 = float2(_12617.x ? _4265.x : _10467.x, _12617.y ? _4265.y : _10467.y);
                        _12529 = int2(_12617.x ? _4259.x : _10461.x, _12617.y ? _4259.y : _10461.y);
                        _12518 = _10459;
                        _12507 = _10458;
                        _12503 = _4312 ? _4270 : _10457;
                    }
                    else
                    {
                        bool _4321 = _12462 < _12470;
                        bool2 _12613 = _4321.xx;
                        _12609 = _4321 ? _12462 : _12470;
                        _12562 = _10467;
                        _12529 = _10461;
                        _12518 = float2(_12613.x ? _4265.x : _10459.x, _12613.y ? _4265.y : _10459.y);
                        _12507 = int2(_12613.x ? _4259.x : _10458.x, _12613.y ? _4259.y : _10458.y);
                        _12503 = _10457;
                    }
                    _12608 = _12609;
                    _12561 = _12562;
                    _12528 = _12529;
                    _12517 = _12518;
                    _12506 = _12507;
                    _12502 = _12503;
                }
                bool _4333 = _10457 < 0.0f;
                bool2 _12623 = _4333.xx;
                int2 _12626 = int2(_12623.x ? _10458.x : _10461.x, _12623.y ? _10458.y : _10461.y);
                _12041 = float3(1.0f, _4224, float(any(bool2(_12626.x != _4152.x, _12626.y != _4152.y))));
                _10501 = _12626;
                _10490 = _4333 ? false : true;
                _10469 = float2(_12623.x ? _10459.x : _10467.x, _12623.y ? _10459.y : _10467.y);
            }
            else
            {
                _12041 = _10238;
                _10501 = _4152;
                _10490 = false;
                _10469 = _6202;
            }
            _12040 = _12041;
            _10500 = _10501;
            _10489 = _10490;
            _10468 = _10469;
        }
        else
        {
            _12040 = 0.0f.xxx;
            _10500 = _4152;
            _10489 = false;
            _10468 = _6202;
        }
        float2 _10470;
        if (_6224)
        {
            float2 _6649 = clamp((((_10447 + (_10468 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6652 = tan(_6649.x);
            _10470 = (float2(_6652 / cbFI_DeviceToViewDepth.z, (tan(_6649.y) * sqrt(1.0f + (_6652 * _6652))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10470 = _10447 + (_10468 * cbFI_Timestep);
        }
        float _4356 = cbFI_Timestep - 1.0f;
        float2 _10472;
        if (_6224)
        {
            float2 _6720 = clamp((((_10447 + (_10468 * _4356)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6723 = tan(_6720.x);
            _10472 = (float2(_6723 / cbFI_DeviceToViewDepth.z, (tan(_6720.y) * sqrt(1.0f + (_6723 * _6723))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10472 = _10447 + (_10468 * _4356);
        }
        float _4361 = -cbFI_Timestep;
        float2 _10473;
        if (_6224)
        {
            float2 _6791 = clamp((((_10447 + (_6196 * _4361)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6794 = tan(_6791.x);
            _10473 = (float2(_6794 / cbFI_DeviceToViewDepth.z, (tan(_6791.y) * sqrt(1.0f + (_6794 * _6794))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10473 = _10447 + (_6196 * _4361);
        }
        float _4366 = 1.0f - cbFI_Timestep;
        float2 _10474;
        if (_6224)
        {
            float2 _6862 = clamp((((_10447 + (_6196 * _4366)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6865 = tan(_6862.x);
            _10474 = (float2(_6865 / cbFI_DeviceToViewDepth.z, (tan(_6862.y) * sqrt(1.0f + (_6865 * _6865))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10474 = _10447 + (_6196 * _4366);
        }
        float4 _6900 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10470, 0.0f);
        float3 _6901 = _6900.xyz;
        float4 _6908 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10472, 0.0f);
        float3 _6909 = _6908.xyz;
        float4 _6916 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10473, 0.0f);
        float3 _6917 = _6916.xyz;
        float4 _6924 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10474, 0.0f);
        float3 _6925 = _6924.xyz;
        float4 _6939 = exp(_6190 - max(max(max(_6190.x, _6190.y), _6190.z), _6190.w).xxxx);
        float4 _6946 = _6939 / (dot(_6939, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4385 = _4178 && (!_10489);
        bool _4394;
        if (_4385)
        {
            _4394 = (_6946.z + _6946.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4394 = _4385;
        }
        bool _4405;
        if (_4394)
        {
            _4405 = length((_10473 - _10470) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4405 = _4394;
        }
        bool _10513;
        if (_4405)
        {
            uint4 _6965 = r_warped_motion_qdata_tp1.Load(int3(_10500, 0));
            uint _6966 = _6965.x;
            bool _10516;
            if (_6966 != 0u)
            {
                float _10502;
                if (_6966 == 0u)
                {
                    _10502 = -1.0f;
                }
                else
                {
                    _10502 = float((_6966 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4415 = _10502 - 0.12000000476837158203125f;
                bool _6985 = all(bool2(_10473.x > 0.0f.xx.x, _10473.y > 0.0f.xx.y));
                bool _6991;
                if (_6985)
                {
                    _6991 = all(bool2(_10473.x < 1.0f.xx.x, _10473.y < 1.0f.xx.y));
                }
                else
                {
                    _6991 = _6985;
                }
                bool _4425;
                if (_6991)
                {
                    uint _6998_dummy_parameter;
                    _4425 = (log(((r_depth_tm1.Load(int3(int2(floor(_10473 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6998_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4415;
                }
                else
                {
                    _4425 = _6991;
                }
                bool _4439;
                if (!_4425)
                {
                    bool _7028 = all(bool2(_10474.x > 0.0f.xx.x, _10474.y > 0.0f.xx.y));
                    bool _7034;
                    if (_7028)
                    {
                        _7034 = all(bool2(_10474.x < 1.0f.xx.x, _10474.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7034 = _7028;
                    }
                    bool _4437;
                    if (_7034)
                    {
                        uint _7041_dummy_parameter;
                        _4437 = (log(((r_depth_tp1.Load(int3(int2(floor(_10474 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7041_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4415;
                    }
                    else
                    {
                        _4437 = _7034;
                    }
                    _4439 = _4437;
                }
                else
                {
                    _4439 = _4425;
                }
                _10516 = _4439;
            }
            else
            {
                _10516 = false;
            }
            _10513 = _10516;
        }
        else
        {
            _10513 = false;
        }
        bool _4444 = _10489 || _10513;
        bool _4449;
        if (_4444)
        {
            bool _7071 = all(bool2(_10470.x > 0.0f.xx.x, _10470.y > 0.0f.xx.y));
            bool _7077;
            if (_7071)
            {
                _7077 = all(bool2(_10470.x < 1.0f.xx.x, _10470.y < 1.0f.xx.y));
            }
            else
            {
                _7077 = _7071;
            }
            _4449 = _7077;
        }
        else
        {
            _4449 = _4444;
        }
        bool _4454;
        if (_4449)
        {
            bool _7082 = all(bool2(_10472.x > 0.0f.xx.x, _10472.y > 0.0f.xx.y));
            bool _7088;
            if (_7082)
            {
                _7088 = all(bool2(_10472.x < 1.0f.xx.x, _10472.y < 1.0f.xx.y));
            }
            else
            {
                _7088 = _7082;
            }
            _4454 = _7088;
        }
        else
        {
            _4454 = _4449;
        }
        float4 _10610;
        if (_4454)
        {
            float _4457 = _6946.x;
            float _4459 = _6946.y;
            float _4460 = _4457 + _4459;
            float _4465 = _6946.z + _6946.w;
            float _10531;
            if (_4460 > 0.001000000047497451305389404296875f)
            {
                _10531 = _4457 / _4460;
            }
            else
            {
                _10531 = _4366;
            }
            _10610 = float4(_4457 + (_4465 * _10531), _4459 + (_4465 * (1.0f - _10531)), 0.0f, 0.0f);
        }
        else
        {
            _10610 = _6946;
        }
        bool _7116 = (cbFI_pad0 & 1024u) != 0u;
        bool _7092 = !_7116;
        bool _7093 = !_7092;
        bool _7110;
        if (_7093)
        {
            _7110 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10500.y * cbFI_MvDepthLaneSize.x) + _10500.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _7110 = _7092;
        }
        bool _7142;
        if (_7093)
        {
            _7142 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4157.y * cbFI_FlowLaneSize.x) + _4157.x)) * 4 + 0) != 0u;
        }
        else
        {
            _7142 = _7092;
        }
        float _4500 = float(_7142);
        bool _10623;
        float4 _10654;
        float3 _11832;
        if (_7116)
        {
            bool _4510;
            if (_7110)
            {
                _4510 = all(bool2(_10470.x > 0.0f.xx.x, _10470.y > 0.0f.xx.y));
            }
            else
            {
                _4510 = _7110;
            }
            bool _4516;
            if (_4510)
            {
                _4516 = all(bool2(_10470.x < 1.0f.xx.x, _10470.y < 1.0f.xx.y));
            }
            else
            {
                _4516 = _4510;
            }
            bool _4523;
            if (_7110)
            {
                _4523 = all(bool2(_10472.x > 0.0f.xx.x, _10472.y > 0.0f.xx.y));
            }
            else
            {
                _4523 = _7110;
            }
            bool _4529;
            if (_4523)
            {
                _4529 = all(bool2(_10472.x < 1.0f.xx.x, _10472.y < 1.0f.xx.y));
            }
            else
            {
                _4529 = _4523;
            }
            bool _4536;
            if (_7142)
            {
                _4536 = all(bool2(_10473.x > 0.0f.xx.x, _10473.y > 0.0f.xx.y));
            }
            else
            {
                _4536 = _7142;
            }
            bool _4542;
            if (_4536)
            {
                _4542 = all(bool2(_10473.x < 1.0f.xx.x, _10473.y < 1.0f.xx.y));
            }
            else
            {
                _4542 = _4536;
            }
            bool _4549;
            if (_7142)
            {
                _4549 = all(bool2(_10474.x > 0.0f.xx.x, _10474.y > 0.0f.xx.y));
            }
            else
            {
                _4549 = _7142;
            }
            bool _4555;
            if (_4549)
            {
                _4555 = all(bool2(_10474.x < 1.0f.xx.x, _10474.y < 1.0f.xx.y));
            }
            else
            {
                _4555 = _4549;
            }
            bool _4557 = !_7110;
            if (_4557)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7184;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7184);
                }
            }
            bool _4562 = !_7142;
            if (_4562)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7194;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7194);
                }
            }
            if (_7110 && _4562)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7204;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7204);
                }
            }
            if (_4557 && _7142)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7214;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7214);
                }
            }
            float _4581 = float(_4516);
            float _4583 = float(_4529);
            bool _4586 = _4542 && _4555;
            float _10565;
            if (_4586)
            {
                _10565 = 1.0f;
            }
            else
            {
                _10565 = (_4542 || _4555) ? 0.5f : 0.0f;
            }
            bool _10570;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4516)) && (!_4529))
            {
                bool _4616;
                if (_4586)
                {
                    float _10568;
                    do
                    {
                        bool _7298 = all(bool2(_10473.x > 0.0f.xx.x, _10473.y > 0.0f.xx.y));
                        bool _7304;
                        if (_7298)
                        {
                            _7304 = all(bool2(_10473.x < 1.0f.xx.x, _10473.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7304 = _7298;
                        }
                        bool _7235 = !_7304;
                        bool _7242;
                        if (!_7235)
                        {
                            bool _7309 = all(bool2(_10474.x > 0.0f.xx.x, _10474.y > 0.0f.xx.y));
                            bool _7315;
                            if (_7309)
                            {
                                _7315 = all(bool2(_10474.x < 1.0f.xx.x, _10474.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7315 = _7309;
                            }
                            _7242 = !_7315;
                        }
                        else
                        {
                            _7242 = _7235;
                        }
                        if (_7242)
                        {
                            _10568 = 0.0f;
                            break;
                        }
                        uint _7322_dummy_parameter;
                        uint _7338_dummy_parameter;
                        float4 _7263 = mul(float4((float2(_10473.x, 1.0f - _10473.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10473 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7322_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7265 = _7263.w;
                        if (abs(_7265) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10568 = 0.0f;
                            break;
                        }
                        float _7276 = abs(cbFI_DeviceToViewDepth.y / ((_7263.z / _7265) - cbFI_DeviceToViewDepth.x));
                        float _7279 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10474 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7338_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10568 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7276 - _7279) / max(max(_7276, _7279), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4616 = _10568 >= 0.5f;
                }
                else
                {
                    _4616 = _4586;
                }
                bool _4624;
                if (_4616)
                {
                    _4624 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4624 = _4616;
                }
                bool _10571;
                if (_4624)
                {
                    uint _7388_dummy_parameter;
                    float2 _10569;
                    do
                    {
                        float _7414 = 1.0f - _10473.y;
                        float4 _7425 = mul(float4((float2(_10473.x, _7414) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10473 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7388_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7427 = _7425.w;
                        if (!(_7427 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10569 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7440 = ((_7425.xy / _7427.xx) + 1.0f.xx) * 0.5f;
                        _10569 = float2(_7440.x - _10473.x, _7414 - _7440.y);
                        break;
                    } while(false);
                    float2 _4637 = float2(cbFI_DisplaySize);
                    _10571 = length(((_10473 + _10569) - _10474) * _4637) <= ((0.100000001490116119384765625f * length(_10569 * _4637)) + 8.0f);
                }
                else
                {
                    _10571 = _4616;
                }
                _10570 = _10571;
            }
            else
            {
                _10570 = true;
            }
            bool _4651 = !_10570;
            bool _12627 = _4651 ? false : _4555;
            bool _12628 = _4651 ? false : _4542;
            bool _10624;
            float4 _10655;
            if (!(((_4516 && _4529) && _12628) && _12627))
            {
                float4 _4673 = _10610 * float4(_4581, _4583, float(_12628), float(_12627));
                float _4675 = dot(_4673, 1.0f.xxxx);
                bool _4678 = !(_4675 > 0.0f);
                float4 _10656;
                if (!_4678)
                {
                    _10656 = _4673 / _4675.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7462;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7462);
                    }
                    _10656 = 0.0f.xxxx;
                }
                _10655 = _10656;
                _10624 = _4678;
            }
            else
            {
                _10655 = _10610;
                _10624 = false;
            }
            _11832 = float3(_4581, _4583, _10565);
            _10654 = _10655;
            _10623 = _10624;
        }
        else
        {
            _11832 = float3(float(_7110), _4500, 0.0f);
            _10654 = _10610;
            _10623 = false;
        }
        bool _4696 = !_10623;
        float4 _10739;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4696)
        {
            float _4703 = _10654.x + _10654.y;
            float4 _10740;
            if (_4703 > 0.001000000047497451305389404296875f)
            {
                _10740 = float4(_10654.x / _4703, _10654.y / _4703, 0.0f, 0.0f);
            }
            else
            {
                _10740 = float4(_4366, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10739 = _10740;
        }
        else
        {
            _10739 = _10654;
        }
        float4 _10916;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4696) && _7110)
        {
            float _10713;
            do
            {
                uint4 _7602 = r_warped_motion_qdata_tp1.Load(int3(_10500, 0));
                uint _7603 = _7602.x;
                if (_7603 != 0u)
                {
                    float _10712;
                    if (_7603 == 0u)
                    {
                        _10712 = -1.0f;
                    }
                    else
                    {
                        _10712 = float((_7603 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10713 = _10712;
                    break;
                }
                int _10695;
                uint _10696;
                _10696 = _7603;
                _10695 = -1;
                uint _10711;
                for (; _10695 <= 1; _10696 = _10711, _10695++)
                {
                    _10711 = _10696;
                    for (int _10709 = -1; _10709 <= 1; )
                    {
                        _10711 = max(_10711, r_warped_motion_qdata_tp1.Load(int3(clamp(_10500 + int2(_10709, _10695), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10709++;
                        continue;
                    }
                }
                if (_10696 != 0u)
                {
                    float _10708;
                    if (_10696 == 0u)
                    {
                        _10708 = -1.0f;
                    }
                    else
                    {
                        _10708 = float((_10696 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10713 = _10708;
                    break;
                }
                uint _10698;
                _10698 = 4294967295u;
                uint _12598;
                for (int _10697 = 0; _10697 < 8; _10698 = _12598, _10697++)
                {
                    int _10701 = 0;
                    for (;;)
                    {
                        if (_10701 < 5)
                        {
                            int2 _7553 = _10500 + (_1085[_10697] * _1094[_10701].xx);
                            bool _7556 = any(bool2(_7553.x < int2(0, 0).x, _7553.y < int2(0, 0).y));
                            bool _7564;
                            if (!_7556)
                            {
                                _7564 = any(bool2(_7553.x >= cbFI_MvDepthLaneSize.x, _7553.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7564 = _7556;
                            }
                            if (_7564)
                            {
                                _12598 = _10698;
                                break;
                            }
                            uint4 _7642 = r_warped_motion_qdata_tp1.Load(int3(_7553, 0));
                            uint _7643 = _7642.x;
                            if (_7643 != 0u)
                            {
                                _12598 = min(_10698, _7643);
                                break;
                            }
                            _10701++;
                            continue;
                        }
                        else
                        {
                            _12598 = _10698;
                            break;
                        }
                    }
                }
                float _10700;
                if (_10698 == 4294967295u)
                {
                    _10700 = -1.0f;
                }
                else
                {
                    float _10699;
                    if (_10698 == 0u)
                    {
                        _10699 = -1.0f;
                    }
                    else
                    {
                        _10699 = float((_10698 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10700 = _10699;
                }
                _10713 = _10700;
                break;
            } while(false);
            float _4739 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4742 = r_warped_motion_qdata_tp1.Load(int3(_10500, 0)).x == 0u;
            bool _4748;
            if (_4742)
            {
                bool _7668 = all(bool2(_10470.x > 0.0f.xx.x, _10470.y > 0.0f.xx.y));
                bool _7674;
                if (_7668)
                {
                    _7674 = all(bool2(_10470.x < 1.0f.xx.x, _10470.y < 1.0f.xx.y));
                }
                else
                {
                    _7674 = _7668;
                }
                _4748 = _7674;
            }
            else
            {
                _4748 = _4742;
            }
            bool _4753;
            if (_4748)
            {
                bool _7679 = all(bool2(_10472.x > 0.0f.xx.x, _10472.y > 0.0f.xx.y));
                bool _7685;
                if (_7679)
                {
                    _7685 = all(bool2(_10472.x < 1.0f.xx.x, _10472.y < 1.0f.xx.y));
                }
                else
                {
                    _7685 = _7679;
                }
                _4753 = _7685;
            }
            else
            {
                _4753 = _4748;
            }
            bool _10725;
            float4 _10734;
            if (_4753)
            {
                uint _7692_dummy_parameter;
                float _7716 = log(((r_depth_tm1.Load(int3(int2(floor(_10470 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7692_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _7724_dummy_parameter;
                float _7748 = log(((r_depth_tp1.Load(int3(int2(floor(_10472 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7724_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _4764 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4771;
                if (_4764)
                {
                    _4771 = _7748 > (_7716 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4771 = _4764;
                }
                bool _10730;
                float4 _10752;
                if (_4771)
                {
                    _10752 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _10730 = true;
                }
                else
                {
                    bool _4777 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _4784;
                    if (_4777)
                    {
                        _4784 = _7716 > (_7748 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _4784 = _4777;
                    }
                    bool4 _12629 = _4784.xxxx;
                    _10752 = float4(_12629.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10739.x, _12629.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10739.y, _12629.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10739.z, _12629.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10739.w);
                    _10730 = _4784 ? true : false;
                }
                _10734 = _10752;
                _10725 = _10730;
            }
            else
            {
                _10734 = _10739;
                _10725 = false;
            }
            float4 _10807;
            if (_10725)
            {
                _10807 = 1.0f.xxxx;
            }
            else
            {
                bool _4795 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4801;
                if (_4795)
                {
                    _4801 = _10734.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4801 = _4795;
                }
                bool _4806;
                if (_4801)
                {
                    bool _7754 = all(bool2(_10472.x > 0.0f.xx.x, _10472.y > 0.0f.xx.y));
                    bool _7760;
                    if (_7754)
                    {
                        _7760 = all(bool2(_10472.x < 1.0f.xx.x, _10472.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7760 = _7754;
                    }
                    _4806 = _7760;
                }
                else
                {
                    _4806 = _4801;
                }
                float4 _10808;
                if (_4806)
                {
                    float _10761;
                    if (_10713 >= 0.0f)
                    {
                        _10761 = _10713 - _4739;
                    }
                    else
                    {
                        float _10757;
                        _10757 = 2.0f;
                        float _7817;
                        for (int _10756 = 0; _10756 < 24; _10757 = _7817, _10756++)
                        {
                            float _7781 = float(_10756 & 7) * 0.785398185253143310546875f;
                            int _7783 = _10756 >> 3;
                            int _10758;
                            if (_7783 == 0)
                            {
                                _10758 = 16;
                            }
                            else
                            {
                                _10758 = (_7783 == 1) ? 48 : 96;
                            }
                            uint _7849_dummy_parameter;
                            _7817 = min(_10757, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10472 + ((cbFI_MvDepthLaneSizeRcp * float(_10758)) * float2(cos(_7781), sin(_7781))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7849_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10761 = _10757;
                    }
                    uint _7881_dummy_parameter;
                    float4 _10809;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_10472 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7881_dummy_parameter))))), 0)).x) > ((exp((_10761 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10809 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10809 = 1.0f.xxxx;
                    }
                    _10808 = _10809;
                }
                else
                {
                    _10808 = 1.0f.xxxx;
                }
                _10807 = _10808;
            }
            bool _4834 = _10713 >= 0.0f;
            bool _4835 = (!_10725) && _4834;
            bool _4842;
            if (_4835)
            {
                _4842 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4842 = _4835;
            }
            bool _4848;
            if (_4842)
            {
                _4848 = _10734.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4848 = _4842;
            }
            bool _4853;
            if (_4848)
            {
                bool _7906 = all(bool2(_10470.x > 0.0f.xx.x, _10470.y > 0.0f.xx.y));
                bool _7912;
                if (_7906)
                {
                    _7912 = all(bool2(_10470.x < 1.0f.xx.x, _10470.y < 1.0f.xx.y));
                }
                else
                {
                    _7912 = _7906;
                }
                _4853 = _7912;
            }
            else
            {
                _4853 = _4848;
            }
            float4 _10832;
            if (_4853)
            {
                float _10801;
                if (_4834)
                {
                    _10801 = _10713 - _4739;
                }
                else
                {
                    float _10797;
                    _10797 = 2.0f;
                    float _7969;
                    for (int _10796 = 0; _10796 < 24; _10797 = _7969, _10796++)
                    {
                        float _7933 = float(_10796 & 7) * 0.785398185253143310546875f;
                        int _7935 = _10796 >> 3;
                        int _10798;
                        if (_7935 == 0)
                        {
                            _10798 = 16;
                        }
                        else
                        {
                            _10798 = (_7935 == 1) ? 48 : 96;
                        }
                        uint _7985_dummy_parameter;
                        _7969 = min(_10797, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10470 + ((cbFI_MvDepthLaneSizeRcp * float(_10798)) * float2(cos(_7933), sin(_7933))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7985_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10801 = _10797;
                }
                uint _8033_dummy_parameter;
                float4 _10833;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_10470 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8033_dummy_parameter))))), 0)).x) > ((exp((_10801 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10310 = _10807;
                    _10310.x = 0.0f;
                    _10833 = _10310;
                }
                else
                {
                    _10833 = _10807;
                }
                _10832 = _10833;
            }
            else
            {
                _10832 = _10807;
            }
            float4 _10845;
            if (_4835)
            {
                float _8060 = (exp(((_10713 - _4739) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _4891 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4897;
                if (_4891)
                {
                    _4897 = _10734.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4897 = _4891;
                }
                bool _4902;
                if (_4897)
                {
                    bool _8065 = all(bool2(_10474.x > 0.0f.xx.x, _10474.y > 0.0f.xx.y));
                    bool _8071;
                    if (_8065)
                    {
                        _8071 = all(bool2(_10474.x < 1.0f.xx.x, _10474.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8071 = _8065;
                    }
                    _4902 = _8071;
                }
                else
                {
                    _4902 = _4897;
                }
                bool _4910;
                if (_4902)
                {
                    uint _8078_dummy_parameter;
                    _4910 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10474 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8078_dummy_parameter))))), 0)).x) > _8060;
                }
                else
                {
                    _4910 = _4902;
                }
                float4 _10843;
                if (_4910)
                {
                    float4 _10313 = _10832;
                    _10313.w = 0.0f;
                    _10843 = _10313;
                }
                else
                {
                    _10843 = _10832;
                }
                bool _4917 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4923;
                if (_4917)
                {
                    _4923 = _10734.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4923 = _4917;
                }
                bool _4928;
                if (_4923)
                {
                    bool _8096 = all(bool2(_10473.x > 0.0f.xx.x, _10473.y > 0.0f.xx.y));
                    bool _8102;
                    if (_8096)
                    {
                        _8102 = all(bool2(_10473.x < 1.0f.xx.x, _10473.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8102 = _8096;
                    }
                    _4928 = _8102;
                }
                else
                {
                    _4928 = _4923;
                }
                bool _4936;
                if (_4928)
                {
                    uint _8109_dummy_parameter;
                    _4936 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10473 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8109_dummy_parameter))))), 0)).x) > _8060;
                }
                else
                {
                    _4936 = _4928;
                }
                float4 _10846;
                if (_4936)
                {
                    float4 _10316 = _10843;
                    _10316.z = 0.0f;
                    _10846 = _10316;
                }
                else
                {
                    _10846 = _10843;
                }
                _10845 = _10846;
            }
            else
            {
                _10845 = _10832;
            }
            float4 _10917;
            if (any(bool4(_10845.x < 1.0f.xxxx.x, _10845.y < 1.0f.xxxx.y, _10845.z < 1.0f.xxxx.z, _10845.w < 1.0f.xxxx.w)))
            {
                float4 _4947 = _10734 * _10845;
                float _4949 = dot(_4947, 1.0f.xxxx);
                float4 _10918;
                if (_4949 > 0.0f)
                {
                    _10918 = _4947 / _4949.xxxx;
                }
                else
                {
                    bool _4960 = _10845.y == 0.0f;
                    bool _4966;
                    if (_4960)
                    {
                        _4966 = _10845.x > 0.0f;
                    }
                    else
                    {
                        _4966 = _4960;
                    }
                    bool _4971;
                    if (_4966)
                    {
                        bool _8127 = all(bool2(_10470.x > 0.0f.xx.x, _10470.y > 0.0f.xx.y));
                        bool _8133;
                        if (_8127)
                        {
                            _8133 = all(bool2(_10470.x < 1.0f.xx.x, _10470.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8133 = _8127;
                        }
                        _4971 = _8133;
                    }
                    else
                    {
                        _4971 = _4966;
                    }
                    float4 _10919;
                    if (_4971)
                    {
                        _10919 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4976 = _10845.x == 0.0f;
                        bool _4982;
                        if (_4976)
                        {
                            _4982 = _10845.y > 0.0f;
                        }
                        else
                        {
                            _4982 = _4976;
                        }
                        bool _4987;
                        if (_4982)
                        {
                            bool _8138 = all(bool2(_10472.x > 0.0f.xx.x, _10472.y > 0.0f.xx.y));
                            bool _8144;
                            if (_8138)
                            {
                                _8144 = all(bool2(_10472.x < 1.0f.xx.x, _10472.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _8144 = _8138;
                            }
                            _4987 = _8144;
                        }
                        else
                        {
                            _4987 = _4982;
                        }
                        bool4 _12632 = _4987.xxxx;
                        _10919 = float4(_12632.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10734.x, _12632.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10734.y, _12632.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10734.z, _12632.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10734.w);
                    }
                    _10918 = _10919;
                }
                _10917 = _10918;
            }
            else
            {
                _10917 = _10734;
            }
            _10916 = _10917;
        }
        else
        {
            _10916 = _10739;
        }
        float4 _11495;
        bool _11515;
        float3 _11629;
        if (((cbFI_pad0 & 32768u) != 0u) && _4696)
        {
            bool _5004 = _10916.x > 0.00999999977648258209228515625f;
            bool _5007 = _10916.y > 0.00999999977648258209228515625f;
            bool _5016 = (_10916.z + _10916.w) > 0.0199999995529651641845703125f;
            bool _5022;
            if (_5016)
            {
                bool _8149 = all(bool2(_10473.x > 0.0f.xx.x, _10473.y > 0.0f.xx.y));
                bool _8155;
                if (_8149)
                {
                    _8155 = all(bool2(_10473.x < 1.0f.xx.x, _10473.y < 1.0f.xx.y));
                }
                else
                {
                    _8155 = _8149;
                }
                _5022 = _8155;
            }
            else
            {
                _5022 = _5016;
            }
            bool _5027;
            if (_5022)
            {
                bool _8160 = all(bool2(_10474.x > 0.0f.xx.x, _10474.y > 0.0f.xx.y));
                bool _8166;
                if (_8160)
                {
                    _8166 = all(bool2(_10474.x < 1.0f.xx.x, _10474.y < 1.0f.xx.y));
                }
                else
                {
                    _8166 = _8160;
                }
                _5027 = _8166;
            }
            else
            {
                _5027 = _5022;
            }
            bool _5034;
            if (_5027)
            {
                float _10927;
                do
                {
                    bool _8249 = all(bool2(_10473.x > 0.0f.xx.x, _10473.y > 0.0f.xx.y));
                    bool _8255;
                    if (_8249)
                    {
                        _8255 = all(bool2(_10473.x < 1.0f.xx.x, _10473.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8255 = _8249;
                    }
                    bool _8186 = !_8255;
                    bool _8193;
                    if (!_8186)
                    {
                        bool _8260 = all(bool2(_10474.x > 0.0f.xx.x, _10474.y > 0.0f.xx.y));
                        bool _8266;
                        if (_8260)
                        {
                            _8266 = all(bool2(_10474.x < 1.0f.xx.x, _10474.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8266 = _8260;
                        }
                        _8193 = !_8266;
                    }
                    else
                    {
                        _8193 = _8186;
                    }
                    if (_8193)
                    {
                        _10927 = 0.0f;
                        break;
                    }
                    uint _8273_dummy_parameter;
                    uint _8289_dummy_parameter;
                    float4 _8214 = mul(float4((float2(_10473.x, 1.0f - _10473.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10473 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8273_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _8216 = _8214.w;
                    if (abs(_8216) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10927 = 0.0f;
                        break;
                    }
                    float _8227 = abs(cbFI_DeviceToViewDepth.y / ((_8214.z / _8216) - cbFI_DeviceToViewDepth.x));
                    float _8230 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10474 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8289_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10927 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8227 - _8230) / max(max(_8227, _8230), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5034 = _10927 < 0.5f;
            }
            else
            {
                _5034 = _5027;
            }
            float4 _10942;
            if (_5034)
            {
                uint _8339_dummy_parameter;
                uint _8370_dummy_parameter;
                float4 _10943;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10473 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8339_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10474 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8370_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10943 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10943 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10942 = _10943;
            }
            else
            {
                _10942 = 1.0f.xxxx;
            }
            bool _5058;
            if (_7110)
            {
                bool _8399 = all(bool2(_10470.x > 0.0f.xx.x, _10470.y > 0.0f.xx.y));
                bool _8405;
                if (_8399)
                {
                    _8405 = all(bool2(_10470.x < 1.0f.xx.x, _10470.y < 1.0f.xx.y));
                }
                else
                {
                    _8405 = _8399;
                }
                _5058 = _8405;
            }
            else
            {
                _5058 = _7110;
            }
            bool _5064;
            if (_7110)
            {
                bool _8410 = all(bool2(_10472.x > 0.0f.xx.x, _10472.y > 0.0f.xx.y));
                bool _8416;
                if (_8410)
                {
                    _8416 = all(bool2(_10472.x < 1.0f.xx.x, _10472.y < 1.0f.xx.y));
                }
                else
                {
                    _8416 = _8410;
                }
                _5064 = _8416;
            }
            else
            {
                _5064 = _7110;
            }
            bool _5070;
            if (_7142)
            {
                bool _8421 = all(bool2(_10473.x > 0.0f.xx.x, _10473.y > 0.0f.xx.y));
                bool _8427;
                if (_8421)
                {
                    _8427 = all(bool2(_10473.x < 1.0f.xx.x, _10473.y < 1.0f.xx.y));
                }
                else
                {
                    _8427 = _8421;
                }
                _5070 = _8427;
            }
            else
            {
                _5070 = _7142;
            }
            bool _5076;
            if (_7142)
            {
                bool _8432 = all(bool2(_10474.x > 0.0f.xx.x, _10474.y > 0.0f.xx.y));
                bool _8438;
                if (_8432)
                {
                    _8438 = all(bool2(_10474.x < 1.0f.xx.x, _10474.y < 1.0f.xx.y));
                }
                else
                {
                    _8438 = _8432;
                }
                _5076 = _8438;
            }
            else
            {
                _5076 = _7142;
            }
            bool _5079 = _5070 != _5076;
            bool _5085;
            if (_5079)
            {
                _5085 = _5058 || _5064;
            }
            else
            {
                _5085 = _5079;
            }
            float4 _11041;
            if (_5085)
            {
                float4 _10343 = _10942;
                _10343.z = 0.0f;
                _10343.w = 0.0f;
                _11041 = _10343;
            }
            else
            {
                _11041 = _10942;
            }
            bool _5092 = _5058 && _5004;
            bool _5095 = _5064 && _5007;
            float4 _11146;
            float3 _11730;
            if (_5092 || _5095)
            {
                float _11036;
                do
                {
                    uint4 _8577 = r_warped_motion_qdata_tp1.Load(int3(_10500, 0));
                    uint _8578 = _8577.x;
                    if (_8578 != 0u)
                    {
                        float _11035;
                        if (_8578 == 0u)
                        {
                            _11035 = -1.0f;
                        }
                        else
                        {
                            _11035 = float((_8578 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11036 = _11035;
                        break;
                    }
                    int _11018;
                    uint _11019;
                    _11019 = _8578;
                    _11018 = -1;
                    uint _11034;
                    for (; _11018 <= 1; _11019 = _11034, _11018++)
                    {
                        _11034 = _11019;
                        for (int _11032 = -1; _11032 <= 1; )
                        {
                            _11034 = max(_11034, r_warped_motion_qdata_tp1.Load(int3(clamp(_10500 + int2(_11032, _11018), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11032++;
                            continue;
                        }
                    }
                    if (_11019 != 0u)
                    {
                        float _11031;
                        if (_11019 == 0u)
                        {
                            _11031 = -1.0f;
                        }
                        else
                        {
                            _11031 = float((_11019 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11036 = _11031;
                        break;
                    }
                    uint _11021;
                    _11021 = 4294967295u;
                    uint _12599;
                    for (int _11020 = 0; _11020 < 8; _11021 = _12599, _11020++)
                    {
                        int _11024 = 0;
                        for (;;)
                        {
                            if (_11024 < 5)
                            {
                                int2 _8528 = _10500 + (_1085[_11020] * _1094[_11024].xx);
                                bool _8531 = any(bool2(_8528.x < int2(0, 0).x, _8528.y < int2(0, 0).y));
                                bool _8539;
                                if (!_8531)
                                {
                                    _8539 = any(bool2(_8528.x >= cbFI_MvDepthLaneSize.x, _8528.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8539 = _8531;
                                }
                                if (_8539)
                                {
                                    _12599 = _11021;
                                    break;
                                }
                                uint4 _8617 = r_warped_motion_qdata_tp1.Load(int3(_8528, 0));
                                uint _8618 = _8617.x;
                                if (_8618 != 0u)
                                {
                                    _12599 = min(_11021, _8618);
                                    break;
                                }
                                _11024++;
                                continue;
                            }
                            else
                            {
                                _12599 = _11021;
                                break;
                            }
                        }
                    }
                    float _11023;
                    if (_11021 == 4294967295u)
                    {
                        _11023 = -1.0f;
                    }
                    else
                    {
                        float _11022;
                        if (_11021 == 0u)
                        {
                            _11022 = -1.0f;
                        }
                        else
                        {
                            _11022 = float((_11021 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11023 = _11022;
                    }
                    _11036 = _11023;
                    break;
                } while(false);
                bool _5103 = _11036 < 0.0f;
                float _11037;
                if (_5103)
                {
                    _11037 = 0.0f;
                }
                else
                {
                    _11037 = _11036 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8639_dummy_parameter;
                uint _8671_dummy_parameter;
                float4 _11074;
                if ((_5103 && _5092) && _5095)
                {
                    uint _8703_dummy_parameter;
                    float _8727 = log(((r_depth_tm1.Load(int3(int2(floor(_10470 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8703_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8735_dummy_parameter;
                    float _8759 = log(((r_depth_tp1.Load(int3(int2(floor(_10472 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8735_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _11075;
                    if (_8727 > (_8759 + 0.07999999821186065673828125f))
                    {
                        float4 _10347 = _11041;
                        _10347.x = 0.0f;
                        _11075 = _10347;
                    }
                    else
                    {
                        float4 _11076;
                        if (_8759 > (_8727 + 0.07999999821186065673828125f))
                        {
                            float4 _10349 = _11041;
                            _10349.y = 0.0f;
                            _11076 = _10349;
                        }
                        else
                        {
                            _11076 = _11041;
                        }
                        _11075 = _11076;
                    }
                    _11074 = _11075;
                }
                else
                {
                    _11074 = _11041;
                }
                float _5155 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5157 = _11036 >= 0.0f;
                float _11057;
                if (_5157)
                {
                    _11057 = _11036 - _5155;
                }
                else
                {
                    float _11053;
                    if (_5092)
                    {
                        float _11052;
                        _11052 = 2.0f;
                        float _8817;
                        for (int _11051 = 0; _11051 < 24; _11052 = _8817, _11051++)
                        {
                            float _8781 = float(_11051 & 7) * 0.785398185253143310546875f;
                            int _8783 = _11051 >> 3;
                            int _11054;
                            if (_8783 == 0)
                            {
                                _11054 = 16;
                            }
                            else
                            {
                                _11054 = (_8783 == 1) ? 48 : 96;
                            }
                            uint _8833_dummy_parameter;
                            _8817 = min(_11052, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10470 + ((cbFI_MvDepthLaneSizeRcp * float(_11054)) * float2(cos(_8781), sin(_8781))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8833_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11053 = _11052;
                    }
                    else
                    {
                        _11053 = 0.0f;
                    }
                    _11057 = _11053;
                }
                float _11064;
                if (_5157)
                {
                    _11064 = _11036 - _5155;
                }
                else
                {
                    float _11060;
                    if (_5095)
                    {
                        float _11059;
                        _11059 = 2.0f;
                        float _8931;
                        for (int _11058 = 0; _11058 < 24; _11059 = _8931, _11058++)
                        {
                            float _8895 = float(_11058 & 7) * 0.785398185253143310546875f;
                            int _8897 = _11058 >> 3;
                            int _11061;
                            if (_8897 == 0)
                            {
                                _11061 = 16;
                            }
                            else
                            {
                                _11061 = (_8897 == 1) ? 48 : 96;
                            }
                            uint _8963_dummy_parameter;
                            _8931 = min(_11059, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10472 + ((cbFI_MvDepthLaneSizeRcp * float(_11061)) * float2(cos(_8895), sin(_8895))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8963_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11060 = _11059;
                    }
                    else
                    {
                        _11060 = 0.0f;
                    }
                    _11064 = _11060;
                }
                float _11065;
                if (_5092)
                {
                    uint _8995_dummy_parameter;
                    _11065 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_10470 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8995_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11065 = 0.0f;
                }
                float _11066;
                if (_5095)
                {
                    uint _9015_dummy_parameter;
                    _11066 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_10472 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9015_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11066 = 0.0f;
                }
                bool _5212;
                if (_5092)
                {
                    _5212 = _11065 > ((exp((_11057 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5212 = _5092;
                }
                float4 _11082;
                if (_5212)
                {
                    float4 _10351 = _11074;
                    _10351.x = 0.0f;
                    _11082 = _10351;
                }
                else
                {
                    _11082 = _11074;
                }
                bool _5224;
                if (_5095)
                {
                    _5224 = _11066 > ((exp((_11064 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5224 = _5095;
                }
                float4 _11084;
                if (_5224)
                {
                    float4 _10353 = _11082;
                    _10353.y = 0.0f;
                    _11084 = _10353;
                }
                else
                {
                    _11084 = _11082;
                }
                float4 _11147;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5157)
                {
                    bool _5244;
                    if (_5092)
                    {
                        _5244 = _11065 < ((exp((_11057 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5244 = _5092;
                    }
                    float4 _11086;
                    if (_5244)
                    {
                        float4 _10355 = _11084;
                        _10355.x = 0.0f;
                        _11086 = _10355;
                    }
                    else
                    {
                        _11086 = _11084;
                    }
                    bool _5256;
                    if (_5095)
                    {
                        _5256 = _11066 < ((exp((_11064 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5256 = _5095;
                    }
                    float4 _11148;
                    if (_5256)
                    {
                        float4 _10357 = _11086;
                        _10357.y = 0.0f;
                        _11148 = _10357;
                    }
                    else
                    {
                        _11148 = _11086;
                    }
                    _11147 = _11148;
                }
                else
                {
                    _11147 = _11084;
                }
                _11730 = float3(_11037, log(((r_depth_tm1.Load(int3(int2(floor(_10470 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8639_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_10472 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8671_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _11146 = _11147;
            }
            else
            {
                _11730 = float3(0.0f, 0.0f, 0.5f);
                _11146 = _11041;
            }
            bool _5267 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5016;
            bool _5273;
            if (_5267)
            {
                _5273 = _5070 || _5076;
            }
            else
            {
                _5273 = _5267;
            }
            float4 _11169;
            if (_5273)
            {
                float _11141;
                do
                {
                    uint4 _9195 = r_warped_motion_qdata_tp1.Load(int3(_10500, 0));
                    uint _9196 = _9195.x;
                    if (_9196 != 0u)
                    {
                        float _11140;
                        if (_9196 == 0u)
                        {
                            _11140 = -1.0f;
                        }
                        else
                        {
                            _11140 = float((_9196 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11141 = _11140;
                        break;
                    }
                    int _11123;
                    uint _11124;
                    _11124 = _9196;
                    _11123 = -1;
                    uint _11139;
                    for (; _11123 <= 1; _11124 = _11139, _11123++)
                    {
                        _11139 = _11124;
                        for (int _11137 = -1; _11137 <= 1; )
                        {
                            _11139 = max(_11139, r_warped_motion_qdata_tp1.Load(int3(clamp(_10500 + int2(_11137, _11123), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11137++;
                            continue;
                        }
                    }
                    if (_11124 != 0u)
                    {
                        float _11136;
                        if (_11124 == 0u)
                        {
                            _11136 = -1.0f;
                        }
                        else
                        {
                            _11136 = float((_11124 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11141 = _11136;
                        break;
                    }
                    uint _11126;
                    _11126 = 4294967295u;
                    uint _12600;
                    for (int _11125 = 0; _11125 < 8; _11126 = _12600, _11125++)
                    {
                        int _11129 = 0;
                        for (;;)
                        {
                            if (_11129 < 5)
                            {
                                int2 _9146 = _10500 + (_1085[_11125] * _1094[_11129].xx);
                                bool _9149 = any(bool2(_9146.x < int2(0, 0).x, _9146.y < int2(0, 0).y));
                                bool _9157;
                                if (!_9149)
                                {
                                    _9157 = any(bool2(_9146.x >= cbFI_MvDepthLaneSize.x, _9146.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _9157 = _9149;
                                }
                                if (_9157)
                                {
                                    _12600 = _11126;
                                    break;
                                }
                                uint4 _9235 = r_warped_motion_qdata_tp1.Load(int3(_9146, 0));
                                uint _9236 = _9235.x;
                                if (_9236 != 0u)
                                {
                                    _12600 = min(_11126, _9236);
                                    break;
                                }
                                _11129++;
                                continue;
                            }
                            else
                            {
                                _12600 = _11126;
                                break;
                            }
                        }
                    }
                    float _11128;
                    if (_11126 == 4294967295u)
                    {
                        _11128 = -1.0f;
                    }
                    else
                    {
                        float _11127;
                        if (_11126 == 0u)
                        {
                            _11127 = -1.0f;
                        }
                        else
                        {
                            _11127 = float((_11126 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11128 = _11127;
                    }
                    _11141 = _11128;
                    break;
                } while(false);
                float4 _11170;
                if (_11141 >= 0.0f)
                {
                    float _9257 = (exp((_11141 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5292;
                    if (_5070)
                    {
                        uint _9264_dummy_parameter;
                        _5292 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10473 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9264_dummy_parameter))))), 0)).x) > _9257;
                    }
                    else
                    {
                        _5292 = _5070;
                    }
                    float4 _11159;
                    if (_5292)
                    {
                        float4 _10359 = _11146;
                        _10359.z = 0.0f;
                        _11159 = _10359;
                    }
                    else
                    {
                        _11159 = _11146;
                    }
                    bool _5304;
                    if (_5076)
                    {
                        uint _9284_dummy_parameter;
                        _5304 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10474 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9284_dummy_parameter))))), 0)).x) > _9257;
                    }
                    else
                    {
                        _5304 = _5076;
                    }
                    float4 _11171;
                    if (_5304)
                    {
                        float4 _10361 = _11159;
                        _10361.w = 0.0f;
                        _11171 = _10361;
                    }
                    else
                    {
                        _11171 = _11159;
                    }
                    _11170 = _11171;
                }
                else
                {
                    _11170 = _11146;
                }
                _11169 = _11170;
            }
            else
            {
                _11169 = _11146;
            }
            bool _5312 = _5058 != _5064;
            bool _5319;
            if (_5312)
            {
                _5319 = _5058 ? _5004 : _5007;
            }
            else
            {
                _5319 = _5312;
            }
            bool _5326;
            if (_5319)
            {
                _5326 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5326 = _5319;
            }
            float4 _11254;
            if (_5326)
            {
                bool2 _5331 = _5058.xx;
                float2 _5332 = float2(_5331.x ? _10470.x : _10472.x, _5331.y ? _10470.y : _10472.y);
                float _11161;
                if (_5058)
                {
                    uint _9304_dummy_parameter;
                    _11161 = r_depth_tm1.Load(int3(int2(floor(_5332 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9304_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9320_dummy_parameter;
                    _11161 = r_depth_tp1.Load(int3(int2(floor(_5332 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9320_dummy_parameter))))), 0)).x;
                }
                float4x4 _11162;
                if (_5058)
                {
                    _11162 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _11162 = cbFI_MotionTP1ToTM1;
                }
                float2 _11163;
                do
                {
                    float _9347 = _5332.x;
                    float _9350 = 1.0f - _5332.y;
                    float4 _9361 = mul(float4((float2(_9347, _9350) * 2.0f) - 1.0f.xx, _11161, 1.0f), _11162);
                    float _9363 = _9361.w;
                    if (!(_9363 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11163 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9376 = ((_9361.xy / _9363.xx) + 1.0f.xx) * 0.5f;
                    _11163 = float2(_9376.x - _9347, _9350 - _9376.y);
                    break;
                } while(false);
                float2 _5362 = float2(cbFI_DisplaySize);
                float4 _11255;
                if (!(length(((_5332 + _11163) - float2(_5331.x ? _10472.x : _10470.x, _5331.y ? _10472.y : _10470.y)) * _5362) <= ((0.100000001490116119384765625f * length(_11163 * _5362)) + 8.0f)))
                {
                    float4 _11256;
                    if (_5058)
                    {
                        float4 _10371 = _11169;
                        _10371.x = 0.0f;
                        _11256 = _10371;
                    }
                    else
                    {
                        float4 _10373 = _11169;
                        _10373.y = 0.0f;
                        _11256 = _10373;
                    }
                    _11255 = _11256;
                }
                else
                {
                    _11255 = _11169;
                }
                _11254 = _11255;
            }
            else
            {
                _11254 = _11169;
            }
            float4 _5387 = _10916 * _11254;
            float _5389 = dot(_5387, 1.0f.xxxx);
            float4 _11496;
            bool _11516;
            if (_5389 > 0.0f)
            {
                _11516 = _10623;
                _11496 = _5387 / _5389.xxxx;
            }
            else
            {
                bool _5400 = any(bool4(_11254.x < 1.0f.xxxx.x, _11254.y < 1.0f.xxxx.y, _11254.z < 1.0f.xxxx.z, _11254.w < 1.0f.xxxx.w));
                if (_5400)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9398;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9398);
                    }
                }
                bool4 _12635 = _5400.xxxx;
                _11516 = _5400 ? true : _10623;
                _11496 = float4(_12635.x ? 0.0f.xxxx.x : _10916.x, _12635.y ? 0.0f.xxxx.y : _10916.y, _12635.z ? 0.0f.xxxx.z : _10916.z, _12635.w ? 0.0f.xxxx.w : _10916.w);
            }
            _11629 = _11730;
            _11515 = _11516;
            _11495 = _11496;
        }
        else
        {
            _11629 = float3(0.0f, 0.0f, 0.5f);
            _11515 = _10623;
            _11495 = _10916;
        }
        uint _5409 = (cbFI_pad0 >> 24u) & 31u;
        uint _5413 = (cbFI_pad0 >> 16u) & 255u;
        bool _5415 = _5409 != 0u;
        bool _5417 = _5413 == 12u;
        bool _5420 = _5413 == 13u;
        float4 _11512;
        if ((_5415 || _5417) || _5420)
        {
            float _11257;
            do
            {
                bool _9482 = all(bool2(_10473.x > 0.0f.xx.x, _10473.y > 0.0f.xx.y));
                bool _9488;
                if (_9482)
                {
                    _9488 = all(bool2(_10473.x < 1.0f.xx.x, _10473.y < 1.0f.xx.y));
                }
                else
                {
                    _9488 = _9482;
                }
                bool _9419 = !_9488;
                bool _9426;
                if (!_9419)
                {
                    bool _9493 = all(bool2(_10474.x > 0.0f.xx.x, _10474.y > 0.0f.xx.y));
                    bool _9499;
                    if (_9493)
                    {
                        _9499 = all(bool2(_10474.x < 1.0f.xx.x, _10474.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9499 = _9493;
                    }
                    _9426 = !_9499;
                }
                else
                {
                    _9426 = _9419;
                }
                if (_9426)
                {
                    _11257 = 0.0f;
                    break;
                }
                uint _9506_dummy_parameter;
                uint _9522_dummy_parameter;
                float4 _9447 = mul(float4((float2(_10473.x, 1.0f - _10473.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10473 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9506_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9449 = _9447.w;
                if (abs(_9449) < 9.9999999747524270787835121154785e-07f)
                {
                    _11257 = 0.0f;
                    break;
                }
                float _9460 = abs(cbFI_DeviceToViewDepth.y / ((_9447.z / _9449) - cbFI_DeviceToViewDepth.x));
                float _9463 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10474 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9522_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _11257 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9460 - _9463) / max(max(_9460, _9463), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9570 = all(bool2(_10474.x > 0.0f.xx.x, _10474.y > 0.0f.xx.y));
            bool _9576;
            if (_9570)
            {
                _9576 = all(bool2(_10474.x < 1.0f.xx.x, _10474.y < 1.0f.xx.y));
            }
            else
            {
                _9576 = _9570;
            }
            float _11258;
            if (_9576)
            {
                uint _9583_dummy_parameter;
                _11258 = length((_6196 + (r_motion_tp1.Load(int3(int2(floor(_10474 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9583_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _11258 = 1000000.0f;
            }
            float _11269;
            if ((_5409 & 1u) != 0u)
            {
                _11269 = _11257;
            }
            else
            {
                _11269 = 1.0f;
            }
            float _11270;
            if ((_5409 & 2u) != 0u)
            {
                _11270 = _11269 * (1.0f - smoothstep(2.0f, 8.0f, _11258));
            }
            else
            {
                _11270 = _11269;
            }
            float _11271;
            if ((_5409 & 4u) != 0u)
            {
                _11271 = _11270 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6917 - _6925) - length(_6901 - _6909))));
            }
            else
            {
                _11271 = _11270;
            }
            float _11506;
            if ((_5409 & 8u) != 0u)
            {
                _11506 = lerp(1.0f, _11271, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6901 - _6909)));
            }
            else
            {
                _11506 = _11271;
            }
            bool _5495 = (_5409 & 16u) != 0u;
            bool _5504;
            if (_5495)
            {
                _5504 = length(_10468 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5504 = _5495;
            }
            float _12637 = _5504 ? 1.0f : _11506;
            bool _5510 = _5415 && _7110;
            bool _5515;
            if (_5510)
            {
                bool _9608 = all(bool2(_10470.x > 0.0f.xx.x, _10470.y > 0.0f.xx.y));
                bool _9614;
                if (_9608)
                {
                    _9614 = all(bool2(_10470.x < 1.0f.xx.x, _10470.y < 1.0f.xx.y));
                }
                else
                {
                    _9614 = _9608;
                }
                _5515 = _9614;
            }
            else
            {
                _5515 = _5510;
            }
            bool _5520;
            if (_5515)
            {
                bool _9619 = all(bool2(_10472.x > 0.0f.xx.x, _10472.y > 0.0f.xx.y));
                bool _9625;
                if (_9619)
                {
                    _9625 = all(bool2(_10472.x < 1.0f.xx.x, _10472.y < 1.0f.xx.y));
                }
                else
                {
                    _9625 = _9619;
                }
                _5520 = _9625;
            }
            else
            {
                _5520 = _5515;
            }
            float4 _11513;
            if (_5520)
            {
                float _5526 = _11495.x + _11495.y;
                float _5535 = (_11495.z + _11495.w) * (1.0f - _12637);
                float _11509;
                if (_5526 > 9.9999997473787516355514526367188e-06f)
                {
                    _11509 = _11495.x / _5526;
                }
                else
                {
                    _11509 = _4366;
                }
                _11513 = float4(_11495.x + (_5535 * _11509), _11495.y + (_5535 * (1.0f - _11509)), _11495.zw * _12637);
            }
            else
            {
                _11513 = _11495;
            }
            _11512 = _11513;
        }
        else
        {
            _11512 = _11495;
        }
        float3 _12402;
        if (_11515)
        {
            float3 _9631 = r_current_interpolation_source.Load(int3(_3735, 0)).xyz;
            float3 _12403;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _7110)
            {
                uint _9638_dummy_parameter;
                float _11620;
                _11620 = r_depth_tm1.Load(int3(int2(floor(_10470 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9638_dummy_parameter))))), 0)).x;
                float _5647;
                for (int _11619 = 0; _11619 < 24; _11620 = _5647, _11619++)
                {
                    float _5619 = float(_11619 & 7) * 0.785398185253143310546875f;
                    int _5621 = _11619 >> 3;
                    int _12453;
                    if (_5621 == 0)
                    {
                        _12453 = 16;
                    }
                    else
                    {
                        _12453 = (_5621 == 1) ? 48 : 96;
                    }
                    uint _9658_dummy_parameter;
                    _5647 = max(_11620, r_depth_tm1.Load(int3(int2(floor(clamp(_10470 + ((cbFI_MvDepthLaneSizeRcp * float(_12453)) * float2(cos(_5619), sin(_5619))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9658_dummy_parameter))))), 0)).x);
                }
                float2 _11621;
                do
                {
                    float _9680 = 1.0f - _10470.y;
                    float4 _9691 = mul(float4((float2(_10470.x, _9680) * 2.0f) - 1.0f.xx, _11620, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9693 = _9691.w;
                    if (!(_9693 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11621 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9706 = ((_9691.xy / _9693.xx) + 1.0f.xx) * 0.5f;
                    _11621 = float2(_9706.x - _10470.x, _9680 - _9706.y);
                    break;
                } while(false);
                float2 _5658 = _10470 + _11621;
                bool _9724 = all(bool2(_5658.x > 0.0f.xx.x, _5658.y > 0.0f.xx.y));
                bool _9730;
                if (_9724)
                {
                    _9730 = all(bool2(_5658.x < 1.0f.xx.x, _5658.y < 1.0f.xx.y));
                }
                else
                {
                    _9730 = _9724;
                }
                float3 _12404;
                if (_9730)
                {
                    float _5664 = abs(cbFI_DeviceToViewDepth.y / (_11620 - cbFI_DeviceToViewDepth.x));
                    uint _9750_dummy_parameter;
                    int2 _9750 = int2(spvTextureSize(r_depth_m2, uint(0), _9750_dummy_parameter));
                    float _5668 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5658 * float2(_9750))), int2(0, 0), _9750 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12409;
                    if (abs(_5668 - _5664) <= (0.20000000298023223876953125f * max(_5668, _5664)))
                    {
                        uint _9784_dummy_parameter;
                        int2 _9784 = int2(spvTextureSize(r_colour_m2, uint(0), _9784_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9807;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9807);
                        }
                        _12409 = r_colour_m2.Load(int3(clamp(int2(floor(_5658 * float2(_9784))), int2(0, 0), _9784 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9817;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9817);
                        }
                        _12409 = _9631;
                    }
                    _12404 = _12409;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9827;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9827);
                    }
                    _12404 = _9631;
                }
                _12403 = _12404;
            }
            else
            {
                _12403 = _9631;
            }
            _12402 = _12403;
        }
        else
        {
            _12402 = (((_6901 * _11512.x) + (_6909 * _11512.y)) + (_6917 * _11512.z)) + (_6925 * _11512.w);
        }
        uint _5696 = cbFI_pad0 & 255u;
        bool _12294;
        float3 _12401;
        if (_5696 != 0u)
        {
            float3 _5701 = r_present_backbuffer.Load(int3(_3735, 0)).xyz;
            float3 _5705 = r_current_interpolation_source.Load(int3(_3735, 0)).xyz;
            float3 _5709 = abs(_5701 - _5705);
            float3 _11624;
            if (_5696 == 2u)
            {
                _11624 = (abs(_5705) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11624 = 0.000244140625f.xxx;
            }
            bool _5725 = any(bool3(_5709.x > _11624.x, _5709.y > _11624.y, _5709.z > _11624.z));
            bool3 _12638 = _5725.xxx;
            _12401 = float3(_12638.x ? _5701.x : _12402.x, _12638.y ? _5701.y : _12402.y, _12638.z ? _5701.z : _12402.z);
            _12294 = _5725;
        }
        else
        {
            _12401 = _12402;
            _12294 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9842;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9842);
        }
        float3 _12384;
        if (_5413 == 1u)
        {
            _12384 = lerp(_6901, _6909, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12385;
            if (_5413 == 2u)
            {
                _12385 = lerp(_6917, _6925, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12386;
                if (_5413 == 3u)
                {
                    _12386 = float(_12294).xxx;
                }
                else
                {
                    float3 _12387;
                    if (_5413 == 4u)
                    {
                        _12387 = float3(((_10468 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12388;
                        if (_5413 == 5u)
                        {
                            _12388 = float3(((_6196 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12389;
                            if (_5413 == 6u)
                            {
                                _12389 = float3(_11512.xy, _11512.z + _11512.w);
                            }
                            else
                            {
                                float3 _12390;
                                if (_5413 == 7u)
                                {
                                    _12390 = r_current_interpolation_source.Load(int3(_3735, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12391;
                                    if (_5413 == 8u)
                                    {
                                        _12391 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4141, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12392;
                                        if (_5417)
                                        {
                                            uint _9864_dummy_parameter;
                                            uint _9896_dummy_parameter;
                                            _12392 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4141 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9864_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4141 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9896_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12393;
                                            if (_5420)
                                            {
                                                _12393 = _6917;
                                            }
                                            else
                                            {
                                                float3 _12394;
                                                if (_5413 == 20u)
                                                {
                                                    _12394 = _6901;
                                                }
                                                else
                                                {
                                                    float3 _12395;
                                                    if (_5413 == 21u)
                                                    {
                                                        _12395 = _6909;
                                                    }
                                                    else
                                                    {
                                                        float3 _12396;
                                                        if (_5413 == 22u)
                                                        {
                                                            _12396 = _6925;
                                                        }
                                                        else
                                                        {
                                                            float3 _12397;
                                                            if (_5413 == 18u)
                                                            {
                                                                _12397 = _12040;
                                                            }
                                                            else
                                                            {
                                                                float3 _12398;
                                                                if (_5413 == 19u)
                                                                {
                                                                    _12398 = _11832;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12640 = (_5413 == 23u).xxx;
                                                                    _12398 = float3(_12640.x ? _11629.x : _12401.x, _12640.y ? _11629.y : _12401.y, _12640.z ? _11629.z : _12401.z);
                                                                }
                                                                _12397 = _12398;
                                                            }
                                                            _12396 = _12397;
                                                        }
                                                        _12395 = _12396;
                                                    }
                                                    _12394 = _12395;
                                                }
                                                _12393 = _12394;
                                            }
                                            _12392 = _12393;
                                        }
                                        _12391 = _12392;
                                    }
                                    _12390 = _12391;
                                }
                                _12389 = _12390;
                            }
                            _12388 = _12389;
                        }
                        _12387 = _12388;
                    }
                    _12386 = _12387;
                }
                _12385 = _12386;
            }
            _12384 = _12385;
        }
        float3 _12383;
        if ((_5413 >= 9u) && (_5413 <= 11u))
        {
            uint _5889 = 64u + uint((_10500.y * cbFI_MvDepthLaneSize.x) + _10500.x);
            uint _5893 = rw_nfru_diagnostics.Load<uint>(_5889 * 4 + 0) & 15u;
            float3 _12414;
            if (_5413 == 10u)
            {
                float3 _12382;
                if ((rw_nfru_diagnostics.Load<uint>(_5889 * 4 + 0) & 32u) != 0u)
                {
                    _12382 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12381;
                    if ((rw_nfru_diagnostics.Load<uint>(_5889 * 4 + 0) & 16u) != 0u)
                    {
                        _12381 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5914 = ((rw_nfru_diagnostics.Load<uint>(_5889 * 4 + 0) & 64u) != 0u).xxx;
                        _12381 = float3(_5914.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5914.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5914.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12382 = _12381;
                }
                _12414 = _12382;
            }
            else
            {
                float3 _12415;
                if (_5413 == 11u)
                {
                    uint _5927 = (rw_nfru_diagnostics.Load<uint>(_5889 * 4 + 0) >> 8u) & 15u;
                    uint _5930 = (rw_nfru_diagnostics.Load<uint>(_5889 * 4 + 0) >> 12u) & 15u;
                    float3 _12374;
                    if ((_5893 == 2u) || (_5893 == 3u))
                    {
                        _12374 = _3448[_5893];
                    }
                    else
                    {
                        bool _5942 = _5927 == 3u;
                        bool _5944 = _5930 == 3u;
                        float3 _12375;
                        if (_5942 && _5944)
                        {
                            _12375 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12376;
                            if (_5942)
                            {
                                _12376 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12377;
                                if (_5944)
                                {
                                    _12377 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12378;
                                    if ((_5927 == 4u) || (_5930 == 4u))
                                    {
                                        _12378 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12379;
                                        if ((_5927 == 1u) || (_5930 == 1u))
                                        {
                                            _12379 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12642 = (_5893 == 1u).xxx;
                                            _12379 = float3(_12642.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12642.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12642.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12378 = _12379;
                                    }
                                    _12377 = _12378;
                                }
                                _12376 = _12377;
                            }
                            _12375 = _12376;
                        }
                        _12374 = _12375;
                    }
                    _12415 = _12374;
                }
                else
                {
                    _12415 = _3448[min(_5893, 7u)];
                }
                _12414 = _12415;
            }
            _12383 = _12414;
        }
        else
        {
            _12383 = _12384;
        }
        float4 _12418;
        if ((_5413 >= 14u) && (_5413 <= 16u))
        {
            float2 _12416;
            if (_5413 == 14u)
            {
                uint _6000_dummy_parameter;
                uint _6006_dummy_parameter;
                _12416 = r_flow_tm1.Load(int3(clamp(int2(floor(_4141 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6000_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6006_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12417;
                if (_5413 == 16u)
                {
                    uint _9947 = r_warped_flow_qdata_tm1.Load(int3(_4157, 0)).x & 2147483647u;
                    uint _9979 = uint(max((int((_9947 >> 16u) & 15u) - 6), 0));
                    _12417 = ((float2(float((1 - (2 * int((_9947 >> 15u) & 1u))) * int(((_9947 >> uint(7)) & 127u) << _9979)), float((1 - (2 * int((_9947 >> 14u) & 1u))) * int((_9947 & 127u) << _9979))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12417 = _6196 * float2(cbFI_DisplaySize);
                }
                _12416 = _12417;
            }
            uint2 _6039 = uint2(clamp(round(_12416 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6041 = _6039.x;
            uint _6048 = _6039.y;
            _12418 = float4(float(_6041 & 255u), float((_6041 >> 8u) | ((_6048 & 15u) << 4u)), float(_6048 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12419;
            if (_5413 == 17u)
            {
                _12419 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4157, 0)).x != 0u), _4500, 0.0f, 1.0f);
            }
            else
            {
                _12419 = float4(_12383, 1.0f);
            }
            _12418 = _12419;
        }
        rw_output[_3735] = _12418.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6092 = ((uint(_3735.y) * uint(cbFI_DisplaySize.x)) + uint(_3735.x)) * 6u;
            uint _10025 = spvPackHalf2x16(clamp(_6900.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6092 * 4 + 0, (((_10025 & 32767u) >> 4u) | ((((_10025 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6900.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10060 = spvPackHalf2x16(clamp(_6908.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6092 + 1u) * 4 + 0, (((_10060 & 32767u) >> 4u) | ((((_10060 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6908.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10095 = spvPackHalf2x16(clamp(_6916.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6092 + 2u) * 4 + 0, (((_10095 & 32767u) >> 4u) | ((((_10095 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6916.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10130 = spvPackHalf2x16(clamp(_6924.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6092 + 3u) * 4 + 0, (((_10130 & 32767u) >> 4u) | ((((_10130 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6924.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _10157 = r_current_interpolation_source.Load(int3(_3735, 0));
            uint _10171 = spvPackHalf2x16(clamp(_10157.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6092 + 4u) * 4 + 0, (((_10171 & 32767u) >> 4u) | ((((_10171 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10157.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12452;
            if (_12294 || (_5413 != 0u))
            {
                _12452 = 4294967295u;
            }
            else
            {
                uint _10206 = spvPackHalf2x16(clamp(_12418.xy, 0.0f.xx, 65000.0f.xx));
                _12452 = (((_10206 & 32767u) >> 4u) | ((((_10206 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12418.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6092 + 5u) * 4 + 0, _12452);
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
