static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3453[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3757 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3757.x >= cbFI_DisplaySize.x, _3757.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3757] = float4(r_present_backbuffer.Load(int3(_3757, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3757] = float4(r_current_interpolation_source.Load(int3(_3757, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4173 = (float2(_3757) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4184 = int2(floor(_4173 * float2(cbFI_MvDepthLaneSize)));
        int2 _4189 = int2(floor(_4173 * float2(cbFI_FlowLaneSize)));
        float4 _6236 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4173 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6242 = r_warped_filled_flow_tm1.Load(int3(_4189, 0)).xy;
        float2 _6248 = r_warped_filled_motion_tp1.Load(int3(_4184, 0)).xy;
        bool _6270 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10493;
        if (_6270)
        {
            float _6283 = ((2.0f * _4173.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10493 = float2(atan(_6283) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4173.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6283 * _6283))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10493 = _4173;
        }
        bool _4210 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10514;
        bool _10535;
        int2 _10546;
        float3 _12052;
        if (_4210)
        {
            float _10495;
            float _10497;
            _10497 = 2.0f;
            _10495 = -1.0f;
            uint _3821[9];
            float _12505;
            float _12508;
            for (int _10494 = 0; _10494 < 9; _10497 = _12508, _10495 = _12505, _10494++)
            {
                _3821[_10494] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4184 + int2((_10494 % 3) - 1, (_10494 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3821[_10494] != 0u)
                {
                    float _12500;
                    if (_3821[_10494] == 0u)
                    {
                        _12500 = -1.0f;
                    }
                    else
                    {
                        _12500 = float((_3821[_10494] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12508 = min(_10497, _12500);
                    _12505 = max(_10495, _12500);
                }
                else
                {
                    _12508 = _10497;
                    _12505 = _10495;
                }
            }
            float _4256 = float(_10495 >= 0.0f);
            float3 _10280 = 0.0f.xxx;
            _10280.y = _4256;
            float2 _10515;
            bool _10536;
            int2 _10547;
            float3 _12053;
            if ((_10495 - _10497) > 0.0199999995529651641845703125f)
            {
                float _10503;
                int2 _10504;
                float2 _10505;
                int2 _10507;
                float2 _10513;
                _10513 = _6248;
                _10507 = _4184;
                _10505 = _6248;
                _10504 = _4184;
                _10503 = -1.0f;
                float _12513;
                int2 _12517;
                float2 _12528;
                int2 _12539;
                float2 _12572;
                float _12619;
                int _10502 = 0;
                float _12481 = 1000000000.0f;
                for (; _10502 < 9; _12481 = _12619, _10513 = _12572, _10507 = _12539, _10505 = _12528, _10504 = _12517, _10503 = _12513, _10502++)
                {
                    if (_3821[_10502] == 0u)
                    {
                        _12619 = _12481;
                        _12572 = _10513;
                        _12539 = _10507;
                        _12528 = _10505;
                        _12517 = _10504;
                        _12513 = _10503;
                        continue;
                    }
                    int2 _4291 = clamp(_4184 + int2((_10502 % 3) - 1, (_10502 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6358 = _3821[_10502] & 2147483647u;
                    uint _6390 = uint(max((int((_6358 >> 16u) & 15u) - 6), 0));
                    float2 _4297 = (float2(float((1 - (2 * int((_6358 >> 15u) & 1u))) * int(((_6358 >> uint(7)) & 127u) << _6390)), float((1 - (2 * int((_6358 >> 14u) & 1u))) * int((_6358 & 127u) << _6390))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12467;
                    if (_3821[_10502] == 0u)
                    {
                        _12467 = -1.0f;
                    }
                    else
                    {
                        _12467 = float((_3821[_10502] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4302 = _12467 - 0.100000001490116119384765625f;
                    float2 _12468;
                    if (_6270)
                    {
                        float2 _6467 = clamp((((_10493 + (_4297 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6470 = tan(_6467.x);
                        _12468 = (float2(_6470 / cbFI_DeviceToViewDepth.z, (tan(_6467.y) * sqrt(1.0f + (_6470 * _6470))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12468 = _10493 + (_4297 * cbFI_Timestep);
                    }
                    float _4309 = cbFI_Timestep - 1.0f;
                    float2 _12469;
                    if (_6270)
                    {
                        float2 _6538 = clamp((((_10493 + (_4297 * _4309)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6541 = tan(_6538.x);
                        _12469 = (float2(_6541 / cbFI_DeviceToViewDepth.z, (tan(_6538.y) * sqrt(1.0f + (_6541 * _6541))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12469 = _10493 + (_4297 * _4309);
                    }
                    bool _6574 = all(bool2(_12468.x > 0.0f.xx.x, _12468.y > 0.0f.xx.y));
                    bool _6580;
                    if (_6574)
                    {
                        _6580 = all(bool2(_12468.x < 1.0f.xx.x, _12468.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6580 = _6574;
                    }
                    float _12472;
                    if (_6580)
                    {
                        uint _6587_dummy_parameter;
                        _12472 = max((_4302 - (log((r_depth_tm1.Load(int3(int2(floor(_12468 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6587_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12472 = 0.0f;
                    }
                    bool _6617 = all(bool2(_12469.x > 0.0f.xx.x, _12469.y > 0.0f.xx.y));
                    bool _6623;
                    if (_6617)
                    {
                        _6623 = all(bool2(_12469.x < 1.0f.xx.x, _12469.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6623 = _6617;
                    }
                    float _12473;
                    if (_6623)
                    {
                        uint _6630_dummy_parameter;
                        _12473 = _12472 + max((_4302 - (log((r_depth_tp1.Load(int3(int2(floor(_12469 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6630_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12473 = _12472;
                    }
                    float _12514;
                    int2 _12518;
                    float2 _12529;
                    int2 _12540;
                    float2 _12573;
                    float _12620;
                    if (_12473 == 0.0f)
                    {
                        bool _4344 = _4302 > _10503;
                        bool2 _12628 = _4344.xx;
                        _12620 = _12481;
                        _12573 = float2(_12628.x ? _4297.x : _10513.x, _12628.y ? _4297.y : _10513.y);
                        _12540 = int2(_12628.x ? _4291.x : _10507.x, _12628.y ? _4291.y : _10507.y);
                        _12529 = _10505;
                        _12518 = _10504;
                        _12514 = _4344 ? _4302 : _10503;
                    }
                    else
                    {
                        bool _4353 = _12473 < _12481;
                        bool2 _12624 = _4353.xx;
                        _12620 = _4353 ? _12473 : _12481;
                        _12573 = _10513;
                        _12540 = _10507;
                        _12529 = float2(_12624.x ? _4297.x : _10505.x, _12624.y ? _4297.y : _10505.y);
                        _12518 = int2(_12624.x ? _4291.x : _10504.x, _12624.y ? _4291.y : _10504.y);
                        _12514 = _10503;
                    }
                    _12619 = _12620;
                    _12572 = _12573;
                    _12539 = _12540;
                    _12528 = _12529;
                    _12517 = _12518;
                    _12513 = _12514;
                }
                bool _4365 = _10503 < 0.0f;
                bool2 _12634 = _4365.xx;
                int2 _12637 = int2(_12634.x ? _10504.x : _10507.x, _12634.y ? _10504.y : _10507.y);
                _12053 = float3(1.0f, _4256, float(any(bool2(_12637.x != _4184.x, _12637.y != _4184.y))));
                _10547 = _12637;
                _10536 = _4365 ? false : true;
                _10515 = float2(_12634.x ? _10505.x : _10513.x, _12634.y ? _10505.y : _10513.y);
            }
            else
            {
                _12053 = _10280;
                _10547 = _4184;
                _10536 = false;
                _10515 = _6248;
            }
            _12052 = _12053;
            _10546 = _10547;
            _10535 = _10536;
            _10514 = _10515;
        }
        else
        {
            _12052 = 0.0f.xxx;
            _10546 = _4184;
            _10535 = false;
            _10514 = _6248;
        }
        float2 _10516;
        if (_6270)
        {
            float2 _6695 = clamp((((_10493 + (_10514 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6698 = tan(_6695.x);
            _10516 = (float2(_6698 / cbFI_DeviceToViewDepth.z, (tan(_6695.y) * sqrt(1.0f + (_6698 * _6698))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10516 = _10493 + (_10514 * cbFI_Timestep);
        }
        float _4388 = cbFI_Timestep - 1.0f;
        float2 _10518;
        if (_6270)
        {
            float2 _6766 = clamp((((_10493 + (_10514 * _4388)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6769 = tan(_6766.x);
            _10518 = (float2(_6769 / cbFI_DeviceToViewDepth.z, (tan(_6766.y) * sqrt(1.0f + (_6769 * _6769))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10518 = _10493 + (_10514 * _4388);
        }
        float _4393 = -cbFI_Timestep;
        float2 _10519;
        if (_6270)
        {
            float2 _6837 = clamp((((_10493 + (_6242 * _4393)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6840 = tan(_6837.x);
            _10519 = (float2(_6840 / cbFI_DeviceToViewDepth.z, (tan(_6837.y) * sqrt(1.0f + (_6840 * _6840))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10519 = _10493 + (_6242 * _4393);
        }
        float _4398 = 1.0f - cbFI_Timestep;
        float2 _10520;
        if (_6270)
        {
            float2 _6908 = clamp((((_10493 + (_6242 * _4398)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6911 = tan(_6908.x);
            _10520 = (float2(_6911 / cbFI_DeviceToViewDepth.z, (tan(_6908.y) * sqrt(1.0f + (_6911 * _6911))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10520 = _10493 + (_6242 * _4398);
        }
        float4 _6946 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10516, 0.0f);
        float3 _6947 = _6946.xyz;
        float4 _6954 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10518, 0.0f);
        float3 _6955 = _6954.xyz;
        float4 _6962 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10519, 0.0f);
        float3 _6963 = _6962.xyz;
        float4 _6970 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10520, 0.0f);
        float3 _6971 = _6970.xyz;
        float4 _6985 = exp(_6236 - max(max(max(_6236.x, _6236.y), _6236.z), _6236.w).xxxx);
        float4 _6992 = _6985 / (dot(_6985, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4417 = _4210 && (!_10535);
        bool _4426;
        if (_4417)
        {
            _4426 = (_6992.z + _6992.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4426 = _4417;
        }
        bool _4437;
        if (_4426)
        {
            _4437 = length((_10519 - _10516) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4437 = _4426;
        }
        bool _10559;
        if (_4437)
        {
            uint4 _7011 = r_warped_motion_qdata_tp1.Load(int3(_10546, 0));
            uint _7012 = _7011.x;
            bool _10562;
            if (_7012 != 0u)
            {
                float _10548;
                if (_7012 == 0u)
                {
                    _10548 = -1.0f;
                }
                else
                {
                    _10548 = float((_7012 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4447 = _10548 - 0.12000000476837158203125f;
                bool _7031 = all(bool2(_10519.x > 0.0f.xx.x, _10519.y > 0.0f.xx.y));
                bool _7037;
                if (_7031)
                {
                    _7037 = all(bool2(_10519.x < 1.0f.xx.x, _10519.y < 1.0f.xx.y));
                }
                else
                {
                    _7037 = _7031;
                }
                bool _4457;
                if (_7037)
                {
                    uint _7044_dummy_parameter;
                    _4457 = (log((r_depth_tm1.Load(int3(int2(floor(_10519 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7044_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4447;
                }
                else
                {
                    _4457 = _7037;
                }
                bool _4471;
                if (!_4457)
                {
                    bool _7074 = all(bool2(_10520.x > 0.0f.xx.x, _10520.y > 0.0f.xx.y));
                    bool _7080;
                    if (_7074)
                    {
                        _7080 = all(bool2(_10520.x < 1.0f.xx.x, _10520.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7080 = _7074;
                    }
                    bool _4469;
                    if (_7080)
                    {
                        uint _7087_dummy_parameter;
                        _4469 = (log((r_depth_tp1.Load(int3(int2(floor(_10520 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7087_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4447;
                    }
                    else
                    {
                        _4469 = _7080;
                    }
                    _4471 = _4469;
                }
                else
                {
                    _4471 = _4457;
                }
                _10562 = _4471;
            }
            else
            {
                _10562 = false;
            }
            _10559 = _10562;
        }
        else
        {
            _10559 = false;
        }
        bool _4476 = _10535 || _10559;
        bool _4481;
        if (_4476)
        {
            bool _7117 = all(bool2(_10516.x > 0.0f.xx.x, _10516.y > 0.0f.xx.y));
            bool _7123;
            if (_7117)
            {
                _7123 = all(bool2(_10516.x < 1.0f.xx.x, _10516.y < 1.0f.xx.y));
            }
            else
            {
                _7123 = _7117;
            }
            _4481 = _7123;
        }
        else
        {
            _4481 = _4476;
        }
        bool _4486;
        if (_4481)
        {
            bool _7128 = all(bool2(_10518.x > 0.0f.xx.x, _10518.y > 0.0f.xx.y));
            bool _7134;
            if (_7128)
            {
                _7134 = all(bool2(_10518.x < 1.0f.xx.x, _10518.y < 1.0f.xx.y));
            }
            else
            {
                _7134 = _7128;
            }
            _4486 = _7134;
        }
        else
        {
            _4486 = _4481;
        }
        float4 _10656;
        if (_4486)
        {
            float _4489 = _6992.x;
            float _4491 = _6992.y;
            float _4492 = _4489 + _4491;
            float _4497 = _6992.z + _6992.w;
            float _10577;
            if (_4492 > 0.001000000047497451305389404296875f)
            {
                _10577 = _4489 / _4492;
            }
            else
            {
                _10577 = _4398;
            }
            _10656 = float4(_4489 + (_4497 * _10577), _4491 + (_4497 * (1.0f - _10577)), 0.0f, 0.0f);
        }
        else
        {
            _10656 = _6992;
        }
        bool _7162 = (cbFI_pad0 & 1024u) != 0u;
        bool _7138 = !_7162;
        bool _7139 = !_7138;
        bool _7156;
        if (_7139)
        {
            _7156 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10546.y * cbFI_MvDepthLaneSize.x) + _10546.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _7156 = _7138;
        }
        bool _7188;
        if (_7139)
        {
            _7188 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4189.y * cbFI_FlowLaneSize.x) + _4189.x)) * 4 + 0) != 0u;
        }
        else
        {
            _7188 = _7138;
        }
        float _4532 = float(_7188);
        bool _10669;
        float4 _10700;
        float3 _11845;
        if (_7162)
        {
            bool _4542;
            if (_7156)
            {
                _4542 = all(bool2(_10516.x > 0.0f.xx.x, _10516.y > 0.0f.xx.y));
            }
            else
            {
                _4542 = _7156;
            }
            bool _4548;
            if (_4542)
            {
                _4548 = all(bool2(_10516.x < 1.0f.xx.x, _10516.y < 1.0f.xx.y));
            }
            else
            {
                _4548 = _4542;
            }
            bool _4555;
            if (_7156)
            {
                _4555 = all(bool2(_10518.x > 0.0f.xx.x, _10518.y > 0.0f.xx.y));
            }
            else
            {
                _4555 = _7156;
            }
            bool _4561;
            if (_4555)
            {
                _4561 = all(bool2(_10518.x < 1.0f.xx.x, _10518.y < 1.0f.xx.y));
            }
            else
            {
                _4561 = _4555;
            }
            bool _4568;
            if (_7188)
            {
                _4568 = all(bool2(_10519.x > 0.0f.xx.x, _10519.y > 0.0f.xx.y));
            }
            else
            {
                _4568 = _7188;
            }
            bool _4574;
            if (_4568)
            {
                _4574 = all(bool2(_10519.x < 1.0f.xx.x, _10519.y < 1.0f.xx.y));
            }
            else
            {
                _4574 = _4568;
            }
            bool _4581;
            if (_7188)
            {
                _4581 = all(bool2(_10520.x > 0.0f.xx.x, _10520.y > 0.0f.xx.y));
            }
            else
            {
                _4581 = _7188;
            }
            bool _4587;
            if (_4581)
            {
                _4587 = all(bool2(_10520.x < 1.0f.xx.x, _10520.y < 1.0f.xx.y));
            }
            else
            {
                _4587 = _4581;
            }
            bool _4589 = !_7156;
            if (_4589)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7230;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7230);
                }
            }
            bool _4594 = !_7188;
            if (_4594)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7240;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7240);
                }
            }
            if (_7156 && _4594)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7250;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7250);
                }
            }
            if (_4589 && _7188)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7260;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7260);
                }
            }
            float _4613 = float(_4548);
            float _4615 = float(_4561);
            bool _4618 = _4574 && _4587;
            float _10611;
            if (_4618)
            {
                _10611 = 1.0f;
            }
            else
            {
                _10611 = (_4574 || _4587) ? 0.5f : 0.0f;
            }
            bool _10616;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4548)) && (!_4561))
            {
                bool _4648;
                if (_4618)
                {
                    float _10614;
                    do
                    {
                        bool _7344 = all(bool2(_10519.x > 0.0f.xx.x, _10519.y > 0.0f.xx.y));
                        bool _7350;
                        if (_7344)
                        {
                            _7350 = all(bool2(_10519.x < 1.0f.xx.x, _10519.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7350 = _7344;
                        }
                        bool _7281 = !_7350;
                        bool _7288;
                        if (!_7281)
                        {
                            bool _7355 = all(bool2(_10520.x > 0.0f.xx.x, _10520.y > 0.0f.xx.y));
                            bool _7361;
                            if (_7355)
                            {
                                _7361 = all(bool2(_10520.x < 1.0f.xx.x, _10520.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7361 = _7355;
                            }
                            _7288 = !_7361;
                        }
                        else
                        {
                            _7288 = _7281;
                        }
                        if (_7288)
                        {
                            _10614 = 0.0f;
                            break;
                        }
                        uint _7368_dummy_parameter;
                        uint _7384_dummy_parameter;
                        float4 _7309 = mul(float4((float2(_10519.x, 1.0f - _10519.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10519 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7368_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7311 = _7309.w;
                        if (abs(_7311) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10614 = 0.0f;
                            break;
                        }
                        float _7322 = abs(cbFI_DeviceToViewDepth.y / ((_7309.z / _7311) - cbFI_DeviceToViewDepth.x));
                        float _7325 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10520 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7384_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10614 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7322 - _7325) / max(max(_7322, _7325), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4648 = _10614 >= 0.5f;
                }
                else
                {
                    _4648 = _4618;
                }
                bool _4656;
                if (_4648)
                {
                    _4656 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4656 = _4648;
                }
                bool _10617;
                if (_4656)
                {
                    uint _7434_dummy_parameter;
                    float2 _10615;
                    do
                    {
                        float _7460 = 1.0f - _10519.y;
                        float4 _7471 = mul(float4((float2(_10519.x, _7460) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10519 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7434_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7473 = _7471.w;
                        if (!(_7473 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10615 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7486 = ((_7471.xy / _7473.xx) + 1.0f.xx) * 0.5f;
                        _10615 = float2(_7486.x - _10519.x, _7460 - _7486.y);
                        break;
                    } while(false);
                    float2 _4669 = float2(cbFI_DisplaySize);
                    _10617 = length(((_10519 + _10615) - _10520) * _4669) <= ((0.100000001490116119384765625f * length(_10615 * _4669)) + 8.0f);
                }
                else
                {
                    _10617 = _4648;
                }
                _10616 = _10617;
            }
            else
            {
                _10616 = true;
            }
            bool _4683 = !_10616;
            bool _12638 = _4683 ? false : _4587;
            bool _12639 = _4683 ? false : _4574;
            bool _10670;
            float4 _10701;
            if (!(((_4548 && _4561) && _12639) && _12638))
            {
                float4 _4705 = _10656 * float4(_4613, _4615, float(_12639), float(_12638));
                float _4707 = dot(_4705, 1.0f.xxxx);
                bool _4710 = !(_4707 > 0.0f);
                float4 _10702;
                if (!_4710)
                {
                    _10702 = _4705 / _4707.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7508;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7508);
                    }
                    _10702 = 0.0f.xxxx;
                }
                _10701 = _10702;
                _10670 = _4710;
            }
            else
            {
                _10701 = _10656;
                _10670 = false;
            }
            _11845 = float3(_4613, _4615, _10611);
            _10700 = _10701;
            _10669 = _10670;
        }
        else
        {
            _11845 = float3(float(_7156), _4532, 0.0f);
            _10700 = _10656;
            _10669 = false;
        }
        bool _4728 = !_10669;
        float4 _10764;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4728)
        {
            float _4735 = _10700.x + _10700.y;
            float4 _10765;
            if (_4735 > 0.001000000047497451305389404296875f)
            {
                _10765 = float4(_10700.x / _4735, _10700.y / _4735, 0.0f, 0.0f);
            }
            else
            {
                _10765 = float4(_4398, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10764 = _10765;
        }
        else
        {
            _10764 = _10700;
        }
        float4 _10921;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4728) && _7156)
        {
            float _10759;
            do
            {
                uint4 _7648 = r_warped_motion_qdata_tp1.Load(int3(_10546, 0));
                uint _7649 = _7648.x;
                if (_7649 != 0u)
                {
                    float _10758;
                    if (_7649 == 0u)
                    {
                        _10758 = -1.0f;
                    }
                    else
                    {
                        _10758 = float((_7649 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10759 = _10758;
                    break;
                }
                int _10741;
                uint _10742;
                _10742 = _7649;
                _10741 = -1;
                uint _10757;
                for (; _10741 <= 1; _10742 = _10757, _10741++)
                {
                    _10757 = _10742;
                    for (int _10755 = -1; _10755 <= 1; )
                    {
                        _10757 = max(_10757, r_warped_motion_qdata_tp1.Load(int3(clamp(_10546 + int2(_10755, _10741), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10755++;
                        continue;
                    }
                }
                if (_10742 != 0u)
                {
                    float _10754;
                    if (_10742 == 0u)
                    {
                        _10754 = -1.0f;
                    }
                    else
                    {
                        _10754 = float((_10742 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10759 = _10754;
                    break;
                }
                uint _10744;
                _10744 = 4294967295u;
                uint _12609;
                for (int _10743 = 0; _10743 < 8; _10744 = _12609, _10743++)
                {
                    int _10747 = 0;
                    for (;;)
                    {
                        if (_10747 < 5)
                        {
                            int2 _7599 = _10546 + (_1093[_10743] * _1102[_10747].xx);
                            bool _7602 = any(bool2(_7599.x < int2(0, 0).x, _7599.y < int2(0, 0).y));
                            bool _7610;
                            if (!_7602)
                            {
                                _7610 = any(bool2(_7599.x >= cbFI_MvDepthLaneSize.x, _7599.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7610 = _7602;
                            }
                            if (_7610)
                            {
                                _12609 = _10744;
                                break;
                            }
                            uint4 _7688 = r_warped_motion_qdata_tp1.Load(int3(_7599, 0));
                            uint _7689 = _7688.x;
                            if (_7689 != 0u)
                            {
                                _12609 = min(_10744, _7689);
                                break;
                            }
                            _10747++;
                            continue;
                        }
                        else
                        {
                            _12609 = _10744;
                            break;
                        }
                    }
                }
                float _10746;
                if (_10744 == 4294967295u)
                {
                    _10746 = -1.0f;
                }
                else
                {
                    float _10745;
                    if (_10744 == 0u)
                    {
                        _10745 = -1.0f;
                    }
                    else
                    {
                        _10745 = float((_10744 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10746 = _10745;
                }
                _10759 = _10746;
                break;
            } while(false);
            float _4771 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4773 = _10759 < 0.0f;
            bool _4778;
            if (_4773)
            {
                bool _7708 = all(bool2(_10516.x > 0.0f.xx.x, _10516.y > 0.0f.xx.y));
                bool _7714;
                if (_7708)
                {
                    _7714 = all(bool2(_10516.x < 1.0f.xx.x, _10516.y < 1.0f.xx.y));
                }
                else
                {
                    _7714 = _7708;
                }
                _4778 = _7714;
            }
            else
            {
                _4778 = _4773;
            }
            bool _4783;
            if (_4778)
            {
                bool _7719 = all(bool2(_10518.x > 0.0f.xx.x, _10518.y > 0.0f.xx.y));
                bool _7725;
                if (_7719)
                {
                    _7725 = all(bool2(_10518.x < 1.0f.xx.x, _10518.y < 1.0f.xx.y));
                }
                else
                {
                    _7725 = _7719;
                }
                _4783 = _7725;
            }
            else
            {
                _4783 = _4778;
            }
            float4 _10821;
            if (_4783)
            {
                uint _7732_dummy_parameter;
                float _7756 = log((r_depth_tm1.Load(int3(int2(floor(_10516 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7732_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _7764_dummy_parameter;
                float _7788 = log((r_depth_tp1.Load(int3(int2(floor(_10518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7764_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _4794 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4801;
                if (_4794)
                {
                    _4801 = _7788 > (_7756 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4801 = _4794;
                }
                float4 _10795;
                if (_4801)
                {
                    _10795 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10795 = 1.0f.xxxx;
                }
                bool _4808 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4815;
                if (_4808)
                {
                    _4815 = _7756 > (_7788 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4815 = _4808;
                }
                float4 _10824;
                if (_4815)
                {
                    float4 _10350 = _10795;
                    _10350.x = 0.0f;
                    _10824 = _10350;
                }
                else
                {
                    _10824 = _10795;
                }
                _10821 = _10824;
            }
            else
            {
                bool _4823 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4829;
                if (_4823)
                {
                    _4829 = _10764.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4829 = _4823;
                }
                bool _4834;
                if (_4829)
                {
                    bool _7794 = all(bool2(_10518.x > 0.0f.xx.x, _10518.y > 0.0f.xx.y));
                    bool _7800;
                    if (_7794)
                    {
                        _7800 = all(bool2(_10518.x < 1.0f.xx.x, _10518.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7800 = _7794;
                    }
                    _4834 = _7800;
                }
                else
                {
                    _4834 = _4829;
                }
                float4 _10822;
                if (_4834)
                {
                    float _10782;
                    if (_10759 >= 0.0f)
                    {
                        _10782 = _10759 - _4771;
                    }
                    else
                    {
                        float _10778;
                        _10778 = 2.0f;
                        float _7857;
                        for (int _10777 = 0; _10777 < 24; _10778 = _7857, _10777++)
                        {
                            float _7821 = float(_10777 & 7) * 0.785398185253143310546875f;
                            int _7823 = _10777 >> 3;
                            int _10779;
                            if (_7823 == 0)
                            {
                                _10779 = 16;
                            }
                            else
                            {
                                _10779 = (_7823 == 1) ? 48 : 96;
                            }
                            uint _7889_dummy_parameter;
                            _7857 = min(_10778, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10518 + ((cbFI_MvDepthLaneSizeRcp * float(_10779)) * float2(cos(_7821), sin(_7821))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7889_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10782 = _10778;
                    }
                    uint _7921_dummy_parameter;
                    float4 _10823;
                    if (r_depth_tp1.Load(int3(int2(floor(_10518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7921_dummy_parameter))))), 0)).x > ((exp((_10782 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10823 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10823 = 1.0f.xxxx;
                    }
                    _10822 = _10823;
                }
                else
                {
                    _10822 = 1.0f.xxxx;
                }
                _10821 = _10822;
            }
            bool _4860 = _10759 >= 0.0f;
            bool _4867;
            if (_4860)
            {
                _4867 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4867 = _4860;
            }
            bool _4873;
            if (_4867)
            {
                _4873 = _10764.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4873 = _4867;
            }
            bool _4878;
            if (_4873)
            {
                bool _7945 = all(bool2(_10516.x > 0.0f.xx.x, _10516.y > 0.0f.xx.y));
                bool _7951;
                if (_7945)
                {
                    _7951 = all(bool2(_10516.x < 1.0f.xx.x, _10516.y < 1.0f.xx.y));
                }
                else
                {
                    _7951 = _7945;
                }
                _4878 = _7951;
            }
            else
            {
                _4878 = _4873;
            }
            float4 _10838;
            if (_4878)
            {
                float _10815;
                if (_4860)
                {
                    _10815 = _10759 - _4771;
                }
                else
                {
                    float _10811;
                    _10811 = 2.0f;
                    float _8008;
                    for (int _10810 = 0; _10810 < 24; _10811 = _8008, _10810++)
                    {
                        float _7972 = float(_10810 & 7) * 0.785398185253143310546875f;
                        int _7974 = _10810 >> 3;
                        int _10812;
                        if (_7974 == 0)
                        {
                            _10812 = 16;
                        }
                        else
                        {
                            _10812 = (_7974 == 1) ? 48 : 96;
                        }
                        uint _8024_dummy_parameter;
                        _8008 = min(_10811, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10516 + ((cbFI_MvDepthLaneSizeRcp * float(_10812)) * float2(cos(_7972), sin(_7972))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8024_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10815 = _10811;
                }
                uint _8072_dummy_parameter;
                float4 _10839;
                if (r_depth_tm1.Load(int3(int2(floor(_10516 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8072_dummy_parameter))))), 0)).x > ((exp((_10815 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10356 = _10821;
                    _10356.x = 0.0f;
                    _10839 = _10356;
                }
                else
                {
                    _10839 = _10821;
                }
                _10838 = _10839;
            }
            else
            {
                _10838 = _10821;
            }
            float4 _10851;
            if (_4860)
            {
                float _8098 = (exp(((_10759 - _4771) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _4913 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4919;
                if (_4913)
                {
                    _4919 = _10764.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4919 = _4913;
                }
                bool _4924;
                if (_4919)
                {
                    bool _8103 = all(bool2(_10520.x > 0.0f.xx.x, _10520.y > 0.0f.xx.y));
                    bool _8109;
                    if (_8103)
                    {
                        _8109 = all(bool2(_10520.x < 1.0f.xx.x, _10520.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8109 = _8103;
                    }
                    _4924 = _8109;
                }
                else
                {
                    _4924 = _4919;
                }
                bool _4932;
                if (_4924)
                {
                    uint _8116_dummy_parameter;
                    _4932 = r_depth_tp1.Load(int3(int2(floor(_10520 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8116_dummy_parameter))))), 0)).x > _8098;
                }
                else
                {
                    _4932 = _4924;
                }
                float4 _10849;
                if (_4932)
                {
                    float4 _10359 = _10838;
                    _10359.w = 0.0f;
                    _10849 = _10359;
                }
                else
                {
                    _10849 = _10838;
                }
                bool _4939 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4945;
                if (_4939)
                {
                    _4945 = _10764.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4945 = _4939;
                }
                bool _4950;
                if (_4945)
                {
                    bool _8133 = all(bool2(_10519.x > 0.0f.xx.x, _10519.y > 0.0f.xx.y));
                    bool _8139;
                    if (_8133)
                    {
                        _8139 = all(bool2(_10519.x < 1.0f.xx.x, _10519.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8139 = _8133;
                    }
                    _4950 = _8139;
                }
                else
                {
                    _4950 = _4945;
                }
                bool _4958;
                if (_4950)
                {
                    uint _8146_dummy_parameter;
                    _4958 = r_depth_tm1.Load(int3(int2(floor(_10519 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8146_dummy_parameter))))), 0)).x > _8098;
                }
                else
                {
                    _4958 = _4950;
                }
                float4 _10852;
                if (_4958)
                {
                    float4 _10362 = _10849;
                    _10362.z = 0.0f;
                    _10852 = _10362;
                }
                else
                {
                    _10852 = _10849;
                }
                _10851 = _10852;
            }
            else
            {
                _10851 = _10838;
            }
            float4 _10922;
            if (any(bool4(_10851.x < 1.0f.xxxx.x, _10851.y < 1.0f.xxxx.y, _10851.z < 1.0f.xxxx.z, _10851.w < 1.0f.xxxx.w)))
            {
                float4 _4969 = _10764 * _10851;
                float _4971 = dot(_4969, 1.0f.xxxx);
                float4 _10923;
                if (_4971 > 0.0f)
                {
                    _10923 = _4969 / _4971.xxxx;
                }
                else
                {
                    bool _4982 = _10851.y == 0.0f;
                    bool _4988;
                    if (_4982)
                    {
                        _4988 = _10851.x > 0.0f;
                    }
                    else
                    {
                        _4988 = _4982;
                    }
                    bool _4993;
                    if (_4988)
                    {
                        bool _8163 = all(bool2(_10516.x > 0.0f.xx.x, _10516.y > 0.0f.xx.y));
                        bool _8169;
                        if (_8163)
                        {
                            _8169 = all(bool2(_10516.x < 1.0f.xx.x, _10516.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8169 = _8163;
                        }
                        _4993 = _8169;
                    }
                    else
                    {
                        _4993 = _4988;
                    }
                    float4 _10924;
                    if (_4993)
                    {
                        _10924 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4998 = _10851.x == 0.0f;
                        bool _5004;
                        if (_4998)
                        {
                            _5004 = _10851.y > 0.0f;
                        }
                        else
                        {
                            _5004 = _4998;
                        }
                        bool _5009;
                        if (_5004)
                        {
                            bool _8174 = all(bool2(_10518.x > 0.0f.xx.x, _10518.y > 0.0f.xx.y));
                            bool _8180;
                            if (_8174)
                            {
                                _8180 = all(bool2(_10518.x < 1.0f.xx.x, _10518.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _8180 = _8174;
                            }
                            _5009 = _8180;
                        }
                        else
                        {
                            _5009 = _5004;
                        }
                        bool4 _12640 = _5009.xxxx;
                        _10924 = float4(_12640.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10764.x, _12640.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10764.y, _12640.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10764.z, _12640.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10764.w);
                    }
                    _10923 = _10924;
                }
                _10922 = _10923;
            }
            else
            {
                _10922 = _10764;
            }
            _10921 = _10922;
        }
        else
        {
            _10921 = _10764;
        }
        float4 _11509;
        bool _11529;
        float3 _11643;
        if (((cbFI_pad0 & 32768u) != 0u) && _4728)
        {
            bool _5026 = _10921.x > 0.00999999977648258209228515625f;
            bool _5029 = _10921.y > 0.00999999977648258209228515625f;
            bool _5038 = (_10921.z + _10921.w) > 0.0199999995529651641845703125f;
            bool _5044;
            if (_5038)
            {
                bool _8185 = all(bool2(_10519.x > 0.0f.xx.x, _10519.y > 0.0f.xx.y));
                bool _8191;
                if (_8185)
                {
                    _8191 = all(bool2(_10519.x < 1.0f.xx.x, _10519.y < 1.0f.xx.y));
                }
                else
                {
                    _8191 = _8185;
                }
                _5044 = _8191;
            }
            else
            {
                _5044 = _5038;
            }
            bool _5049;
            if (_5044)
            {
                bool _8196 = all(bool2(_10520.x > 0.0f.xx.x, _10520.y > 0.0f.xx.y));
                bool _8202;
                if (_8196)
                {
                    _8202 = all(bool2(_10520.x < 1.0f.xx.x, _10520.y < 1.0f.xx.y));
                }
                else
                {
                    _8202 = _8196;
                }
                _5049 = _8202;
            }
            else
            {
                _5049 = _5044;
            }
            bool _5056;
            if (_5049)
            {
                float _10932;
                do
                {
                    bool _8285 = all(bool2(_10519.x > 0.0f.xx.x, _10519.y > 0.0f.xx.y));
                    bool _8291;
                    if (_8285)
                    {
                        _8291 = all(bool2(_10519.x < 1.0f.xx.x, _10519.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8291 = _8285;
                    }
                    bool _8222 = !_8291;
                    bool _8229;
                    if (!_8222)
                    {
                        bool _8296 = all(bool2(_10520.x > 0.0f.xx.x, _10520.y > 0.0f.xx.y));
                        bool _8302;
                        if (_8296)
                        {
                            _8302 = all(bool2(_10520.x < 1.0f.xx.x, _10520.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8302 = _8296;
                        }
                        _8229 = !_8302;
                    }
                    else
                    {
                        _8229 = _8222;
                    }
                    if (_8229)
                    {
                        _10932 = 0.0f;
                        break;
                    }
                    uint _8309_dummy_parameter;
                    uint _8325_dummy_parameter;
                    float4 _8250 = mul(float4((float2(_10519.x, 1.0f - _10519.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10519 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8309_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _8252 = _8250.w;
                    if (abs(_8252) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10932 = 0.0f;
                        break;
                    }
                    float _8263 = abs(cbFI_DeviceToViewDepth.y / ((_8250.z / _8252) - cbFI_DeviceToViewDepth.x));
                    float _8266 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10520 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8325_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10932 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8263 - _8266) / max(max(_8263, _8266), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5056 = _10932 < 0.5f;
            }
            else
            {
                _5056 = _5049;
            }
            float4 _10947;
            if (_5056)
            {
                uint _8375_dummy_parameter;
                uint _8406_dummy_parameter;
                float4 _10948;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10519 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8375_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10520 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8406_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10948 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10948 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10947 = _10948;
            }
            else
            {
                _10947 = 1.0f.xxxx;
            }
            bool _5080;
            if (_7156)
            {
                bool _8435 = all(bool2(_10516.x > 0.0f.xx.x, _10516.y > 0.0f.xx.y));
                bool _8441;
                if (_8435)
                {
                    _8441 = all(bool2(_10516.x < 1.0f.xx.x, _10516.y < 1.0f.xx.y));
                }
                else
                {
                    _8441 = _8435;
                }
                _5080 = _8441;
            }
            else
            {
                _5080 = _7156;
            }
            bool _5086;
            if (_7156)
            {
                bool _8446 = all(bool2(_10518.x > 0.0f.xx.x, _10518.y > 0.0f.xx.y));
                bool _8452;
                if (_8446)
                {
                    _8452 = all(bool2(_10518.x < 1.0f.xx.x, _10518.y < 1.0f.xx.y));
                }
                else
                {
                    _8452 = _8446;
                }
                _5086 = _8452;
            }
            else
            {
                _5086 = _7156;
            }
            bool _5092;
            if (_7188)
            {
                bool _8457 = all(bool2(_10519.x > 0.0f.xx.x, _10519.y > 0.0f.xx.y));
                bool _8463;
                if (_8457)
                {
                    _8463 = all(bool2(_10519.x < 1.0f.xx.x, _10519.y < 1.0f.xx.y));
                }
                else
                {
                    _8463 = _8457;
                }
                _5092 = _8463;
            }
            else
            {
                _5092 = _7188;
            }
            bool _5098;
            if (_7188)
            {
                bool _8468 = all(bool2(_10520.x > 0.0f.xx.x, _10520.y > 0.0f.xx.y));
                bool _8474;
                if (_8468)
                {
                    _8474 = all(bool2(_10520.x < 1.0f.xx.x, _10520.y < 1.0f.xx.y));
                }
                else
                {
                    _8474 = _8468;
                }
                _5098 = _8474;
            }
            else
            {
                _5098 = _7188;
            }
            bool _5101 = _5092 != _5098;
            bool _5107;
            if (_5101)
            {
                _5107 = _5080 || _5086;
            }
            else
            {
                _5107 = _5101;
            }
            float4 _11056;
            if (_5107)
            {
                float4 _10389 = _10947;
                _10389.z = 0.0f;
                _10389.w = 0.0f;
                _11056 = _10389;
            }
            else
            {
                _11056 = _10947;
            }
            bool _5114 = _5080 && _5026;
            bool _5117 = _5086 && _5029;
            float4 _11161;
            float3 _11743;
            if (_5114 || _5117)
            {
                float _11051;
                do
                {
                    uint4 _8613 = r_warped_motion_qdata_tp1.Load(int3(_10546, 0));
                    uint _8614 = _8613.x;
                    if (_8614 != 0u)
                    {
                        float _11050;
                        if (_8614 == 0u)
                        {
                            _11050 = -1.0f;
                        }
                        else
                        {
                            _11050 = float((_8614 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11051 = _11050;
                        break;
                    }
                    int _11033;
                    uint _11034;
                    _11034 = _8614;
                    _11033 = -1;
                    uint _11049;
                    for (; _11033 <= 1; _11034 = _11049, _11033++)
                    {
                        _11049 = _11034;
                        for (int _11047 = -1; _11047 <= 1; )
                        {
                            _11049 = max(_11049, r_warped_motion_qdata_tp1.Load(int3(clamp(_10546 + int2(_11047, _11033), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11047++;
                            continue;
                        }
                    }
                    if (_11034 != 0u)
                    {
                        float _11046;
                        if (_11034 == 0u)
                        {
                            _11046 = -1.0f;
                        }
                        else
                        {
                            _11046 = float((_11034 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11051 = _11046;
                        break;
                    }
                    uint _11036;
                    _11036 = 4294967295u;
                    uint _12610;
                    for (int _11035 = 0; _11035 < 8; _11036 = _12610, _11035++)
                    {
                        int _11039 = 0;
                        for (;;)
                        {
                            if (_11039 < 5)
                            {
                                int2 _8564 = _10546 + (_1093[_11035] * _1102[_11039].xx);
                                bool _8567 = any(bool2(_8564.x < int2(0, 0).x, _8564.y < int2(0, 0).y));
                                bool _8575;
                                if (!_8567)
                                {
                                    _8575 = any(bool2(_8564.x >= cbFI_MvDepthLaneSize.x, _8564.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8575 = _8567;
                                }
                                if (_8575)
                                {
                                    _12610 = _11036;
                                    break;
                                }
                                uint4 _8653 = r_warped_motion_qdata_tp1.Load(int3(_8564, 0));
                                uint _8654 = _8653.x;
                                if (_8654 != 0u)
                                {
                                    _12610 = min(_11036, _8654);
                                    break;
                                }
                                _11039++;
                                continue;
                            }
                            else
                            {
                                _12610 = _11036;
                                break;
                            }
                        }
                    }
                    float _11038;
                    if (_11036 == 4294967295u)
                    {
                        _11038 = -1.0f;
                    }
                    else
                    {
                        float _11037;
                        if (_11036 == 0u)
                        {
                            _11037 = -1.0f;
                        }
                        else
                        {
                            _11037 = float((_11036 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11038 = _11037;
                    }
                    _11051 = _11038;
                    break;
                } while(false);
                bool _5125 = _11051 < 0.0f;
                float _11052;
                if (_5125)
                {
                    _11052 = 0.0f;
                }
                else
                {
                    _11052 = _11051 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8675_dummy_parameter;
                uint _8707_dummy_parameter;
                float4 _11089;
                if ((_5125 && _5114) && _5117)
                {
                    uint _8739_dummy_parameter;
                    float _8763 = log((r_depth_tm1.Load(int3(int2(floor(_10516 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8739_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8771_dummy_parameter;
                    float _8795 = log((r_depth_tp1.Load(int3(int2(floor(_10518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8771_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _11090;
                    if (_8763 > (_8795 + 0.07999999821186065673828125f))
                    {
                        float4 _10393 = _11056;
                        _10393.x = 0.0f;
                        _11090 = _10393;
                    }
                    else
                    {
                        float4 _11091;
                        if (_8795 > (_8763 + 0.07999999821186065673828125f))
                        {
                            float4 _10395 = _11056;
                            _10395.y = 0.0f;
                            _11091 = _10395;
                        }
                        else
                        {
                            _11091 = _11056;
                        }
                        _11090 = _11091;
                    }
                    _11089 = _11090;
                }
                else
                {
                    _11089 = _11056;
                }
                float _5177 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5179 = _11051 >= 0.0f;
                float _11072;
                if (_5179)
                {
                    _11072 = _11051 - _5177;
                }
                else
                {
                    float _11068;
                    if (_5114)
                    {
                        float _11067;
                        _11067 = 2.0f;
                        float _8853;
                        for (int _11066 = 0; _11066 < 24; _11067 = _8853, _11066++)
                        {
                            float _8817 = float(_11066 & 7) * 0.785398185253143310546875f;
                            int _8819 = _11066 >> 3;
                            int _11069;
                            if (_8819 == 0)
                            {
                                _11069 = 16;
                            }
                            else
                            {
                                _11069 = (_8819 == 1) ? 48 : 96;
                            }
                            uint _8869_dummy_parameter;
                            _8853 = min(_11067, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10516 + ((cbFI_MvDepthLaneSizeRcp * float(_11069)) * float2(cos(_8817), sin(_8817))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8869_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11068 = _11067;
                    }
                    else
                    {
                        _11068 = 0.0f;
                    }
                    _11072 = _11068;
                }
                float _11079;
                if (_5179)
                {
                    _11079 = _11051 - _5177;
                }
                else
                {
                    float _11075;
                    if (_5117)
                    {
                        float _11074;
                        _11074 = 2.0f;
                        float _8967;
                        for (int _11073 = 0; _11073 < 24; _11074 = _8967, _11073++)
                        {
                            float _8931 = float(_11073 & 7) * 0.785398185253143310546875f;
                            int _8933 = _11073 >> 3;
                            int _11076;
                            if (_8933 == 0)
                            {
                                _11076 = 16;
                            }
                            else
                            {
                                _11076 = (_8933 == 1) ? 48 : 96;
                            }
                            uint _8999_dummy_parameter;
                            _8967 = min(_11074, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10518 + ((cbFI_MvDepthLaneSizeRcp * float(_11076)) * float2(cos(_8931), sin(_8931))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8999_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11075 = _11074;
                    }
                    else
                    {
                        _11075 = 0.0f;
                    }
                    _11079 = _11075;
                }
                float _11080;
                if (_5114)
                {
                    uint _9031_dummy_parameter;
                    _11080 = r_depth_tm1.Load(int3(int2(floor(_10516 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9031_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11080 = 0.0f;
                }
                float _11081;
                if (_5117)
                {
                    uint _9050_dummy_parameter;
                    _11081 = r_depth_tp1.Load(int3(int2(floor(_10518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9050_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11081 = 0.0f;
                }
                bool _5234;
                if (_5114)
                {
                    _5234 = _11080 > ((exp((_11072 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5234 = _5114;
                }
                float4 _11097;
                if (_5234)
                {
                    float4 _10397 = _11089;
                    _10397.x = 0.0f;
                    _11097 = _10397;
                }
                else
                {
                    _11097 = _11089;
                }
                bool _5246;
                if (_5117)
                {
                    _5246 = _11081 > ((exp((_11079 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5246 = _5117;
                }
                float4 _11099;
                if (_5246)
                {
                    float4 _10399 = _11097;
                    _10399.y = 0.0f;
                    _11099 = _10399;
                }
                else
                {
                    _11099 = _11097;
                }
                float4 _11162;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5179)
                {
                    bool _5266;
                    if (_5114)
                    {
                        _5266 = _11080 < ((exp((_11072 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5266 = _5114;
                    }
                    float4 _11101;
                    if (_5266)
                    {
                        float4 _10401 = _11099;
                        _10401.x = 0.0f;
                        _11101 = _10401;
                    }
                    else
                    {
                        _11101 = _11099;
                    }
                    bool _5278;
                    if (_5117)
                    {
                        _5278 = _11081 < ((exp((_11079 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5278 = _5117;
                    }
                    float4 _11163;
                    if (_5278)
                    {
                        float4 _10403 = _11101;
                        _10403.y = 0.0f;
                        _11163 = _10403;
                    }
                    else
                    {
                        _11163 = _11101;
                    }
                    _11162 = _11163;
                }
                else
                {
                    _11162 = _11099;
                }
                _11743 = float3(_11052, log((r_depth_tm1.Load(int3(int2(floor(_10516 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8675_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_10518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8707_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _11161 = _11162;
            }
            else
            {
                _11743 = float3(0.0f, 0.0f, 0.5f);
                _11161 = _11056;
            }
            bool _5289 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5038;
            bool _5295;
            if (_5289)
            {
                _5295 = _5092 || _5098;
            }
            else
            {
                _5295 = _5289;
            }
            float4 _11184;
            if (_5295)
            {
                float _11156;
                do
                {
                    uint4 _9229 = r_warped_motion_qdata_tp1.Load(int3(_10546, 0));
                    uint _9230 = _9229.x;
                    if (_9230 != 0u)
                    {
                        float _11155;
                        if (_9230 == 0u)
                        {
                            _11155 = -1.0f;
                        }
                        else
                        {
                            _11155 = float((_9230 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11156 = _11155;
                        break;
                    }
                    int _11138;
                    uint _11139;
                    _11139 = _9230;
                    _11138 = -1;
                    uint _11154;
                    for (; _11138 <= 1; _11139 = _11154, _11138++)
                    {
                        _11154 = _11139;
                        for (int _11152 = -1; _11152 <= 1; )
                        {
                            _11154 = max(_11154, r_warped_motion_qdata_tp1.Load(int3(clamp(_10546 + int2(_11152, _11138), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11152++;
                            continue;
                        }
                    }
                    if (_11139 != 0u)
                    {
                        float _11151;
                        if (_11139 == 0u)
                        {
                            _11151 = -1.0f;
                        }
                        else
                        {
                            _11151 = float((_11139 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11156 = _11151;
                        break;
                    }
                    uint _11141;
                    _11141 = 4294967295u;
                    uint _12611;
                    for (int _11140 = 0; _11140 < 8; _11141 = _12611, _11140++)
                    {
                        int _11144 = 0;
                        for (;;)
                        {
                            if (_11144 < 5)
                            {
                                int2 _9180 = _10546 + (_1093[_11140] * _1102[_11144].xx);
                                bool _9183 = any(bool2(_9180.x < int2(0, 0).x, _9180.y < int2(0, 0).y));
                                bool _9191;
                                if (!_9183)
                                {
                                    _9191 = any(bool2(_9180.x >= cbFI_MvDepthLaneSize.x, _9180.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _9191 = _9183;
                                }
                                if (_9191)
                                {
                                    _12611 = _11141;
                                    break;
                                }
                                uint4 _9269 = r_warped_motion_qdata_tp1.Load(int3(_9180, 0));
                                uint _9270 = _9269.x;
                                if (_9270 != 0u)
                                {
                                    _12611 = min(_11141, _9270);
                                    break;
                                }
                                _11144++;
                                continue;
                            }
                            else
                            {
                                _12611 = _11141;
                                break;
                            }
                        }
                    }
                    float _11143;
                    if (_11141 == 4294967295u)
                    {
                        _11143 = -1.0f;
                    }
                    else
                    {
                        float _11142;
                        if (_11141 == 0u)
                        {
                            _11142 = -1.0f;
                        }
                        else
                        {
                            _11142 = float((_11141 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11143 = _11142;
                    }
                    _11156 = _11143;
                    break;
                } while(false);
                float4 _11185;
                if (_11156 >= 0.0f)
                {
                    float _9291 = (exp((_11156 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5314;
                    if (_5092)
                    {
                        uint _9298_dummy_parameter;
                        _5314 = r_depth_tm1.Load(int3(int2(floor(_10519 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9298_dummy_parameter))))), 0)).x > _9291;
                    }
                    else
                    {
                        _5314 = _5092;
                    }
                    float4 _11174;
                    if (_5314)
                    {
                        float4 _10405 = _11161;
                        _10405.z = 0.0f;
                        _11174 = _10405;
                    }
                    else
                    {
                        _11174 = _11161;
                    }
                    bool _5326;
                    if (_5098)
                    {
                        uint _9317_dummy_parameter;
                        _5326 = r_depth_tp1.Load(int3(int2(floor(_10520 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9317_dummy_parameter))))), 0)).x > _9291;
                    }
                    else
                    {
                        _5326 = _5098;
                    }
                    float4 _11186;
                    if (_5326)
                    {
                        float4 _10407 = _11174;
                        _10407.w = 0.0f;
                        _11186 = _10407;
                    }
                    else
                    {
                        _11186 = _11174;
                    }
                    _11185 = _11186;
                }
                else
                {
                    _11185 = _11161;
                }
                _11184 = _11185;
            }
            else
            {
                _11184 = _11161;
            }
            bool _5334 = _5080 != _5086;
            bool _5341;
            if (_5334)
            {
                _5341 = _5080 ? _5026 : _5029;
            }
            else
            {
                _5341 = _5334;
            }
            bool _5348;
            if (_5341)
            {
                _5348 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5348 = _5341;
            }
            float4 _11269;
            if (_5348)
            {
                bool2 _5353 = _5080.xx;
                float2 _5354 = float2(_5353.x ? _10516.x : _10518.x, _5353.y ? _10516.y : _10518.y);
                float _11176;
                if (_5080)
                {
                    uint _9336_dummy_parameter;
                    _11176 = r_depth_tm1.Load(int3(int2(floor(_5354 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9336_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9352_dummy_parameter;
                    _11176 = r_depth_tp1.Load(int3(int2(floor(_5354 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9352_dummy_parameter))))), 0)).x;
                }
                float4x4 _11177;
                if (_5080)
                {
                    _11177 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _11177 = cbFI_MotionTP1ToTM1;
                }
                float2 _11178;
                do
                {
                    float _9379 = _5354.x;
                    float _9382 = 1.0f - _5354.y;
                    float4 _9393 = mul(float4((float2(_9379, _9382) * 2.0f) - 1.0f.xx, _11176, 1.0f), _11177);
                    float _9395 = _9393.w;
                    if (!(_9395 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11178 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9408 = ((_9393.xy / _9395.xx) + 1.0f.xx) * 0.5f;
                    _11178 = float2(_9408.x - _9379, _9382 - _9408.y);
                    break;
                } while(false);
                float2 _5384 = float2(cbFI_DisplaySize);
                float4 _11270;
                if (!(length(((_5354 + _11178) - float2(_5353.x ? _10518.x : _10516.x, _5353.y ? _10518.y : _10516.y)) * _5384) <= ((0.100000001490116119384765625f * length(_11178 * _5384)) + 8.0f)))
                {
                    float4 _11271;
                    if (_5080)
                    {
                        float4 _10417 = _11184;
                        _10417.x = 0.0f;
                        _11271 = _10417;
                    }
                    else
                    {
                        float4 _10419 = _11184;
                        _10419.y = 0.0f;
                        _11271 = _10419;
                    }
                    _11270 = _11271;
                }
                else
                {
                    _11270 = _11184;
                }
                _11269 = _11270;
            }
            else
            {
                _11269 = _11184;
            }
            float4 _5409 = _10921 * _11269;
            float _5411 = dot(_5409, 1.0f.xxxx);
            float4 _11510;
            bool _11530;
            if (_5411 > 0.0f)
            {
                _11530 = _10669;
                _11510 = _5409 / _5411.xxxx;
            }
            else
            {
                bool _5422 = any(bool4(_11269.x < 1.0f.xxxx.x, _11269.y < 1.0f.xxxx.y, _11269.z < 1.0f.xxxx.z, _11269.w < 1.0f.xxxx.w));
                if (_5422)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9430;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9430);
                    }
                }
                bool4 _12643 = _5422.xxxx;
                _11530 = _5422 ? true : _10669;
                _11510 = float4(_12643.x ? 0.0f.xxxx.x : _10921.x, _12643.y ? 0.0f.xxxx.y : _10921.y, _12643.z ? 0.0f.xxxx.z : _10921.z, _12643.w ? 0.0f.xxxx.w : _10921.w);
            }
            _11643 = _11743;
            _11529 = _11530;
            _11509 = _11510;
        }
        else
        {
            _11643 = float3(0.0f, 0.0f, 0.5f);
            _11529 = _10669;
            _11509 = _10921;
        }
        uint _5431 = (cbFI_pad0 >> 24u) & 31u;
        uint _5435 = (cbFI_pad0 >> 16u) & 255u;
        bool _5437 = _5431 != 0u;
        bool _5439 = _5435 == 12u;
        bool _5442 = _5435 == 13u;
        float4 _11526;
        if ((_5437 || _5439) || _5442)
        {
            float _11272;
            do
            {
                bool _9514 = all(bool2(_10519.x > 0.0f.xx.x, _10519.y > 0.0f.xx.y));
                bool _9520;
                if (_9514)
                {
                    _9520 = all(bool2(_10519.x < 1.0f.xx.x, _10519.y < 1.0f.xx.y));
                }
                else
                {
                    _9520 = _9514;
                }
                bool _9451 = !_9520;
                bool _9458;
                if (!_9451)
                {
                    bool _9525 = all(bool2(_10520.x > 0.0f.xx.x, _10520.y > 0.0f.xx.y));
                    bool _9531;
                    if (_9525)
                    {
                        _9531 = all(bool2(_10520.x < 1.0f.xx.x, _10520.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9531 = _9525;
                    }
                    _9458 = !_9531;
                }
                else
                {
                    _9458 = _9451;
                }
                if (_9458)
                {
                    _11272 = 0.0f;
                    break;
                }
                uint _9538_dummy_parameter;
                uint _9554_dummy_parameter;
                float4 _9479 = mul(float4((float2(_10519.x, 1.0f - _10519.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10519 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9538_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9481 = _9479.w;
                if (abs(_9481) < 9.9999999747524270787835121154785e-07f)
                {
                    _11272 = 0.0f;
                    break;
                }
                float _9492 = abs(cbFI_DeviceToViewDepth.y / ((_9479.z / _9481) - cbFI_DeviceToViewDepth.x));
                float _9495 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10520 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9554_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _11272 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9492 - _9495) / max(max(_9492, _9495), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9602 = all(bool2(_10520.x > 0.0f.xx.x, _10520.y > 0.0f.xx.y));
            bool _9608;
            if (_9602)
            {
                _9608 = all(bool2(_10520.x < 1.0f.xx.x, _10520.y < 1.0f.xx.y));
            }
            else
            {
                _9608 = _9602;
            }
            float _11273;
            if (_9608)
            {
                uint _9615_dummy_parameter;
                _11273 = length((_6242 + (r_motion_tp1.Load(int3(int2(floor(_10520 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9615_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _11273 = 1000000.0f;
            }
            float _11284;
            if ((_5431 & 1u) != 0u)
            {
                _11284 = _11272;
            }
            else
            {
                _11284 = 1.0f;
            }
            float _11285;
            if ((_5431 & 2u) != 0u)
            {
                _11285 = _11284 * (1.0f - smoothstep(2.0f, 8.0f, _11273));
            }
            else
            {
                _11285 = _11284;
            }
            float _11286;
            if ((_5431 & 4u) != 0u)
            {
                _11286 = _11285 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6963 - _6971) - length(_6947 - _6955))));
            }
            else
            {
                _11286 = _11285;
            }
            float _11520;
            if ((_5431 & 8u) != 0u)
            {
                _11520 = lerp(1.0f, _11286, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6947 - _6955)));
            }
            else
            {
                _11520 = _11286;
            }
            bool _5517 = (_5431 & 16u) != 0u;
            bool _5526;
            if (_5517)
            {
                _5526 = length(_10514 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5526 = _5517;
            }
            float _12645 = _5526 ? 1.0f : _11520;
            bool _5532 = _5437 && _7156;
            bool _5537;
            if (_5532)
            {
                bool _9640 = all(bool2(_10516.x > 0.0f.xx.x, _10516.y > 0.0f.xx.y));
                bool _9646;
                if (_9640)
                {
                    _9646 = all(bool2(_10516.x < 1.0f.xx.x, _10516.y < 1.0f.xx.y));
                }
                else
                {
                    _9646 = _9640;
                }
                _5537 = _9646;
            }
            else
            {
                _5537 = _5532;
            }
            bool _5542;
            if (_5537)
            {
                bool _9651 = all(bool2(_10518.x > 0.0f.xx.x, _10518.y > 0.0f.xx.y));
                bool _9657;
                if (_9651)
                {
                    _9657 = all(bool2(_10518.x < 1.0f.xx.x, _10518.y < 1.0f.xx.y));
                }
                else
                {
                    _9657 = _9651;
                }
                _5542 = _9657;
            }
            else
            {
                _5542 = _5537;
            }
            float4 _11527;
            if (_5542)
            {
                float _5548 = _11509.x + _11509.y;
                float _5557 = (_11509.z + _11509.w) * (1.0f - _12645);
                float _11523;
                if (_5548 > 9.9999997473787516355514526367188e-06f)
                {
                    _11523 = _11509.x / _5548;
                }
                else
                {
                    _11523 = _4398;
                }
                _11527 = float4(_11509.x + (_5557 * _11523), _11509.y + (_5557 * (1.0f - _11523)), _11509.zw * _12645);
            }
            else
            {
                _11527 = _11509;
            }
            _11526 = _11527;
        }
        else
        {
            _11526 = _11509;
        }
        float3 _12413;
        if (_11529)
        {
            float3 _9663 = r_current_interpolation_source.Load(int3(_3757, 0)).xyz;
            float3 _12414;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _7156)
            {
                uint _9670_dummy_parameter;
                float _11634;
                _11634 = r_depth_tm1.Load(int3(int2(floor(_10516 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9670_dummy_parameter))))), 0)).x;
                float _5669;
                for (int _11633 = 0; _11633 < 24; _11634 = _5669, _11633++)
                {
                    float _5641 = float(_11633 & 7) * 0.785398185253143310546875f;
                    int _5643 = _11633 >> 3;
                    int _12464;
                    if (_5643 == 0)
                    {
                        _12464 = 16;
                    }
                    else
                    {
                        _12464 = (_5643 == 1) ? 48 : 96;
                    }
                    uint _9690_dummy_parameter;
                    _5669 = min(_11634, r_depth_tm1.Load(int3(int2(floor(clamp(_10516 + ((cbFI_MvDepthLaneSizeRcp * float(_12464)) * float2(cos(_5641), sin(_5641))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9690_dummy_parameter))))), 0)).x);
                }
                float2 _11635;
                do
                {
                    float _9712 = 1.0f - _10516.y;
                    float4 _9723 = mul(float4((float2(_10516.x, _9712) * 2.0f) - 1.0f.xx, _11634, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9725 = _9723.w;
                    if (!(_9725 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11635 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9738 = ((_9723.xy / _9725.xx) + 1.0f.xx) * 0.5f;
                    _11635 = float2(_9738.x - _10516.x, _9712 - _9738.y);
                    break;
                } while(false);
                float2 _5680 = _10516 + _11635;
                bool _9756 = all(bool2(_5680.x > 0.0f.xx.x, _5680.y > 0.0f.xx.y));
                bool _9762;
                if (_9756)
                {
                    _9762 = all(bool2(_5680.x < 1.0f.xx.x, _5680.y < 1.0f.xx.y));
                }
                else
                {
                    _9762 = _9756;
                }
                float3 _12415;
                if (_9762)
                {
                    float _5686 = abs(cbFI_DeviceToViewDepth.y / (_11634 - cbFI_DeviceToViewDepth.x));
                    uint _9782_dummy_parameter;
                    int2 _9782 = int2(spvTextureSize(r_depth_m2, uint(0), _9782_dummy_parameter));
                    float _5690 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5680 * float2(_9782))), int2(0, 0), _9782 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12420;
                    if (abs(_5690 - _5686) <= (0.20000000298023223876953125f * max(_5690, _5686)))
                    {
                        uint _9816_dummy_parameter;
                        int2 _9816 = int2(spvTextureSize(r_colour_m2, uint(0), _9816_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9839;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9839);
                        }
                        _12420 = r_colour_m2.Load(int3(clamp(int2(floor(_5680 * float2(_9816))), int2(0, 0), _9816 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9849;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9849);
                        }
                        _12420 = _9663;
                    }
                    _12415 = _12420;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9859;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9859);
                    }
                    _12415 = _9663;
                }
                _12414 = _12415;
            }
            else
            {
                _12414 = _9663;
            }
            _12413 = _12414;
        }
        else
        {
            _12413 = (((_6947 * _11526.x) + (_6955 * _11526.y)) + (_6963 * _11526.z)) + (_6971 * _11526.w);
        }
        uint _5718 = cbFI_pad0 & 255u;
        bool _12305;
        float3 _12412;
        if (_5718 != 0u)
        {
            float3 _5723 = r_present_backbuffer.Load(int3(_3757, 0)).xyz;
            float3 _5727 = r_current_interpolation_source.Load(int3(_3757, 0)).xyz;
            float3 _5731 = abs(_5723 - _5727);
            float3 _11638;
            if (_5718 == 2u)
            {
                _11638 = (abs(_5727) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11638 = 0.000244140625f.xxx;
            }
            bool _5747 = any(bool3(_5731.x > _11638.x, _5731.y > _11638.y, _5731.z > _11638.z));
            bool3 _12646 = _5747.xxx;
            _12412 = float3(_12646.x ? _5723.x : _12413.x, _12646.y ? _5723.y : _12413.y, _12646.z ? _5723.z : _12413.z);
            _12305 = _5747;
        }
        else
        {
            _12412 = _12413;
            _12305 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9874;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9874);
        }
        float3 _12395;
        if (_5435 == 1u)
        {
            _12395 = lerp(_6947, _6955, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12396;
            if (_5435 == 2u)
            {
                _12396 = lerp(_6963, _6971, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12397;
                if (_5435 == 3u)
                {
                    _12397 = float(_12305).xxx;
                }
                else
                {
                    float3 _12398;
                    if (_5435 == 4u)
                    {
                        _12398 = float3(((_10514 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12399;
                        if (_5435 == 5u)
                        {
                            _12399 = float3(((_6242 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12400;
                            if (_5435 == 6u)
                            {
                                _12400 = float3(_11526.xy, _11526.z + _11526.w);
                            }
                            else
                            {
                                float3 _12401;
                                if (_5435 == 7u)
                                {
                                    _12401 = r_current_interpolation_source.Load(int3(_3757, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12402;
                                    if (_5435 == 8u)
                                    {
                                        _12402 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4173, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12403;
                                        if (_5439)
                                        {
                                            uint _9896_dummy_parameter;
                                            uint _9928_dummy_parameter;
                                            _12403 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4173 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9896_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4173 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9928_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12404;
                                            if (_5442)
                                            {
                                                _12404 = _6963;
                                            }
                                            else
                                            {
                                                float3 _12405;
                                                if (_5435 == 20u)
                                                {
                                                    _12405 = _6947;
                                                }
                                                else
                                                {
                                                    float3 _12406;
                                                    if (_5435 == 21u)
                                                    {
                                                        _12406 = _6955;
                                                    }
                                                    else
                                                    {
                                                        float3 _12407;
                                                        if (_5435 == 22u)
                                                        {
                                                            _12407 = _6971;
                                                        }
                                                        else
                                                        {
                                                            float3 _12408;
                                                            if (_5435 == 18u)
                                                            {
                                                                _12408 = _12052;
                                                            }
                                                            else
                                                            {
                                                                float3 _12409;
                                                                if (_5435 == 19u)
                                                                {
                                                                    _12409 = _11845;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12648 = (_5435 == 23u).xxx;
                                                                    _12409 = float3(_12648.x ? _11643.x : _12412.x, _12648.y ? _11643.y : _12412.y, _12648.z ? _11643.z : _12412.z);
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
                                            _12403 = _12404;
                                        }
                                        _12402 = _12403;
                                    }
                                    _12401 = _12402;
                                }
                                _12400 = _12401;
                            }
                            _12399 = _12400;
                        }
                        _12398 = _12399;
                    }
                    _12397 = _12398;
                }
                _12396 = _12397;
            }
            _12395 = _12396;
        }
        float3 _12394;
        if ((_5435 >= 9u) && (_5435 <= 11u))
        {
            uint _5911 = 64u + uint((_10546.y * cbFI_MvDepthLaneSize.x) + _10546.x);
            uint _5915 = rw_nfru_diagnostics.Load<uint>(_5911 * 4 + 0) & 15u;
            float3 _12425;
            if (_5435 == 10u)
            {
                float3 _12393;
                if ((rw_nfru_diagnostics.Load<uint>(_5911 * 4 + 0) & 32u) != 0u)
                {
                    _12393 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12392;
                    if ((rw_nfru_diagnostics.Load<uint>(_5911 * 4 + 0) & 16u) != 0u)
                    {
                        _12392 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5936 = ((rw_nfru_diagnostics.Load<uint>(_5911 * 4 + 0) & 64u) != 0u).xxx;
                        _12392 = float3(_5936.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5936.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5936.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12393 = _12392;
                }
                _12425 = _12393;
            }
            else
            {
                float3 _12426;
                if (_5435 == 11u)
                {
                    uint _5949 = (rw_nfru_diagnostics.Load<uint>(_5911 * 4 + 0) >> 8u) & 15u;
                    uint _5952 = (rw_nfru_diagnostics.Load<uint>(_5911 * 4 + 0) >> 12u) & 15u;
                    float3 _12385;
                    if ((_5915 == 2u) || (_5915 == 3u))
                    {
                        _12385 = _3453[_5915];
                    }
                    else
                    {
                        bool _5964 = _5949 == 3u;
                        bool _5966 = _5952 == 3u;
                        float3 _12386;
                        if (_5964 && _5966)
                        {
                            _12386 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12387;
                            if (_5964)
                            {
                                _12387 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12388;
                                if (_5966)
                                {
                                    _12388 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12389;
                                    if ((_5949 == 4u) || (_5952 == 4u))
                                    {
                                        _12389 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12390;
                                        if ((_5949 == 1u) || (_5952 == 1u))
                                        {
                                            _12390 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12650 = (_5915 == 1u).xxx;
                                            _12390 = float3(_12650.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12650.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12650.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
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
                    _12426 = _12385;
                }
                else
                {
                    _12426 = _3453[min(_5915, 7u)];
                }
                _12425 = _12426;
            }
            _12394 = _12425;
        }
        else
        {
            _12394 = _12395;
        }
        float4 _12429;
        if ((_5435 >= 14u) && (_5435 <= 16u))
        {
            float2 _12427;
            if (_5435 == 14u)
            {
                uint _6022_dummy_parameter;
                uint _6028_dummy_parameter;
                _12427 = r_flow_tm1.Load(int3(clamp(int2(floor(_4173 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6022_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6028_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12428;
                if (_5435 == 16u)
                {
                    uint _9979 = r_warped_flow_qdata_tm1.Load(int3(_4189, 0)).x & 2147483647u;
                    uint _10011 = uint(max((int((_9979 >> 16u) & 15u) - 6), 0));
                    _12428 = ((float2(float((1 - (2 * int((_9979 >> 15u) & 1u))) * int(((_9979 >> uint(7)) & 127u) << _10011)), float((1 - (2 * int((_9979 >> 14u) & 1u))) * int((_9979 & 127u) << _10011))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12428 = _6242 * float2(cbFI_DisplaySize);
                }
                _12427 = _12428;
            }
            uint2 _6061 = uint2(clamp(round(_12427 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6063 = _6061.x;
            uint _6070 = _6061.y;
            _12429 = float4(float(_6063 & 255u), float((_6063 >> 8u) | ((_6070 & 15u) << 4u)), float(_6070 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12430;
            if (_5435 == 17u)
            {
                _12430 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4189, 0)).x != 0u), _4532, 0.0f, 1.0f);
            }
            else
            {
                _12430 = float4(_12394, 1.0f);
            }
            _12429 = _12430;
        }
        rw_output[_3757] = _12429.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6114 = ((uint(_3757.y) * uint(cbFI_DisplaySize.x)) + uint(_3757.x)) * 6u;
            uint _10057 = spvPackHalf2x16(clamp(_6946.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6114 * 4 + 0, (((_10057 & 32767u) >> 4u) | ((((_10057 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6946.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10092 = spvPackHalf2x16(clamp(_6954.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6114 + 1u) * 4 + 0, (((_10092 & 32767u) >> 4u) | ((((_10092 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6954.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10127 = spvPackHalf2x16(clamp(_6962.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6114 + 2u) * 4 + 0, (((_10127 & 32767u) >> 4u) | ((((_10127 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6962.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10162 = spvPackHalf2x16(clamp(_6970.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6114 + 3u) * 4 + 0, (((_10162 & 32767u) >> 4u) | ((((_10162 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6970.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _10189 = r_current_interpolation_source.Load(int3(_3757, 0));
            uint _10203 = spvPackHalf2x16(clamp(_10189.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6114 + 4u) * 4 + 0, (((_10203 & 32767u) >> 4u) | ((((_10203 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10189.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12463;
            if (_12305 || (_5435 != 0u))
            {
                _12463 = 4294967295u;
            }
            else
            {
                uint _10238 = spvPackHalf2x16(clamp(_12429.xy, 0.0f.xx, 65000.0f.xx));
                _12463 = (((_10238 & 32767u) >> 4u) | ((((_10238 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12429.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6114 + 5u) * 4 + 0, _12463);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3757] = float4(r_current_interpolation_source.Load(int3(_3757, 0)).xyz, 1.0f).xyz;
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
