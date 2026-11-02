static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3467[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3771 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3771.x >= cbFI_DisplaySize.x, _3771.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3771] = float4(r_present_backbuffer.Load(int3(_3771, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3771] = float4(r_current_interpolation_source.Load(int3(_3771, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4190 = (float2(_3771) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4201 = int2(floor(_4190 * float2(cbFI_MvDepthLaneSize)));
        int2 _4206 = int2(floor(_4190 * float2(cbFI_FlowLaneSize)));
        float4 _6263 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4190 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6269 = r_warped_filled_flow_tm1.Load(int3(_4206, 0)).xy;
        float2 _6275 = r_warped_filled_motion_tp1.Load(int3(_4201, 0)).xy;
        bool _6297 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10530;
        if (_6297)
        {
            float _6310 = ((2.0f * _4190.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10530 = float2(atan(_6310) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4190.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6310 * _6310))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10530 = _4190;
        }
        bool _4227 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10551;
        bool _10572;
        int2 _10583;
        float3 _12123;
        if (_4227)
        {
            float _10532;
            float _10534;
            _10534 = 2.0f;
            _10532 = -1.0f;
            uint _3835[9];
            float _12577;
            float _12580;
            for (int _10531 = 0; _10531 < 9; _10534 = _12580, _10532 = _12577, _10531++)
            {
                _3835[_10531] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4201 + int2((_10531 % 3) - 1, (_10531 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3835[_10531] != 0u)
                {
                    float _12572;
                    if (_3835[_10531] == 0u)
                    {
                        _12572 = -1.0f;
                    }
                    else
                    {
                        _12572 = float((_3835[_10531] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12580 = min(_10534, _12572);
                    _12577 = max(_10532, _12572);
                }
                else
                {
                    _12580 = _10534;
                    _12577 = _10532;
                }
            }
            float _4273 = float(_10532 >= 0.0f);
            float3 _10321 = 0.0f.xxx;
            _10321.y = _4273;
            float2 _10552;
            bool _10573;
            int2 _10584;
            float3 _12124;
            if ((_10532 - _10534) > 0.0199999995529651641845703125f)
            {
                float _10540;
                int2 _10541;
                float2 _10542;
                int2 _10544;
                float2 _10550;
                _10550 = _6275;
                _10544 = _4201;
                _10542 = _6275;
                _10541 = _4201;
                _10540 = -1.0f;
                float _12585;
                int2 _12589;
                float2 _12600;
                int2 _12611;
                float2 _12644;
                float _12691;
                int _10539 = 0;
                float _12553 = 1000000000.0f;
                for (; _10539 < 9; _12553 = _12691, _10550 = _12644, _10544 = _12611, _10542 = _12600, _10541 = _12589, _10540 = _12585, _10539++)
                {
                    if (_3835[_10539] == 0u)
                    {
                        _12691 = _12553;
                        _12644 = _10550;
                        _12611 = _10544;
                        _12600 = _10542;
                        _12589 = _10541;
                        _12585 = _10540;
                        continue;
                    }
                    int2 _4308 = clamp(_4201 + int2((_10539 % 3) - 1, (_10539 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6385 = _3835[_10539] & 2147483647u;
                    uint _6417 = uint(max((int((_6385 >> 16u) & 15u) - 6), 0));
                    float2 _4314 = (float2(float((1 - (2 * int((_6385 >> 15u) & 1u))) * int(((_6385 >> uint(7)) & 127u) << _6417)), float((1 - (2 * int((_6385 >> 14u) & 1u))) * int((_6385 & 127u) << _6417))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12539;
                    if (_3835[_10539] == 0u)
                    {
                        _12539 = -1.0f;
                    }
                    else
                    {
                        _12539 = float((_3835[_10539] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4319 = _12539 - 0.100000001490116119384765625f;
                    float2 _12540;
                    if (_6297)
                    {
                        float2 _6494 = clamp((((_10530 + (_4314 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6497 = tan(_6494.x);
                        _12540 = (float2(_6497 / cbFI_DeviceToViewDepth.z, (tan(_6494.y) * sqrt(1.0f + (_6497 * _6497))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12540 = _10530 + (_4314 * cbFI_Timestep);
                    }
                    float _4326 = cbFI_Timestep - 1.0f;
                    float2 _12541;
                    if (_6297)
                    {
                        float2 _6565 = clamp((((_10530 + (_4314 * _4326)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6568 = tan(_6565.x);
                        _12541 = (float2(_6568 / cbFI_DeviceToViewDepth.z, (tan(_6565.y) * sqrt(1.0f + (_6568 * _6568))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12541 = _10530 + (_4314 * _4326);
                    }
                    bool _6601 = all(bool2(_12540.x > 0.0f.xx.x, _12540.y > 0.0f.xx.y));
                    bool _6607;
                    if (_6601)
                    {
                        _6607 = all(bool2(_12540.x < 1.0f.xx.x, _12540.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6607 = _6601;
                    }
                    float _12544;
                    if (_6607)
                    {
                        uint _6614_dummy_parameter;
                        _12544 = max((_4319 - (log(((r_depth_tm1.Load(int3(int2(floor(_12540 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6614_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12544 = 0.0f;
                    }
                    bool _6644 = all(bool2(_12541.x > 0.0f.xx.x, _12541.y > 0.0f.xx.y));
                    bool _6650;
                    if (_6644)
                    {
                        _6650 = all(bool2(_12541.x < 1.0f.xx.x, _12541.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6650 = _6644;
                    }
                    float _12545;
                    if (_6650)
                    {
                        uint _6657_dummy_parameter;
                        _12545 = _12544 + max((_4319 - (log(((r_depth_tp1.Load(int3(int2(floor(_12541 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6657_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12545 = _12544;
                    }
                    float _12586;
                    int2 _12590;
                    float2 _12601;
                    int2 _12612;
                    float2 _12645;
                    float _12692;
                    if (_12545 == 0.0f)
                    {
                        bool _4361 = _4319 > _10540;
                        bool2 _12700 = _4361.xx;
                        _12692 = _12553;
                        _12645 = float2(_12700.x ? _4314.x : _10550.x, _12700.y ? _4314.y : _10550.y);
                        _12612 = int2(_12700.x ? _4308.x : _10544.x, _12700.y ? _4308.y : _10544.y);
                        _12601 = _10542;
                        _12590 = _10541;
                        _12586 = _4361 ? _4319 : _10540;
                    }
                    else
                    {
                        bool _4370 = _12545 < _12553;
                        bool2 _12696 = _4370.xx;
                        _12692 = _4370 ? _12545 : _12553;
                        _12645 = _10550;
                        _12612 = _10544;
                        _12601 = float2(_12696.x ? _4314.x : _10542.x, _12696.y ? _4314.y : _10542.y);
                        _12590 = int2(_12696.x ? _4308.x : _10541.x, _12696.y ? _4308.y : _10541.y);
                        _12586 = _10540;
                    }
                    _12691 = _12692;
                    _12644 = _12645;
                    _12611 = _12612;
                    _12600 = _12601;
                    _12589 = _12590;
                    _12585 = _12586;
                }
                bool _4382 = _10540 < 0.0f;
                bool2 _12706 = _4382.xx;
                int2 _12709 = int2(_12706.x ? _10541.x : _10544.x, _12706.y ? _10541.y : _10544.y);
                _12124 = float3(1.0f, _4273, float(any(bool2(_12709.x != _4201.x, _12709.y != _4201.y))));
                _10584 = _12709;
                _10573 = _4382 ? false : true;
                _10552 = float2(_12706.x ? _10542.x : _10550.x, _12706.y ? _10542.y : _10550.y);
            }
            else
            {
                _12124 = _10321;
                _10584 = _4201;
                _10573 = false;
                _10552 = _6275;
            }
            _12123 = _12124;
            _10583 = _10584;
            _10572 = _10573;
            _10551 = _10552;
        }
        else
        {
            _12123 = 0.0f.xxx;
            _10583 = _4201;
            _10572 = false;
            _10551 = _6275;
        }
        float2 _10553;
        if (_6297)
        {
            float2 _6722 = clamp((((_10530 + (_10551 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6725 = tan(_6722.x);
            _10553 = (float2(_6725 / cbFI_DeviceToViewDepth.z, (tan(_6722.y) * sqrt(1.0f + (_6725 * _6725))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10553 = _10530 + (_10551 * cbFI_Timestep);
        }
        float _4405 = cbFI_Timestep - 1.0f;
        float2 _10555;
        if (_6297)
        {
            float2 _6793 = clamp((((_10530 + (_10551 * _4405)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6796 = tan(_6793.x);
            _10555 = (float2(_6796 / cbFI_DeviceToViewDepth.z, (tan(_6793.y) * sqrt(1.0f + (_6796 * _6796))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10555 = _10530 + (_10551 * _4405);
        }
        float _4410 = -cbFI_Timestep;
        float2 _10556;
        if (_6297)
        {
            float2 _6864 = clamp((((_10530 + (_6269 * _4410)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6867 = tan(_6864.x);
            _10556 = (float2(_6867 / cbFI_DeviceToViewDepth.z, (tan(_6864.y) * sqrt(1.0f + (_6867 * _6867))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10556 = _10530 + (_6269 * _4410);
        }
        float _4415 = 1.0f - cbFI_Timestep;
        float2 _10557;
        if (_6297)
        {
            float2 _6935 = clamp((((_10530 + (_6269 * _4415)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6938 = tan(_6935.x);
            _10557 = (float2(_6938 / cbFI_DeviceToViewDepth.z, (tan(_6935.y) * sqrt(1.0f + (_6938 * _6938))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10557 = _10530 + (_6269 * _4415);
        }
        float4 _6973 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10553, 0.0f);
        float3 _6974 = _6973.xyz;
        float4 _6981 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10555, 0.0f);
        float3 _6982 = _6981.xyz;
        float4 _6989 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10556, 0.0f);
        float3 _6990 = _6989.xyz;
        float4 _6997 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10557, 0.0f);
        float3 _6998 = _6997.xyz;
        float4 _7012 = exp(_6263 - max(max(max(_6263.x, _6263.y), _6263.z), _6263.w).xxxx);
        float4 _7019 = _7012 / (dot(_7012, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4434 = _4227 && (!_10572);
        bool _4443;
        if (_4434)
        {
            _4443 = (_7019.z + _7019.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4443 = _4434;
        }
        bool _4454;
        if (_4443)
        {
            _4454 = length((_10556 - _10553) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4454 = _4443;
        }
        bool _10596;
        if (_4454)
        {
            uint4 _7038 = r_warped_motion_qdata_tp1.Load(int3(_10583, 0));
            uint _7039 = _7038.x;
            bool _10599;
            if (_7039 != 0u)
            {
                float _10585;
                if (_7039 == 0u)
                {
                    _10585 = -1.0f;
                }
                else
                {
                    _10585 = float((_7039 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4464 = _10585 - 0.12000000476837158203125f;
                bool _7058 = all(bool2(_10556.x > 0.0f.xx.x, _10556.y > 0.0f.xx.y));
                bool _7064;
                if (_7058)
                {
                    _7064 = all(bool2(_10556.x < 1.0f.xx.x, _10556.y < 1.0f.xx.y));
                }
                else
                {
                    _7064 = _7058;
                }
                bool _4474;
                if (_7064)
                {
                    uint _7071_dummy_parameter;
                    _4474 = (log(((r_depth_tm1.Load(int3(int2(floor(_10556 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7071_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4464;
                }
                else
                {
                    _4474 = _7064;
                }
                bool _4488;
                if (!_4474)
                {
                    bool _7101 = all(bool2(_10557.x > 0.0f.xx.x, _10557.y > 0.0f.xx.y));
                    bool _7107;
                    if (_7101)
                    {
                        _7107 = all(bool2(_10557.x < 1.0f.xx.x, _10557.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7107 = _7101;
                    }
                    bool _4486;
                    if (_7107)
                    {
                        uint _7114_dummy_parameter;
                        _4486 = (log(((r_depth_tp1.Load(int3(int2(floor(_10557 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7114_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4464;
                    }
                    else
                    {
                        _4486 = _7107;
                    }
                    _4488 = _4486;
                }
                else
                {
                    _4488 = _4474;
                }
                _10599 = _4488;
            }
            else
            {
                _10599 = false;
            }
            _10596 = _10599;
        }
        else
        {
            _10596 = false;
        }
        bool _4493 = _10572 || _10596;
        bool _4498;
        if (_4493)
        {
            bool _7144 = all(bool2(_10553.x > 0.0f.xx.x, _10553.y > 0.0f.xx.y));
            bool _7150;
            if (_7144)
            {
                _7150 = all(bool2(_10553.x < 1.0f.xx.x, _10553.y < 1.0f.xx.y));
            }
            else
            {
                _7150 = _7144;
            }
            _4498 = _7150;
        }
        else
        {
            _4498 = _4493;
        }
        bool _4503;
        if (_4498)
        {
            bool _7155 = all(bool2(_10555.x > 0.0f.xx.x, _10555.y > 0.0f.xx.y));
            bool _7161;
            if (_7155)
            {
                _7161 = all(bool2(_10555.x < 1.0f.xx.x, _10555.y < 1.0f.xx.y));
            }
            else
            {
                _7161 = _7155;
            }
            _4503 = _7161;
        }
        else
        {
            _4503 = _4498;
        }
        float4 _10693;
        if (_4503)
        {
            float _4506 = _7019.x;
            float _4508 = _7019.y;
            float _4509 = _4506 + _4508;
            float _4514 = _7019.z + _7019.w;
            float _10614;
            if (_4509 > 0.001000000047497451305389404296875f)
            {
                _10614 = _4506 / _4509;
            }
            else
            {
                _10614 = _4415;
            }
            _10693 = float4(_4506 + (_4514 * _10614), _4508 + (_4514 * (1.0f - _10614)), 0.0f, 0.0f);
        }
        else
        {
            _10693 = _7019;
        }
        bool _7189 = (cbFI_pad0 & 1024u) != 0u;
        bool _7165 = !_7189;
        bool _7166 = !_7165;
        bool _7183;
        if (_7166)
        {
            _7183 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10583.y * cbFI_MvDepthLaneSize.x) + _10583.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _7183 = _7165;
        }
        bool _7215;
        if (_7166)
        {
            _7215 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4206.y * cbFI_FlowLaneSize.x) + _4206.x)) * 4 + 0) != 0u;
        }
        else
        {
            _7215 = _7165;
        }
        float _4549 = float(_7215);
        bool _10706;
        float4 _10737;
        float3 _11915;
        if (_7189)
        {
            bool _4559;
            if (_7183)
            {
                _4559 = all(bool2(_10553.x > 0.0f.xx.x, _10553.y > 0.0f.xx.y));
            }
            else
            {
                _4559 = _7183;
            }
            bool _4565;
            if (_4559)
            {
                _4565 = all(bool2(_10553.x < 1.0f.xx.x, _10553.y < 1.0f.xx.y));
            }
            else
            {
                _4565 = _4559;
            }
            bool _4572;
            if (_7183)
            {
                _4572 = all(bool2(_10555.x > 0.0f.xx.x, _10555.y > 0.0f.xx.y));
            }
            else
            {
                _4572 = _7183;
            }
            bool _4578;
            if (_4572)
            {
                _4578 = all(bool2(_10555.x < 1.0f.xx.x, _10555.y < 1.0f.xx.y));
            }
            else
            {
                _4578 = _4572;
            }
            bool _4585;
            if (_7215)
            {
                _4585 = all(bool2(_10556.x > 0.0f.xx.x, _10556.y > 0.0f.xx.y));
            }
            else
            {
                _4585 = _7215;
            }
            bool _4591;
            if (_4585)
            {
                _4591 = all(bool2(_10556.x < 1.0f.xx.x, _10556.y < 1.0f.xx.y));
            }
            else
            {
                _4591 = _4585;
            }
            bool _4598;
            if (_7215)
            {
                _4598 = all(bool2(_10557.x > 0.0f.xx.x, _10557.y > 0.0f.xx.y));
            }
            else
            {
                _4598 = _7215;
            }
            bool _4604;
            if (_4598)
            {
                _4604 = all(bool2(_10557.x < 1.0f.xx.x, _10557.y < 1.0f.xx.y));
            }
            else
            {
                _4604 = _4598;
            }
            bool _4606 = !_7183;
            if (_4606)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7257;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7257);
                }
            }
            bool _4611 = !_7215;
            if (_4611)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7267;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7267);
                }
            }
            if (_7183 && _4611)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7277;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7277);
                }
            }
            if (_4606 && _7215)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7287;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7287);
                }
            }
            float _4630 = float(_4565);
            float _4632 = float(_4578);
            bool _4635 = _4591 && _4604;
            float _10648;
            if (_4635)
            {
                _10648 = 1.0f;
            }
            else
            {
                _10648 = (_4591 || _4604) ? 0.5f : 0.0f;
            }
            bool _10653;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4565)) && (!_4578))
            {
                bool _4665;
                if (_4635)
                {
                    float _10651;
                    do
                    {
                        bool _7371 = all(bool2(_10556.x > 0.0f.xx.x, _10556.y > 0.0f.xx.y));
                        bool _7377;
                        if (_7371)
                        {
                            _7377 = all(bool2(_10556.x < 1.0f.xx.x, _10556.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7377 = _7371;
                        }
                        bool _7308 = !_7377;
                        bool _7315;
                        if (!_7308)
                        {
                            bool _7382 = all(bool2(_10557.x > 0.0f.xx.x, _10557.y > 0.0f.xx.y));
                            bool _7388;
                            if (_7382)
                            {
                                _7388 = all(bool2(_10557.x < 1.0f.xx.x, _10557.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7388 = _7382;
                            }
                            _7315 = !_7388;
                        }
                        else
                        {
                            _7315 = _7308;
                        }
                        if (_7315)
                        {
                            _10651 = 0.0f;
                            break;
                        }
                        uint _7395_dummy_parameter;
                        uint _7411_dummy_parameter;
                        float4 _7336 = mul(float4((float2(_10556.x, 1.0f - _10556.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10556 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7395_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7338 = _7336.w;
                        if (abs(_7338) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10651 = 0.0f;
                            break;
                        }
                        float _7349 = abs(cbFI_DeviceToViewDepth.y / ((_7336.z / _7338) - cbFI_DeviceToViewDepth.x));
                        float _7352 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10557 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7411_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10651 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7349 - _7352) / max(max(_7349, _7352), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4665 = _10651 >= 0.5f;
                }
                else
                {
                    _4665 = _4635;
                }
                bool _4673;
                if (_4665)
                {
                    _4673 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4673 = _4665;
                }
                bool _10654;
                if (_4673)
                {
                    uint _7461_dummy_parameter;
                    float2 _10652;
                    do
                    {
                        float _7487 = 1.0f - _10556.y;
                        float4 _7498 = mul(float4((float2(_10556.x, _7487) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10556 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7461_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7500 = _7498.w;
                        if (!(_7500 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10652 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7513 = ((_7498.xy / _7500.xx) + 1.0f.xx) * 0.5f;
                        _10652 = float2(_7513.x - _10556.x, _7487 - _7513.y);
                        break;
                    } while(false);
                    float2 _4686 = float2(cbFI_DisplaySize);
                    _10654 = length(((_10556 + _10652) - _10557) * _4686) <= ((0.100000001490116119384765625f * length(_10652 * _4686)) + 8.0f);
                }
                else
                {
                    _10654 = _4665;
                }
                _10653 = _10654;
            }
            else
            {
                _10653 = true;
            }
            bool _4700 = !_10653;
            bool _12710 = _4700 ? false : _4604;
            bool _12711 = _4700 ? false : _4591;
            bool _10707;
            float4 _10738;
            if (!(((_4565 && _4578) && _12711) && _12710))
            {
                float4 _4722 = _10693 * float4(_4630, _4632, float(_12711), float(_12710));
                float _4724 = dot(_4722, 1.0f.xxxx);
                bool _4727 = !(_4724 > 0.0f);
                float4 _10739;
                if (!_4727)
                {
                    _10739 = _4722 / _4724.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7535;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7535);
                    }
                    _10739 = 0.0f.xxxx;
                }
                _10738 = _10739;
                _10707 = _4727;
            }
            else
            {
                _10738 = _10693;
                _10707 = false;
            }
            _11915 = float3(_4630, _4632, _10648);
            _10737 = _10738;
            _10706 = _10707;
        }
        else
        {
            _11915 = float3(float(_7183), _4549, 0.0f);
            _10737 = _10693;
            _10706 = false;
        }
        bool _4745 = !_10706;
        float4 _10822;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4745)
        {
            float _4752 = _10737.x + _10737.y;
            float4 _10823;
            if (_4752 > 0.001000000047497451305389404296875f)
            {
                _10823 = float4(_10737.x / _4752, _10737.y / _4752, 0.0f, 0.0f);
            }
            else
            {
                _10823 = float4(_4415, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10822 = _10823;
        }
        else
        {
            _10822 = _10737;
        }
        float4 _10999;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4745) && _7183)
        {
            float _10796;
            do
            {
                uint4 _7675 = r_warped_motion_qdata_tp1.Load(int3(_10583, 0));
                uint _7676 = _7675.x;
                if (_7676 != 0u)
                {
                    float _10795;
                    if (_7676 == 0u)
                    {
                        _10795 = -1.0f;
                    }
                    else
                    {
                        _10795 = float((_7676 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10796 = _10795;
                    break;
                }
                int _10778;
                uint _10779;
                _10779 = _7676;
                _10778 = -1;
                uint _10794;
                for (; _10778 <= 1; _10779 = _10794, _10778++)
                {
                    _10794 = _10779;
                    for (int _10792 = -1; _10792 <= 1; )
                    {
                        _10794 = max(_10794, r_warped_motion_qdata_tp1.Load(int3(clamp(_10583 + int2(_10792, _10778), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10792++;
                        continue;
                    }
                }
                if (_10779 != 0u)
                {
                    float _10791;
                    if (_10779 == 0u)
                    {
                        _10791 = -1.0f;
                    }
                    else
                    {
                        _10791 = float((_10779 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10796 = _10791;
                    break;
                }
                uint _10781;
                _10781 = 4294967295u;
                uint _12681;
                for (int _10780 = 0; _10780 < 8; _10781 = _12681, _10780++)
                {
                    int _10784 = 0;
                    for (;;)
                    {
                        if (_10784 < 5)
                        {
                            int2 _7626 = _10583 + (_1093[_10780] * _1102[_10784].xx);
                            bool _7629 = any(bool2(_7626.x < int2(0, 0).x, _7626.y < int2(0, 0).y));
                            bool _7637;
                            if (!_7629)
                            {
                                _7637 = any(bool2(_7626.x >= cbFI_MvDepthLaneSize.x, _7626.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7637 = _7629;
                            }
                            if (_7637)
                            {
                                _12681 = _10781;
                                break;
                            }
                            uint4 _7715 = r_warped_motion_qdata_tp1.Load(int3(_7626, 0));
                            uint _7716 = _7715.x;
                            if (_7716 != 0u)
                            {
                                _12681 = min(_10781, _7716);
                                break;
                            }
                            _10784++;
                            continue;
                        }
                        else
                        {
                            _12681 = _10781;
                            break;
                        }
                    }
                }
                float _10783;
                if (_10781 == 4294967295u)
                {
                    _10783 = -1.0f;
                }
                else
                {
                    float _10782;
                    if (_10781 == 0u)
                    {
                        _10782 = -1.0f;
                    }
                    else
                    {
                        _10782 = float((_10781 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10783 = _10782;
                }
                _10796 = _10783;
                break;
            } while(false);
            float _4788 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4791 = r_warped_motion_qdata_tp1.Load(int3(_10583, 0)).x == 0u;
            bool _4797;
            if (_4791)
            {
                bool _7741 = all(bool2(_10553.x > 0.0f.xx.x, _10553.y > 0.0f.xx.y));
                bool _7747;
                if (_7741)
                {
                    _7747 = all(bool2(_10553.x < 1.0f.xx.x, _10553.y < 1.0f.xx.y));
                }
                else
                {
                    _7747 = _7741;
                }
                _4797 = _7747;
            }
            else
            {
                _4797 = _4791;
            }
            bool _4802;
            if (_4797)
            {
                bool _7752 = all(bool2(_10555.x > 0.0f.xx.x, _10555.y > 0.0f.xx.y));
                bool _7758;
                if (_7752)
                {
                    _7758 = all(bool2(_10555.x < 1.0f.xx.x, _10555.y < 1.0f.xx.y));
                }
                else
                {
                    _7758 = _7752;
                }
                _4802 = _7758;
            }
            else
            {
                _4802 = _4797;
            }
            bool _10808;
            float4 _10817;
            if (_4802)
            {
                uint _7765_dummy_parameter;
                float _7789 = log(((r_depth_tm1.Load(int3(int2(floor(_10553 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7765_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _7797_dummy_parameter;
                float _7821 = log(((r_depth_tp1.Load(int3(int2(floor(_10555 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7797_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _4813 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4820;
                if (_4813)
                {
                    _4820 = _7821 > (_7789 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4820 = _4813;
                }
                bool _10813;
                float4 _10835;
                if (_4820)
                {
                    _10835 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _10813 = true;
                }
                else
                {
                    bool _4826 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _4833;
                    if (_4826)
                    {
                        _4833 = _7789 > (_7821 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _4833 = _4826;
                    }
                    bool4 _12712 = _4833.xxxx;
                    _10835 = float4(_12712.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10822.x, _12712.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10822.y, _12712.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10822.z, _12712.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10822.w);
                    _10813 = _4833 ? true : false;
                }
                _10817 = _10835;
                _10808 = _10813;
            }
            else
            {
                _10817 = _10822;
                _10808 = false;
            }
            float4 _10890;
            if (_10808)
            {
                _10890 = 1.0f.xxxx;
            }
            else
            {
                bool _4844 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4850;
                if (_4844)
                {
                    _4850 = _10817.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4850 = _4844;
                }
                bool _4855;
                if (_4850)
                {
                    bool _7827 = all(bool2(_10555.x > 0.0f.xx.x, _10555.y > 0.0f.xx.y));
                    bool _7833;
                    if (_7827)
                    {
                        _7833 = all(bool2(_10555.x < 1.0f.xx.x, _10555.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7833 = _7827;
                    }
                    _4855 = _7833;
                }
                else
                {
                    _4855 = _4850;
                }
                float4 _10891;
                if (_4855)
                {
                    float _10844;
                    if (_10796 >= 0.0f)
                    {
                        _10844 = _10796 - _4788;
                    }
                    else
                    {
                        float _10840;
                        _10840 = 2.0f;
                        float _7890;
                        for (int _10839 = 0; _10839 < 24; _10840 = _7890, _10839++)
                        {
                            float _7854 = float(_10839 & 7) * 0.785398185253143310546875f;
                            int _7856 = _10839 >> 3;
                            int _10841;
                            if (_7856 == 0)
                            {
                                _10841 = 16;
                            }
                            else
                            {
                                _10841 = (_7856 == 1) ? 48 : 96;
                            }
                            uint _7922_dummy_parameter;
                            _7890 = min(_10840, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10555 + ((cbFI_MvDepthLaneSizeRcp * float(_10841)) * float2(cos(_7854), sin(_7854))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7922_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10844 = _10840;
                    }
                    uint _7954_dummy_parameter;
                    float4 _10892;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_10555 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7954_dummy_parameter))))), 0)).x) > ((exp((_10844 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10892 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10892 = 1.0f.xxxx;
                    }
                    _10891 = _10892;
                }
                else
                {
                    _10891 = 1.0f.xxxx;
                }
                _10890 = _10891;
            }
            bool _4883 = _10796 >= 0.0f;
            bool _4884 = (!_10808) && _4883;
            bool _4891;
            if (_4884)
            {
                _4891 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4891 = _4884;
            }
            bool _4897;
            if (_4891)
            {
                _4897 = _10817.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4897 = _4891;
            }
            bool _4902;
            if (_4897)
            {
                bool _7979 = all(bool2(_10553.x > 0.0f.xx.x, _10553.y > 0.0f.xx.y));
                bool _7985;
                if (_7979)
                {
                    _7985 = all(bool2(_10553.x < 1.0f.xx.x, _10553.y < 1.0f.xx.y));
                }
                else
                {
                    _7985 = _7979;
                }
                _4902 = _7985;
            }
            else
            {
                _4902 = _4897;
            }
            float4 _10915;
            if (_4902)
            {
                float _10884;
                if (_4883)
                {
                    _10884 = _10796 - _4788;
                }
                else
                {
                    float _10880;
                    _10880 = 2.0f;
                    float _8042;
                    for (int _10879 = 0; _10879 < 24; _10880 = _8042, _10879++)
                    {
                        float _8006 = float(_10879 & 7) * 0.785398185253143310546875f;
                        int _8008 = _10879 >> 3;
                        int _10881;
                        if (_8008 == 0)
                        {
                            _10881 = 16;
                        }
                        else
                        {
                            _10881 = (_8008 == 1) ? 48 : 96;
                        }
                        uint _8058_dummy_parameter;
                        _8042 = min(_10880, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10553 + ((cbFI_MvDepthLaneSizeRcp * float(_10881)) * float2(cos(_8006), sin(_8006))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8058_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10884 = _10880;
                }
                uint _8106_dummy_parameter;
                float4 _10916;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_10553 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8106_dummy_parameter))))), 0)).x) > ((exp((_10884 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10393 = _10890;
                    _10393.x = 0.0f;
                    _10916 = _10393;
                }
                else
                {
                    _10916 = _10890;
                }
                _10915 = _10916;
            }
            else
            {
                _10915 = _10890;
            }
            float4 _10928;
            if (_4884)
            {
                float _8133 = (exp(((_10796 - _4788) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _4940 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4946;
                if (_4940)
                {
                    _4946 = _10817.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4946 = _4940;
                }
                bool _4951;
                if (_4946)
                {
                    bool _8138 = all(bool2(_10557.x > 0.0f.xx.x, _10557.y > 0.0f.xx.y));
                    bool _8144;
                    if (_8138)
                    {
                        _8144 = all(bool2(_10557.x < 1.0f.xx.x, _10557.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8144 = _8138;
                    }
                    _4951 = _8144;
                }
                else
                {
                    _4951 = _4946;
                }
                bool _4959;
                if (_4951)
                {
                    uint _8151_dummy_parameter;
                    _4959 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10557 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8151_dummy_parameter))))), 0)).x) > _8133;
                }
                else
                {
                    _4959 = _4951;
                }
                float4 _10926;
                if (_4959)
                {
                    float4 _10396 = _10915;
                    _10396.w = 0.0f;
                    _10926 = _10396;
                }
                else
                {
                    _10926 = _10915;
                }
                bool _4966 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4972;
                if (_4966)
                {
                    _4972 = _10817.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4972 = _4966;
                }
                bool _4977;
                if (_4972)
                {
                    bool _8169 = all(bool2(_10556.x > 0.0f.xx.x, _10556.y > 0.0f.xx.y));
                    bool _8175;
                    if (_8169)
                    {
                        _8175 = all(bool2(_10556.x < 1.0f.xx.x, _10556.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8175 = _8169;
                    }
                    _4977 = _8175;
                }
                else
                {
                    _4977 = _4972;
                }
                bool _4985;
                if (_4977)
                {
                    uint _8182_dummy_parameter;
                    _4985 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10556 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8182_dummy_parameter))))), 0)).x) > _8133;
                }
                else
                {
                    _4985 = _4977;
                }
                float4 _10929;
                if (_4985)
                {
                    float4 _10399 = _10926;
                    _10399.z = 0.0f;
                    _10929 = _10399;
                }
                else
                {
                    _10929 = _10926;
                }
                _10928 = _10929;
            }
            else
            {
                _10928 = _10915;
            }
            float4 _11000;
            if (any(bool4(_10928.x < 1.0f.xxxx.x, _10928.y < 1.0f.xxxx.y, _10928.z < 1.0f.xxxx.z, _10928.w < 1.0f.xxxx.w)))
            {
                float4 _4996 = _10817 * _10928;
                float _4998 = dot(_4996, 1.0f.xxxx);
                float4 _11001;
                if (_4998 > 0.0f)
                {
                    _11001 = _4996 / _4998.xxxx;
                }
                else
                {
                    bool _5009 = _10928.y == 0.0f;
                    bool _5015;
                    if (_5009)
                    {
                        _5015 = _10928.x > 0.0f;
                    }
                    else
                    {
                        _5015 = _5009;
                    }
                    bool _5020;
                    if (_5015)
                    {
                        bool _8200 = all(bool2(_10553.x > 0.0f.xx.x, _10553.y > 0.0f.xx.y));
                        bool _8206;
                        if (_8200)
                        {
                            _8206 = all(bool2(_10553.x < 1.0f.xx.x, _10553.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8206 = _8200;
                        }
                        _5020 = _8206;
                    }
                    else
                    {
                        _5020 = _5015;
                    }
                    float4 _11002;
                    if (_5020)
                    {
                        _11002 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5025 = _10928.x == 0.0f;
                        bool _5031;
                        if (_5025)
                        {
                            _5031 = _10928.y > 0.0f;
                        }
                        else
                        {
                            _5031 = _5025;
                        }
                        bool _5036;
                        if (_5031)
                        {
                            bool _8211 = all(bool2(_10555.x > 0.0f.xx.x, _10555.y > 0.0f.xx.y));
                            bool _8217;
                            if (_8211)
                            {
                                _8217 = all(bool2(_10555.x < 1.0f.xx.x, _10555.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _8217 = _8211;
                            }
                            _5036 = _8217;
                        }
                        else
                        {
                            _5036 = _5031;
                        }
                        bool4 _12715 = _5036.xxxx;
                        _11002 = float4(_12715.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10817.x, _12715.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10817.y, _12715.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10817.z, _12715.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10817.w);
                    }
                    _11001 = _11002;
                }
                _11000 = _11001;
            }
            else
            {
                _11000 = _10817;
            }
            _10999 = _11000;
        }
        else
        {
            _10999 = _10822;
        }
        float4 _11578;
        bool _11598;
        float3 _11712;
        if (((cbFI_pad0 & 32768u) != 0u) && _4745)
        {
            bool _5053 = _10999.x > 0.00999999977648258209228515625f;
            bool _5056 = _10999.y > 0.00999999977648258209228515625f;
            bool _5065 = (_10999.z + _10999.w) > 0.0199999995529651641845703125f;
            bool _5071;
            if (_5065)
            {
                bool _8222 = all(bool2(_10556.x > 0.0f.xx.x, _10556.y > 0.0f.xx.y));
                bool _8228;
                if (_8222)
                {
                    _8228 = all(bool2(_10556.x < 1.0f.xx.x, _10556.y < 1.0f.xx.y));
                }
                else
                {
                    _8228 = _8222;
                }
                _5071 = _8228;
            }
            else
            {
                _5071 = _5065;
            }
            bool _5076;
            if (_5071)
            {
                bool _8233 = all(bool2(_10557.x > 0.0f.xx.x, _10557.y > 0.0f.xx.y));
                bool _8239;
                if (_8233)
                {
                    _8239 = all(bool2(_10557.x < 1.0f.xx.x, _10557.y < 1.0f.xx.y));
                }
                else
                {
                    _8239 = _8233;
                }
                _5076 = _8239;
            }
            else
            {
                _5076 = _5071;
            }
            bool _5083;
            if (_5076)
            {
                float _11010;
                do
                {
                    bool _8322 = all(bool2(_10556.x > 0.0f.xx.x, _10556.y > 0.0f.xx.y));
                    bool _8328;
                    if (_8322)
                    {
                        _8328 = all(bool2(_10556.x < 1.0f.xx.x, _10556.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8328 = _8322;
                    }
                    bool _8259 = !_8328;
                    bool _8266;
                    if (!_8259)
                    {
                        bool _8333 = all(bool2(_10557.x > 0.0f.xx.x, _10557.y > 0.0f.xx.y));
                        bool _8339;
                        if (_8333)
                        {
                            _8339 = all(bool2(_10557.x < 1.0f.xx.x, _10557.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8339 = _8333;
                        }
                        _8266 = !_8339;
                    }
                    else
                    {
                        _8266 = _8259;
                    }
                    if (_8266)
                    {
                        _11010 = 0.0f;
                        break;
                    }
                    uint _8346_dummy_parameter;
                    uint _8362_dummy_parameter;
                    float4 _8287 = mul(float4((float2(_10556.x, 1.0f - _10556.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10556 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8346_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _8289 = _8287.w;
                    if (abs(_8289) < 9.9999999747524270787835121154785e-07f)
                    {
                        _11010 = 0.0f;
                        break;
                    }
                    float _8300 = abs(cbFI_DeviceToViewDepth.y / ((_8287.z / _8289) - cbFI_DeviceToViewDepth.x));
                    float _8303 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10557 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8362_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _11010 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8300 - _8303) / max(max(_8300, _8303), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5083 = _11010 < 0.5f;
            }
            else
            {
                _5083 = _5076;
            }
            float4 _11025;
            if (_5083)
            {
                uint _8412_dummy_parameter;
                uint _8443_dummy_parameter;
                float4 _11026;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10556 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8412_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10557 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8443_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _11026 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _11026 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _11025 = _11026;
            }
            else
            {
                _11025 = 1.0f.xxxx;
            }
            bool _5107;
            if (_7183)
            {
                bool _8472 = all(bool2(_10553.x > 0.0f.xx.x, _10553.y > 0.0f.xx.y));
                bool _8478;
                if (_8472)
                {
                    _8478 = all(bool2(_10553.x < 1.0f.xx.x, _10553.y < 1.0f.xx.y));
                }
                else
                {
                    _8478 = _8472;
                }
                _5107 = _8478;
            }
            else
            {
                _5107 = _7183;
            }
            bool _5113;
            if (_7183)
            {
                bool _8483 = all(bool2(_10555.x > 0.0f.xx.x, _10555.y > 0.0f.xx.y));
                bool _8489;
                if (_8483)
                {
                    _8489 = all(bool2(_10555.x < 1.0f.xx.x, _10555.y < 1.0f.xx.y));
                }
                else
                {
                    _8489 = _8483;
                }
                _5113 = _8489;
            }
            else
            {
                _5113 = _7183;
            }
            bool _5119;
            if (_7215)
            {
                bool _8494 = all(bool2(_10556.x > 0.0f.xx.x, _10556.y > 0.0f.xx.y));
                bool _8500;
                if (_8494)
                {
                    _8500 = all(bool2(_10556.x < 1.0f.xx.x, _10556.y < 1.0f.xx.y));
                }
                else
                {
                    _8500 = _8494;
                }
                _5119 = _8500;
            }
            else
            {
                _5119 = _7215;
            }
            bool _5125;
            if (_7215)
            {
                bool _8505 = all(bool2(_10557.x > 0.0f.xx.x, _10557.y > 0.0f.xx.y));
                bool _8511;
                if (_8505)
                {
                    _8511 = all(bool2(_10557.x < 1.0f.xx.x, _10557.y < 1.0f.xx.y));
                }
                else
                {
                    _8511 = _8505;
                }
                _5125 = _8511;
            }
            else
            {
                _5125 = _7215;
            }
            bool _5128 = _5119 != _5125;
            bool _5134;
            if (_5128)
            {
                _5134 = _5107 || _5113;
            }
            else
            {
                _5134 = _5128;
            }
            float4 _11124;
            if (_5134)
            {
                float4 _10426 = _11025;
                _10426.z = 0.0f;
                _10426.w = 0.0f;
                _11124 = _10426;
            }
            else
            {
                _11124 = _11025;
            }
            bool _5141 = _5107 && _5053;
            bool _5144 = _5113 && _5056;
            float4 _11229;
            float3 _11813;
            if (_5141 || _5144)
            {
                float _11119;
                do
                {
                    uint4 _8650 = r_warped_motion_qdata_tp1.Load(int3(_10583, 0));
                    uint _8651 = _8650.x;
                    if (_8651 != 0u)
                    {
                        float _11118;
                        if (_8651 == 0u)
                        {
                            _11118 = -1.0f;
                        }
                        else
                        {
                            _11118 = float((_8651 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11119 = _11118;
                        break;
                    }
                    int _11101;
                    uint _11102;
                    _11102 = _8651;
                    _11101 = -1;
                    uint _11117;
                    for (; _11101 <= 1; _11102 = _11117, _11101++)
                    {
                        _11117 = _11102;
                        for (int _11115 = -1; _11115 <= 1; )
                        {
                            _11117 = max(_11117, r_warped_motion_qdata_tp1.Load(int3(clamp(_10583 + int2(_11115, _11101), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11115++;
                            continue;
                        }
                    }
                    if (_11102 != 0u)
                    {
                        float _11114;
                        if (_11102 == 0u)
                        {
                            _11114 = -1.0f;
                        }
                        else
                        {
                            _11114 = float((_11102 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11119 = _11114;
                        break;
                    }
                    uint _11104;
                    _11104 = 4294967295u;
                    uint _12682;
                    for (int _11103 = 0; _11103 < 8; _11104 = _12682, _11103++)
                    {
                        int _11107 = 0;
                        for (;;)
                        {
                            if (_11107 < 5)
                            {
                                int2 _8601 = _10583 + (_1093[_11103] * _1102[_11107].xx);
                                bool _8604 = any(bool2(_8601.x < int2(0, 0).x, _8601.y < int2(0, 0).y));
                                bool _8612;
                                if (!_8604)
                                {
                                    _8612 = any(bool2(_8601.x >= cbFI_MvDepthLaneSize.x, _8601.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8612 = _8604;
                                }
                                if (_8612)
                                {
                                    _12682 = _11104;
                                    break;
                                }
                                uint4 _8690 = r_warped_motion_qdata_tp1.Load(int3(_8601, 0));
                                uint _8691 = _8690.x;
                                if (_8691 != 0u)
                                {
                                    _12682 = min(_11104, _8691);
                                    break;
                                }
                                _11107++;
                                continue;
                            }
                            else
                            {
                                _12682 = _11104;
                                break;
                            }
                        }
                    }
                    float _11106;
                    if (_11104 == 4294967295u)
                    {
                        _11106 = -1.0f;
                    }
                    else
                    {
                        float _11105;
                        if (_11104 == 0u)
                        {
                            _11105 = -1.0f;
                        }
                        else
                        {
                            _11105 = float((_11104 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11106 = _11105;
                    }
                    _11119 = _11106;
                    break;
                } while(false);
                bool _5152 = _11119 < 0.0f;
                float _11120;
                if (_5152)
                {
                    _11120 = 0.0f;
                }
                else
                {
                    _11120 = _11119 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8712_dummy_parameter;
                uint _8744_dummy_parameter;
                float4 _11157;
                if ((_5152 && _5141) && _5144)
                {
                    uint _8776_dummy_parameter;
                    float _8800 = log(((r_depth_tm1.Load(int3(int2(floor(_10553 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8776_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8808_dummy_parameter;
                    float _8832 = log(((r_depth_tp1.Load(int3(int2(floor(_10555 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8808_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _11158;
                    if (_8800 > (_8832 + 0.07999999821186065673828125f))
                    {
                        float4 _10430 = _11124;
                        _10430.x = 0.0f;
                        _11158 = _10430;
                    }
                    else
                    {
                        float4 _11159;
                        if (_8832 > (_8800 + 0.07999999821186065673828125f))
                        {
                            float4 _10432 = _11124;
                            _10432.y = 0.0f;
                            _11159 = _10432;
                        }
                        else
                        {
                            _11159 = _11124;
                        }
                        _11158 = _11159;
                    }
                    _11157 = _11158;
                }
                else
                {
                    _11157 = _11124;
                }
                float _5204 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5206 = _11119 >= 0.0f;
                float _11140;
                if (_5206)
                {
                    _11140 = _11119 - _5204;
                }
                else
                {
                    float _11136;
                    if (_5141)
                    {
                        float _11135;
                        _11135 = 2.0f;
                        float _8890;
                        for (int _11134 = 0; _11134 < 24; _11135 = _8890, _11134++)
                        {
                            float _8854 = float(_11134 & 7) * 0.785398185253143310546875f;
                            int _8856 = _11134 >> 3;
                            int _11137;
                            if (_8856 == 0)
                            {
                                _11137 = 16;
                            }
                            else
                            {
                                _11137 = (_8856 == 1) ? 48 : 96;
                            }
                            uint _8906_dummy_parameter;
                            _8890 = min(_11135, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_10553 + ((cbFI_MvDepthLaneSizeRcp * float(_11137)) * float2(cos(_8854), sin(_8854))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8906_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11136 = _11135;
                    }
                    else
                    {
                        _11136 = 0.0f;
                    }
                    _11140 = _11136;
                }
                float _11147;
                if (_5206)
                {
                    _11147 = _11119 - _5204;
                }
                else
                {
                    float _11143;
                    if (_5144)
                    {
                        float _11142;
                        _11142 = 2.0f;
                        float _9004;
                        for (int _11141 = 0; _11141 < 24; _11142 = _9004, _11141++)
                        {
                            float _8968 = float(_11141 & 7) * 0.785398185253143310546875f;
                            int _8970 = _11141 >> 3;
                            int _11144;
                            if (_8970 == 0)
                            {
                                _11144 = 16;
                            }
                            else
                            {
                                _11144 = (_8970 == 1) ? 48 : 96;
                            }
                            uint _9036_dummy_parameter;
                            _9004 = min(_11142, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_10555 + ((cbFI_MvDepthLaneSizeRcp * float(_11144)) * float2(cos(_8968), sin(_8968))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9036_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11143 = _11142;
                    }
                    else
                    {
                        _11143 = 0.0f;
                    }
                    _11147 = _11143;
                }
                float _11148;
                if (_5141)
                {
                    uint _9068_dummy_parameter;
                    _11148 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_10553 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9068_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11148 = 0.0f;
                }
                float _11149;
                if (_5144)
                {
                    uint _9088_dummy_parameter;
                    _11149 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_10555 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9088_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11149 = 0.0f;
                }
                bool _5261;
                if (_5141)
                {
                    _5261 = _11148 > ((exp((_11140 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5261 = _5141;
                }
                float4 _11165;
                if (_5261)
                {
                    float4 _10434 = _11157;
                    _10434.x = 0.0f;
                    _11165 = _10434;
                }
                else
                {
                    _11165 = _11157;
                }
                bool _5273;
                if (_5144)
                {
                    _5273 = _11149 > ((exp((_11147 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5273 = _5144;
                }
                float4 _11167;
                if (_5273)
                {
                    float4 _10436 = _11165;
                    _10436.y = 0.0f;
                    _11167 = _10436;
                }
                else
                {
                    _11167 = _11165;
                }
                float4 _11230;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5206)
                {
                    bool _5293;
                    if (_5141)
                    {
                        _5293 = _11148 < ((exp((_11140 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5293 = _5141;
                    }
                    float4 _11169;
                    if (_5293)
                    {
                        float4 _10438 = _11167;
                        _10438.x = 0.0f;
                        _11169 = _10438;
                    }
                    else
                    {
                        _11169 = _11167;
                    }
                    bool _5305;
                    if (_5144)
                    {
                        _5305 = _11149 < ((exp((_11147 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5305 = _5144;
                    }
                    float4 _11231;
                    if (_5305)
                    {
                        float4 _10440 = _11169;
                        _10440.y = 0.0f;
                        _11231 = _10440;
                    }
                    else
                    {
                        _11231 = _11169;
                    }
                    _11230 = _11231;
                }
                else
                {
                    _11230 = _11167;
                }
                _11813 = float3(_11120, log(((r_depth_tm1.Load(int3(int2(floor(_10553 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8712_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_10555 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8744_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _11229 = _11230;
            }
            else
            {
                _11813 = float3(0.0f, 0.0f, 0.5f);
                _11229 = _11124;
            }
            bool _5316 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5065;
            bool _5322;
            if (_5316)
            {
                _5322 = _5119 || _5125;
            }
            else
            {
                _5322 = _5316;
            }
            float4 _11252;
            if (_5322)
            {
                float _11224;
                do
                {
                    uint4 _9268 = r_warped_motion_qdata_tp1.Load(int3(_10583, 0));
                    uint _9269 = _9268.x;
                    if (_9269 != 0u)
                    {
                        float _11223;
                        if (_9269 == 0u)
                        {
                            _11223 = -1.0f;
                        }
                        else
                        {
                            _11223 = float((_9269 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11224 = _11223;
                        break;
                    }
                    int _11206;
                    uint _11207;
                    _11207 = _9269;
                    _11206 = -1;
                    uint _11222;
                    for (; _11206 <= 1; _11207 = _11222, _11206++)
                    {
                        _11222 = _11207;
                        for (int _11220 = -1; _11220 <= 1; )
                        {
                            _11222 = max(_11222, r_warped_motion_qdata_tp1.Load(int3(clamp(_10583 + int2(_11220, _11206), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11220++;
                            continue;
                        }
                    }
                    if (_11207 != 0u)
                    {
                        float _11219;
                        if (_11207 == 0u)
                        {
                            _11219 = -1.0f;
                        }
                        else
                        {
                            _11219 = float((_11207 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11224 = _11219;
                        break;
                    }
                    uint _11209;
                    _11209 = 4294967295u;
                    uint _12683;
                    for (int _11208 = 0; _11208 < 8; _11209 = _12683, _11208++)
                    {
                        int _11212 = 0;
                        for (;;)
                        {
                            if (_11212 < 5)
                            {
                                int2 _9219 = _10583 + (_1093[_11208] * _1102[_11212].xx);
                                bool _9222 = any(bool2(_9219.x < int2(0, 0).x, _9219.y < int2(0, 0).y));
                                bool _9230;
                                if (!_9222)
                                {
                                    _9230 = any(bool2(_9219.x >= cbFI_MvDepthLaneSize.x, _9219.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _9230 = _9222;
                                }
                                if (_9230)
                                {
                                    _12683 = _11209;
                                    break;
                                }
                                uint4 _9308 = r_warped_motion_qdata_tp1.Load(int3(_9219, 0));
                                uint _9309 = _9308.x;
                                if (_9309 != 0u)
                                {
                                    _12683 = min(_11209, _9309);
                                    break;
                                }
                                _11212++;
                                continue;
                            }
                            else
                            {
                                _12683 = _11209;
                                break;
                            }
                        }
                    }
                    float _11211;
                    if (_11209 == 4294967295u)
                    {
                        _11211 = -1.0f;
                    }
                    else
                    {
                        float _11210;
                        if (_11209 == 0u)
                        {
                            _11210 = -1.0f;
                        }
                        else
                        {
                            _11210 = float((_11209 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11211 = _11210;
                    }
                    _11224 = _11211;
                    break;
                } while(false);
                float4 _11253;
                if (_11224 >= 0.0f)
                {
                    float _9330 = (exp((_11224 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5341;
                    if (_5119)
                    {
                        uint _9337_dummy_parameter;
                        _5341 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_10556 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9337_dummy_parameter))))), 0)).x) > _9330;
                    }
                    else
                    {
                        _5341 = _5119;
                    }
                    float4 _11242;
                    if (_5341)
                    {
                        float4 _10442 = _11229;
                        _10442.z = 0.0f;
                        _11242 = _10442;
                    }
                    else
                    {
                        _11242 = _11229;
                    }
                    bool _5353;
                    if (_5125)
                    {
                        uint _9357_dummy_parameter;
                        _5353 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_10557 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9357_dummy_parameter))))), 0)).x) > _9330;
                    }
                    else
                    {
                        _5353 = _5125;
                    }
                    float4 _11254;
                    if (_5353)
                    {
                        float4 _10444 = _11242;
                        _10444.w = 0.0f;
                        _11254 = _10444;
                    }
                    else
                    {
                        _11254 = _11242;
                    }
                    _11253 = _11254;
                }
                else
                {
                    _11253 = _11229;
                }
                _11252 = _11253;
            }
            else
            {
                _11252 = _11229;
            }
            bool _5361 = _5107 != _5113;
            bool _5368;
            if (_5361)
            {
                _5368 = _5107 ? _5053 : _5056;
            }
            else
            {
                _5368 = _5361;
            }
            bool _5375;
            if (_5368)
            {
                _5375 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5375 = _5368;
            }
            float4 _11337;
            if (_5375)
            {
                bool2 _5380 = _5107.xx;
                float2 _5381 = float2(_5380.x ? _10553.x : _10555.x, _5380.y ? _10553.y : _10555.y);
                float _11244;
                if (_5107)
                {
                    uint _9377_dummy_parameter;
                    _11244 = r_depth_tm1.Load(int3(int2(floor(_5381 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9377_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9393_dummy_parameter;
                    _11244 = r_depth_tp1.Load(int3(int2(floor(_5381 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9393_dummy_parameter))))), 0)).x;
                }
                float4x4 _11245;
                if (_5107)
                {
                    _11245 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _11245 = cbFI_MotionTP1ToTM1;
                }
                float2 _11246;
                do
                {
                    float _9420 = _5381.x;
                    float _9423 = 1.0f - _5381.y;
                    float4 _9434 = mul(float4((float2(_9420, _9423) * 2.0f) - 1.0f.xx, _11244, 1.0f), _11245);
                    float _9436 = _9434.w;
                    if (!(_9436 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11246 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9449 = ((_9434.xy / _9436.xx) + 1.0f.xx) * 0.5f;
                    _11246 = float2(_9449.x - _9420, _9423 - _9449.y);
                    break;
                } while(false);
                float2 _5411 = float2(cbFI_DisplaySize);
                float4 _11338;
                if (!(length(((_5381 + _11246) - float2(_5380.x ? _10555.x : _10553.x, _5380.y ? _10555.y : _10553.y)) * _5411) <= ((0.100000001490116119384765625f * length(_11246 * _5411)) + 8.0f)))
                {
                    float4 _11339;
                    if (_5107)
                    {
                        float4 _10454 = _11252;
                        _10454.x = 0.0f;
                        _11339 = _10454;
                    }
                    else
                    {
                        float4 _10456 = _11252;
                        _10456.y = 0.0f;
                        _11339 = _10456;
                    }
                    _11338 = _11339;
                }
                else
                {
                    _11338 = _11252;
                }
                _11337 = _11338;
            }
            else
            {
                _11337 = _11252;
            }
            float4 _5436 = _10999 * _11337;
            float _5438 = dot(_5436, 1.0f.xxxx);
            float4 _11579;
            bool _11599;
            if (_5438 > 0.0f)
            {
                _11599 = _10706;
                _11579 = _5436 / _5438.xxxx;
            }
            else
            {
                bool _5449 = any(bool4(_11337.x < 1.0f.xxxx.x, _11337.y < 1.0f.xxxx.y, _11337.z < 1.0f.xxxx.z, _11337.w < 1.0f.xxxx.w));
                if (_5449)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9471;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9471);
                    }
                }
                bool4 _12718 = _5449.xxxx;
                _11599 = _5449 ? true : _10706;
                _11579 = float4(_12718.x ? 0.0f.xxxx.x : _10999.x, _12718.y ? 0.0f.xxxx.y : _10999.y, _12718.z ? 0.0f.xxxx.z : _10999.z, _12718.w ? 0.0f.xxxx.w : _10999.w);
            }
            _11712 = _11813;
            _11598 = _11599;
            _11578 = _11579;
        }
        else
        {
            _11712 = float3(0.0f, 0.0f, 0.5f);
            _11598 = _10706;
            _11578 = _10999;
        }
        uint _5458 = (cbFI_pad0 >> 24u) & 31u;
        uint _5462 = (cbFI_pad0 >> 16u) & 255u;
        bool _5464 = _5458 != 0u;
        bool _5466 = _5462 == 12u;
        bool _5469 = _5462 == 13u;
        float4 _11595;
        if ((_5464 || _5466) || _5469)
        {
            float _11340;
            do
            {
                bool _9555 = all(bool2(_10556.x > 0.0f.xx.x, _10556.y > 0.0f.xx.y));
                bool _9561;
                if (_9555)
                {
                    _9561 = all(bool2(_10556.x < 1.0f.xx.x, _10556.y < 1.0f.xx.y));
                }
                else
                {
                    _9561 = _9555;
                }
                bool _9492 = !_9561;
                bool _9499;
                if (!_9492)
                {
                    bool _9566 = all(bool2(_10557.x > 0.0f.xx.x, _10557.y > 0.0f.xx.y));
                    bool _9572;
                    if (_9566)
                    {
                        _9572 = all(bool2(_10557.x < 1.0f.xx.x, _10557.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9572 = _9566;
                    }
                    _9499 = !_9572;
                }
                else
                {
                    _9499 = _9492;
                }
                if (_9499)
                {
                    _11340 = 0.0f;
                    break;
                }
                uint _9579_dummy_parameter;
                uint _9595_dummy_parameter;
                float4 _9520 = mul(float4((float2(_10556.x, 1.0f - _10556.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10556 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9579_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9522 = _9520.w;
                if (abs(_9522) < 9.9999999747524270787835121154785e-07f)
                {
                    _11340 = 0.0f;
                    break;
                }
                float _9533 = abs(cbFI_DeviceToViewDepth.y / ((_9520.z / _9522) - cbFI_DeviceToViewDepth.x));
                float _9536 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10557 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9595_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _11340 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9533 - _9536) / max(max(_9533, _9536), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9643 = all(bool2(_10557.x > 0.0f.xx.x, _10557.y > 0.0f.xx.y));
            bool _9649;
            if (_9643)
            {
                _9649 = all(bool2(_10557.x < 1.0f.xx.x, _10557.y < 1.0f.xx.y));
            }
            else
            {
                _9649 = _9643;
            }
            float _11341;
            if (_9649)
            {
                uint _9656_dummy_parameter;
                _11341 = length((_6269 + (r_motion_tp1.Load(int3(int2(floor(_10557 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9656_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _11341 = 1000000.0f;
            }
            float _11352;
            if ((_5458 & 1u) != 0u)
            {
                _11352 = _11340;
            }
            else
            {
                _11352 = 1.0f;
            }
            float _11353;
            if ((_5458 & 2u) != 0u)
            {
                _11353 = _11352 * (1.0f - smoothstep(2.0f, 8.0f, _11341));
            }
            else
            {
                _11353 = _11352;
            }
            float _11354;
            if ((_5458 & 4u) != 0u)
            {
                _11354 = _11353 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6990 - _6998) - length(_6974 - _6982))));
            }
            else
            {
                _11354 = _11353;
            }
            float _11589;
            if ((_5458 & 8u) != 0u)
            {
                _11589 = lerp(1.0f, _11354, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6974 - _6982)));
            }
            else
            {
                _11589 = _11354;
            }
            bool _5544 = (_5458 & 16u) != 0u;
            bool _5553;
            if (_5544)
            {
                _5553 = length(_10551 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5553 = _5544;
            }
            float _12720 = _5553 ? 1.0f : _11589;
            bool _5559 = _5464 && _7183;
            bool _5564;
            if (_5559)
            {
                bool _9681 = all(bool2(_10553.x > 0.0f.xx.x, _10553.y > 0.0f.xx.y));
                bool _9687;
                if (_9681)
                {
                    _9687 = all(bool2(_10553.x < 1.0f.xx.x, _10553.y < 1.0f.xx.y));
                }
                else
                {
                    _9687 = _9681;
                }
                _5564 = _9687;
            }
            else
            {
                _5564 = _5559;
            }
            bool _5569;
            if (_5564)
            {
                bool _9692 = all(bool2(_10555.x > 0.0f.xx.x, _10555.y > 0.0f.xx.y));
                bool _9698;
                if (_9692)
                {
                    _9698 = all(bool2(_10555.x < 1.0f.xx.x, _10555.y < 1.0f.xx.y));
                }
                else
                {
                    _9698 = _9692;
                }
                _5569 = _9698;
            }
            else
            {
                _5569 = _5564;
            }
            float4 _11596;
            if (_5569)
            {
                float _5575 = _11578.x + _11578.y;
                float _5584 = (_11578.z + _11578.w) * (1.0f - _12720);
                float _11592;
                if (_5575 > 9.9999997473787516355514526367188e-06f)
                {
                    _11592 = _11578.x / _5575;
                }
                else
                {
                    _11592 = _4415;
                }
                _11596 = float4(_11578.x + (_5584 * _11592), _11578.y + (_5584 * (1.0f - _11592)), _11578.zw * _12720);
            }
            else
            {
                _11596 = _11578;
            }
            _11595 = _11596;
        }
        else
        {
            _11595 = _11578;
        }
        float3 _12485;
        if (_11598)
        {
            float3 _9704 = r_current_interpolation_source.Load(int3(_3771, 0)).xyz;
            float3 _12486;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _7183)
            {
                uint _9711_dummy_parameter;
                float _11703;
                _11703 = r_depth_tm1.Load(int3(int2(floor(_10553 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9711_dummy_parameter))))), 0)).x;
                float _5696;
                for (int _11702 = 0; _11702 < 24; _11703 = _5696, _11702++)
                {
                    float _5668 = float(_11702 & 7) * 0.785398185253143310546875f;
                    int _5670 = _11702 >> 3;
                    int _12536;
                    if (_5670 == 0)
                    {
                        _12536 = 16;
                    }
                    else
                    {
                        _12536 = (_5670 == 1) ? 48 : 96;
                    }
                    uint _9731_dummy_parameter;
                    _5696 = max(_11703, r_depth_tm1.Load(int3(int2(floor(clamp(_10553 + ((cbFI_MvDepthLaneSizeRcp * float(_12536)) * float2(cos(_5668), sin(_5668))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9731_dummy_parameter))))), 0)).x);
                }
                float2 _11704;
                do
                {
                    float _9753 = 1.0f - _10553.y;
                    float4 _9764 = mul(float4((float2(_10553.x, _9753) * 2.0f) - 1.0f.xx, _11703, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9766 = _9764.w;
                    if (!(_9766 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11704 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9779 = ((_9764.xy / _9766.xx) + 1.0f.xx) * 0.5f;
                    _11704 = float2(_9779.x - _10553.x, _9753 - _9779.y);
                    break;
                } while(false);
                float2 _5707 = _10553 + _11704;
                bool _9797 = all(bool2(_5707.x > 0.0f.xx.x, _5707.y > 0.0f.xx.y));
                bool _9803;
                if (_9797)
                {
                    _9803 = all(bool2(_5707.x < 1.0f.xx.x, _5707.y < 1.0f.xx.y));
                }
                else
                {
                    _9803 = _9797;
                }
                float3 _12487;
                if (_9803)
                {
                    float _5713 = abs(cbFI_DeviceToViewDepth.y / (_11703 - cbFI_DeviceToViewDepth.x));
                    uint _9823_dummy_parameter;
                    int2 _9823 = int2(spvTextureSize(r_depth_m2, uint(0), _9823_dummy_parameter));
                    float _5717 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5707 * float2(_9823))), int2(0, 0), _9823 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12492;
                    if (abs(_5717 - _5713) <= (0.20000000298023223876953125f * max(_5717, _5713)))
                    {
                        uint _9857_dummy_parameter;
                        int2 _9857 = int2(spvTextureSize(r_colour_m2, uint(0), _9857_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9880;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9880);
                        }
                        _12492 = r_colour_m2.Load(int3(clamp(int2(floor(_5707 * float2(_9857))), int2(0, 0), _9857 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9890;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9890);
                        }
                        _12492 = _9704;
                    }
                    _12487 = _12492;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9900;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9900);
                    }
                    _12487 = _9704;
                }
                _12486 = _12487;
            }
            else
            {
                _12486 = _9704;
            }
            _12485 = _12486;
        }
        else
        {
            _12485 = (((_6974 * _11595.x) + (_6982 * _11595.y)) + (_6990 * _11595.z)) + (_6998 * _11595.w);
        }
        uint _5745 = cbFI_pad0 & 255u;
        bool _12377;
        float3 _12484;
        if (_5745 != 0u)
        {
            float3 _5750 = r_present_backbuffer.Load(int3(_3771, 0)).xyz;
            float3 _5754 = r_current_interpolation_source.Load(int3(_3771, 0)).xyz;
            float3 _5758 = abs(_5750 - _5754);
            float3 _11707;
            if (_5745 == 2u)
            {
                _11707 = (abs(_5754) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11707 = 0.000244140625f.xxx;
            }
            bool _5774 = any(bool3(_5758.x > _11707.x, _5758.y > _11707.y, _5758.z > _11707.z));
            bool3 _12721 = _5774.xxx;
            _12484 = float3(_12721.x ? _5750.x : _12485.x, _12721.y ? _5750.y : _12485.y, _12721.z ? _5750.z : _12485.z);
            _12377 = _5774;
        }
        else
        {
            _12484 = _12485;
            _12377 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9915;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9915);
        }
        float3 _12467;
        if (_5462 == 1u)
        {
            _12467 = lerp(_6974, _6982, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12468;
            if (_5462 == 2u)
            {
                _12468 = lerp(_6990, _6998, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12469;
                if (_5462 == 3u)
                {
                    _12469 = float(_12377).xxx;
                }
                else
                {
                    float3 _12470;
                    if (_5462 == 4u)
                    {
                        _12470 = float3(((_10551 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12471;
                        if (_5462 == 5u)
                        {
                            _12471 = float3(((_6269 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12472;
                            if (_5462 == 6u)
                            {
                                _12472 = float3(_11595.xy, _11595.z + _11595.w);
                            }
                            else
                            {
                                float3 _12473;
                                if (_5462 == 7u)
                                {
                                    _12473 = r_current_interpolation_source.Load(int3(_3771, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12474;
                                    if (_5462 == 8u)
                                    {
                                        _12474 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4190, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12475;
                                        if (_5466)
                                        {
                                            uint _9937_dummy_parameter;
                                            uint _9969_dummy_parameter;
                                            _12475 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4190 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9937_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4190 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9969_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12476;
                                            if (_5469)
                                            {
                                                _12476 = _6990;
                                            }
                                            else
                                            {
                                                float3 _12477;
                                                if (_5462 == 20u)
                                                {
                                                    _12477 = _6974;
                                                }
                                                else
                                                {
                                                    float3 _12478;
                                                    if (_5462 == 21u)
                                                    {
                                                        _12478 = _6982;
                                                    }
                                                    else
                                                    {
                                                        float3 _12479;
                                                        if (_5462 == 22u)
                                                        {
                                                            _12479 = _6998;
                                                        }
                                                        else
                                                        {
                                                            float3 _12480;
                                                            if (_5462 == 18u)
                                                            {
                                                                _12480 = _12123;
                                                            }
                                                            else
                                                            {
                                                                float3 _12481;
                                                                if (_5462 == 19u)
                                                                {
                                                                    _12481 = _11915;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12723 = (_5462 == 23u).xxx;
                                                                    _12481 = float3(_12723.x ? _11712.x : _12484.x, _12723.y ? _11712.y : _12484.y, _12723.z ? _11712.z : _12484.z);
                                                                }
                                                                _12480 = _12481;
                                                            }
                                                            _12479 = _12480;
                                                        }
                                                        _12478 = _12479;
                                                    }
                                                    _12477 = _12478;
                                                }
                                                _12476 = _12477;
                                            }
                                            _12475 = _12476;
                                        }
                                        _12474 = _12475;
                                    }
                                    _12473 = _12474;
                                }
                                _12472 = _12473;
                            }
                            _12471 = _12472;
                        }
                        _12470 = _12471;
                    }
                    _12469 = _12470;
                }
                _12468 = _12469;
            }
            _12467 = _12468;
        }
        float3 _12466;
        if ((_5462 >= 9u) && (_5462 <= 11u))
        {
            uint _5938 = 64u + uint((_10583.y * cbFI_MvDepthLaneSize.x) + _10583.x);
            uint _5942 = rw_nfru_diagnostics.Load<uint>(_5938 * 4 + 0) & 15u;
            float3 _12497;
            if (_5462 == 10u)
            {
                float3 _12465;
                if ((rw_nfru_diagnostics.Load<uint>(_5938 * 4 + 0) & 32u) != 0u)
                {
                    _12465 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12464;
                    if ((rw_nfru_diagnostics.Load<uint>(_5938 * 4 + 0) & 16u) != 0u)
                    {
                        _12464 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5963 = ((rw_nfru_diagnostics.Load<uint>(_5938 * 4 + 0) & 64u) != 0u).xxx;
                        _12464 = float3(_5963.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5963.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5963.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12465 = _12464;
                }
                _12497 = _12465;
            }
            else
            {
                float3 _12498;
                if (_5462 == 11u)
                {
                    uint _5976 = (rw_nfru_diagnostics.Load<uint>(_5938 * 4 + 0) >> 8u) & 15u;
                    uint _5979 = (rw_nfru_diagnostics.Load<uint>(_5938 * 4 + 0) >> 12u) & 15u;
                    float3 _12457;
                    if ((_5942 == 2u) || (_5942 == 3u))
                    {
                        _12457 = _3467[_5942];
                    }
                    else
                    {
                        bool _5991 = _5976 == 3u;
                        bool _5993 = _5979 == 3u;
                        float3 _12458;
                        if (_5991 && _5993)
                        {
                            _12458 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12459;
                            if (_5991)
                            {
                                _12459 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12460;
                                if (_5993)
                                {
                                    _12460 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12461;
                                    if ((_5976 == 4u) || (_5979 == 4u))
                                    {
                                        _12461 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12462;
                                        if ((_5976 == 1u) || (_5979 == 1u))
                                        {
                                            _12462 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12725 = (_5942 == 1u).xxx;
                                            _12462 = float3(_12725.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12725.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12725.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12461 = _12462;
                                    }
                                    _12460 = _12461;
                                }
                                _12459 = _12460;
                            }
                            _12458 = _12459;
                        }
                        _12457 = _12458;
                    }
                    _12498 = _12457;
                }
                else
                {
                    _12498 = _3467[min(_5942, 7u)];
                }
                _12497 = _12498;
            }
            _12466 = _12497;
        }
        else
        {
            _12466 = _12467;
        }
        float4 _12501;
        if ((_5462 >= 14u) && (_5462 <= 16u))
        {
            float2 _12499;
            if (_5462 == 14u)
            {
                uint _6049_dummy_parameter;
                uint _6055_dummy_parameter;
                _12499 = r_flow_tm1.Load(int3(clamp(int2(floor(_4190 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6049_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6055_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12500;
                if (_5462 == 16u)
                {
                    uint _10020 = r_warped_flow_qdata_tm1.Load(int3(_4206, 0)).x & 2147483647u;
                    uint _10052 = uint(max((int((_10020 >> 16u) & 15u) - 6), 0));
                    _12500 = ((float2(float((1 - (2 * int((_10020 >> 15u) & 1u))) * int(((_10020 >> uint(7)) & 127u) << _10052)), float((1 - (2 * int((_10020 >> 14u) & 1u))) * int((_10020 & 127u) << _10052))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12500 = _6269 * float2(cbFI_DisplaySize);
                }
                _12499 = _12500;
            }
            uint2 _6088 = uint2(clamp(round(_12499 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6090 = _6088.x;
            uint _6097 = _6088.y;
            _12501 = float4(float(_6090 & 255u), float((_6090 >> 8u) | ((_6097 & 15u) << 4u)), float(_6097 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12502;
            if (_5462 == 17u)
            {
                _12502 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4206, 0)).x != 0u), _4549, 0.0f, 1.0f);
            }
            else
            {
                _12502 = float4(_12466, 1.0f);
            }
            _12501 = _12502;
        }
        rw_output[_3771] = _12501.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6141 = ((uint(_3771.y) * uint(cbFI_DisplaySize.x)) + uint(_3771.x)) * 6u;
            uint _10098 = spvPackHalf2x16(clamp(_6973.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6141 * 4 + 0, (((_10098 & 32767u) >> 4u) | ((((_10098 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6973.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10133 = spvPackHalf2x16(clamp(_6981.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6141 + 1u) * 4 + 0, (((_10133 & 32767u) >> 4u) | ((((_10133 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6981.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10168 = spvPackHalf2x16(clamp(_6989.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6141 + 2u) * 4 + 0, (((_10168 & 32767u) >> 4u) | ((((_10168 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6989.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10203 = spvPackHalf2x16(clamp(_6997.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6141 + 3u) * 4 + 0, (((_10203 & 32767u) >> 4u) | ((((_10203 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6997.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _10230 = r_current_interpolation_source.Load(int3(_3771, 0));
            uint _10244 = spvPackHalf2x16(clamp(_10230.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6141 + 4u) * 4 + 0, (((_10244 & 32767u) >> 4u) | ((((_10244 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10230.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12535;
            if (_12377 || (_5462 != 0u))
            {
                _12535 = 4294967295u;
            }
            else
            {
                uint _10279 = spvPackHalf2x16(clamp(_12501.xy, 0.0f.xx, 65000.0f.xx));
                _12535 = (((_10279 & 32767u) >> 4u) | ((((_10279 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12501.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6141 + 5u) * 4 + 0, _12535);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3771] = float4(r_current_interpolation_source.Load(int3(_3771, 0)).xyz, 1.0f).xyz;
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
