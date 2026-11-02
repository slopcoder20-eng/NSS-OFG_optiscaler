static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3466[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3770 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3770.x >= cbFI_DisplaySize.x, _3770.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3770] = float4(r_present_backbuffer.Load(int3(_3770, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3770] = float4(r_current_interpolation_source.Load(int3(_3770, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4189 = (float2(_3770) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4200 = int2(floor(_4189 * float2(cbFI_MvDepthLaneSize)));
        int2 _4205 = int2(floor(_4189 * float2(cbFI_FlowLaneSize)));
        float4 _6262 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4189 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6268 = r_warped_filled_flow_tm1.Load(int3(_4205, 0)).xy;
        float2 _6274 = r_warped_filled_motion_tp1.Load(int3(_4200, 0)).xy;
        bool _6296 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10521;
        if (_6296)
        {
            float _6309 = ((2.0f * _4189.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10521 = float2(atan(_6309) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4189.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6309 * _6309))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10521 = _4189;
        }
        bool _4226 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10542;
        bool _10563;
        int2 _10574;
        float3 _12114;
        if (_4226)
        {
            float _10523;
            float _10525;
            _10525 = 2.0f;
            _10523 = -1.0f;
            uint _3834[9];
            float _12568;
            float _12571;
            for (int _10522 = 0; _10522 < 9; _10525 = _12571, _10523 = _12568, _10522++)
            {
                _3834[_10522] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4200 + int2((_10522 % 3) - 1, (_10522 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3834[_10522] != 0u)
                {
                    float _12563;
                    if (_3834[_10522] == 0u)
                    {
                        _12563 = -1.0f;
                    }
                    else
                    {
                        _12563 = float((_3834[_10522] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12571 = min(_10525, _12563);
                    _12568 = max(_10523, _12563);
                }
                else
                {
                    _12571 = _10525;
                    _12568 = _10523;
                }
            }
            float _4272 = float(_10523 >= 0.0f);
            float3 _10312 = 0.0f.xxx;
            _10312.y = _4272;
            float2 _10543;
            bool _10564;
            int2 _10575;
            float3 _12115;
            if ((_10523 - _10525) > 0.0199999995529651641845703125f)
            {
                float _10531;
                int2 _10532;
                float2 _10533;
                int2 _10535;
                float2 _10541;
                _10541 = _6274;
                _10535 = _4200;
                _10533 = _6274;
                _10532 = _4200;
                _10531 = -1.0f;
                float _12576;
                int2 _12580;
                float2 _12591;
                int2 _12602;
                float2 _12635;
                float _12682;
                int _10530 = 0;
                float _12544 = 1000000000.0f;
                for (; _10530 < 9; _12544 = _12682, _10541 = _12635, _10535 = _12602, _10533 = _12591, _10532 = _12580, _10531 = _12576, _10530++)
                {
                    if (_3834[_10530] == 0u)
                    {
                        _12682 = _12544;
                        _12635 = _10541;
                        _12602 = _10535;
                        _12591 = _10533;
                        _12580 = _10532;
                        _12576 = _10531;
                        continue;
                    }
                    int2 _4307 = clamp(_4200 + int2((_10530 % 3) - 1, (_10530 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6384 = _3834[_10530] & 2147483647u;
                    uint _6416 = uint(max((int((_6384 >> 16u) & 15u) - 6), 0));
                    float2 _4313 = (float2(float((1 - (2 * int((_6384 >> 15u) & 1u))) * int(((_6384 >> uint(7)) & 127u) << _6416)), float((1 - (2 * int((_6384 >> 14u) & 1u))) * int((_6384 & 127u) << _6416))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12530;
                    if (_3834[_10530] == 0u)
                    {
                        _12530 = -1.0f;
                    }
                    else
                    {
                        _12530 = float((_3834[_10530] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4318 = _12530 - 0.100000001490116119384765625f;
                    float2 _12531;
                    if (_6296)
                    {
                        float2 _6493 = clamp((((_10521 + (_4313 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6496 = tan(_6493.x);
                        _12531 = (float2(_6496 / cbFI_DeviceToViewDepth.z, (tan(_6493.y) * sqrt(1.0f + (_6496 * _6496))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12531 = _10521 + (_4313 * cbFI_Timestep);
                    }
                    float _4325 = cbFI_Timestep - 1.0f;
                    float2 _12532;
                    if (_6296)
                    {
                        float2 _6564 = clamp((((_10521 + (_4313 * _4325)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6567 = tan(_6564.x);
                        _12532 = (float2(_6567 / cbFI_DeviceToViewDepth.z, (tan(_6564.y) * sqrt(1.0f + (_6567 * _6567))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12532 = _10521 + (_4313 * _4325);
                    }
                    bool _6600 = all(bool2(_12531.x > 0.0f.xx.x, _12531.y > 0.0f.xx.y));
                    bool _6606;
                    if (_6600)
                    {
                        _6606 = all(bool2(_12531.x < 1.0f.xx.x, _12531.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6606 = _6600;
                    }
                    float _12535;
                    if (_6606)
                    {
                        uint _6613_dummy_parameter;
                        _12535 = max((_4318 - (log((r_depth_tm1.Load(int3(int2(floor(_12531 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6613_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12535 = 0.0f;
                    }
                    bool _6643 = all(bool2(_12532.x > 0.0f.xx.x, _12532.y > 0.0f.xx.y));
                    bool _6649;
                    if (_6643)
                    {
                        _6649 = all(bool2(_12532.x < 1.0f.xx.x, _12532.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6649 = _6643;
                    }
                    float _12536;
                    if (_6649)
                    {
                        uint _6656_dummy_parameter;
                        _12536 = _12535 + max((_4318 - (log((r_depth_tp1.Load(int3(int2(floor(_12532 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6656_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12536 = _12535;
                    }
                    float _12577;
                    int2 _12581;
                    float2 _12592;
                    int2 _12603;
                    float2 _12636;
                    float _12683;
                    if (_12536 == 0.0f)
                    {
                        bool _4360 = _4318 > _10531;
                        bool2 _12691 = _4360.xx;
                        _12683 = _12544;
                        _12636 = float2(_12691.x ? _4313.x : _10541.x, _12691.y ? _4313.y : _10541.y);
                        _12603 = int2(_12691.x ? _4307.x : _10535.x, _12691.y ? _4307.y : _10535.y);
                        _12592 = _10533;
                        _12581 = _10532;
                        _12577 = _4360 ? _4318 : _10531;
                    }
                    else
                    {
                        bool _4369 = _12536 < _12544;
                        bool2 _12687 = _4369.xx;
                        _12683 = _4369 ? _12536 : _12544;
                        _12636 = _10541;
                        _12603 = _10535;
                        _12592 = float2(_12687.x ? _4313.x : _10533.x, _12687.y ? _4313.y : _10533.y);
                        _12581 = int2(_12687.x ? _4307.x : _10532.x, _12687.y ? _4307.y : _10532.y);
                        _12577 = _10531;
                    }
                    _12682 = _12683;
                    _12635 = _12636;
                    _12602 = _12603;
                    _12591 = _12592;
                    _12580 = _12581;
                    _12576 = _12577;
                }
                bool _4381 = _10531 < 0.0f;
                bool2 _12697 = _4381.xx;
                int2 _12700 = int2(_12697.x ? _10532.x : _10535.x, _12697.y ? _10532.y : _10535.y);
                _12115 = float3(1.0f, _4272, float(any(bool2(_12700.x != _4200.x, _12700.y != _4200.y))));
                _10575 = _12700;
                _10564 = _4381 ? false : true;
                _10543 = float2(_12697.x ? _10533.x : _10541.x, _12697.y ? _10533.y : _10541.y);
            }
            else
            {
                _12115 = _10312;
                _10575 = _4200;
                _10564 = false;
                _10543 = _6274;
            }
            _12114 = _12115;
            _10574 = _10575;
            _10563 = _10564;
            _10542 = _10543;
        }
        else
        {
            _12114 = 0.0f.xxx;
            _10574 = _4200;
            _10563 = false;
            _10542 = _6274;
        }
        float2 _10544;
        if (_6296)
        {
            float2 _6721 = clamp((((_10521 + (_10542 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6724 = tan(_6721.x);
            _10544 = (float2(_6724 / cbFI_DeviceToViewDepth.z, (tan(_6721.y) * sqrt(1.0f + (_6724 * _6724))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10544 = _10521 + (_10542 * cbFI_Timestep);
        }
        float _4404 = cbFI_Timestep - 1.0f;
        float2 _10546;
        if (_6296)
        {
            float2 _6792 = clamp((((_10521 + (_10542 * _4404)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6795 = tan(_6792.x);
            _10546 = (float2(_6795 / cbFI_DeviceToViewDepth.z, (tan(_6792.y) * sqrt(1.0f + (_6795 * _6795))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10546 = _10521 + (_10542 * _4404);
        }
        float _4409 = -cbFI_Timestep;
        float2 _10547;
        if (_6296)
        {
            float2 _6863 = clamp((((_10521 + (_6268 * _4409)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6866 = tan(_6863.x);
            _10547 = (float2(_6866 / cbFI_DeviceToViewDepth.z, (tan(_6863.y) * sqrt(1.0f + (_6866 * _6866))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10547 = _10521 + (_6268 * _4409);
        }
        float _4414 = 1.0f - cbFI_Timestep;
        float2 _10548;
        if (_6296)
        {
            float2 _6934 = clamp((((_10521 + (_6268 * _4414)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6937 = tan(_6934.x);
            _10548 = (float2(_6937 / cbFI_DeviceToViewDepth.z, (tan(_6934.y) * sqrt(1.0f + (_6937 * _6937))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10548 = _10521 + (_6268 * _4414);
        }
        float4 _6972 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10544, 0.0f);
        float3 _6973 = _6972.xyz;
        float4 _6980 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10546, 0.0f);
        float3 _6981 = _6980.xyz;
        float4 _6988 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10547, 0.0f);
        float3 _6989 = _6988.xyz;
        float4 _6996 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10548, 0.0f);
        float3 _6997 = _6996.xyz;
        float4 _7011 = exp(_6262 - max(max(max(_6262.x, _6262.y), _6262.z), _6262.w).xxxx);
        float4 _7018 = _7011 / (dot(_7011, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4433 = _4226 && (!_10563);
        bool _4442;
        if (_4433)
        {
            _4442 = (_7018.z + _7018.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4442 = _4433;
        }
        bool _4453;
        if (_4442)
        {
            _4453 = length((_10547 - _10544) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4453 = _4442;
        }
        bool _10587;
        if (_4453)
        {
            uint4 _7037 = r_warped_motion_qdata_tp1.Load(int3(_10574, 0));
            uint _7038 = _7037.x;
            bool _10590;
            if (_7038 != 0u)
            {
                float _10576;
                if (_7038 == 0u)
                {
                    _10576 = -1.0f;
                }
                else
                {
                    _10576 = float((_7038 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4463 = _10576 - 0.12000000476837158203125f;
                bool _7057 = all(bool2(_10547.x > 0.0f.xx.x, _10547.y > 0.0f.xx.y));
                bool _7063;
                if (_7057)
                {
                    _7063 = all(bool2(_10547.x < 1.0f.xx.x, _10547.y < 1.0f.xx.y));
                }
                else
                {
                    _7063 = _7057;
                }
                bool _4473;
                if (_7063)
                {
                    uint _7070_dummy_parameter;
                    _4473 = (log((r_depth_tm1.Load(int3(int2(floor(_10547 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7070_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4463;
                }
                else
                {
                    _4473 = _7063;
                }
                bool _4487;
                if (!_4473)
                {
                    bool _7100 = all(bool2(_10548.x > 0.0f.xx.x, _10548.y > 0.0f.xx.y));
                    bool _7106;
                    if (_7100)
                    {
                        _7106 = all(bool2(_10548.x < 1.0f.xx.x, _10548.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7106 = _7100;
                    }
                    bool _4485;
                    if (_7106)
                    {
                        uint _7113_dummy_parameter;
                        _4485 = (log((r_depth_tp1.Load(int3(int2(floor(_10548 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7113_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4463;
                    }
                    else
                    {
                        _4485 = _7106;
                    }
                    _4487 = _4485;
                }
                else
                {
                    _4487 = _4473;
                }
                _10590 = _4487;
            }
            else
            {
                _10590 = false;
            }
            _10587 = _10590;
        }
        else
        {
            _10587 = false;
        }
        bool _4492 = _10563 || _10587;
        bool _4497;
        if (_4492)
        {
            bool _7143 = all(bool2(_10544.x > 0.0f.xx.x, _10544.y > 0.0f.xx.y));
            bool _7149;
            if (_7143)
            {
                _7149 = all(bool2(_10544.x < 1.0f.xx.x, _10544.y < 1.0f.xx.y));
            }
            else
            {
                _7149 = _7143;
            }
            _4497 = _7149;
        }
        else
        {
            _4497 = _4492;
        }
        bool _4502;
        if (_4497)
        {
            bool _7154 = all(bool2(_10546.x > 0.0f.xx.x, _10546.y > 0.0f.xx.y));
            bool _7160;
            if (_7154)
            {
                _7160 = all(bool2(_10546.x < 1.0f.xx.x, _10546.y < 1.0f.xx.y));
            }
            else
            {
                _7160 = _7154;
            }
            _4502 = _7160;
        }
        else
        {
            _4502 = _4497;
        }
        float4 _10684;
        if (_4502)
        {
            float _4505 = _7018.x;
            float _4507 = _7018.y;
            float _4508 = _4505 + _4507;
            float _4513 = _7018.z + _7018.w;
            float _10605;
            if (_4508 > 0.001000000047497451305389404296875f)
            {
                _10605 = _4505 / _4508;
            }
            else
            {
                _10605 = _4414;
            }
            _10684 = float4(_4505 + (_4513 * _10605), _4507 + (_4513 * (1.0f - _10605)), 0.0f, 0.0f);
        }
        else
        {
            _10684 = _7018;
        }
        bool _7188 = (cbFI_pad0 & 1024u) != 0u;
        bool _7164 = !_7188;
        bool _7165 = !_7164;
        bool _7182;
        if (_7165)
        {
            _7182 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10574.y * cbFI_MvDepthLaneSize.x) + _10574.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _7182 = _7164;
        }
        bool _7214;
        if (_7165)
        {
            _7214 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4205.y * cbFI_FlowLaneSize.x) + _4205.x)) * 4 + 0) != 0u;
        }
        else
        {
            _7214 = _7164;
        }
        float _4548 = float(_7214);
        bool _10697;
        float4 _10728;
        float3 _11906;
        if (_7188)
        {
            bool _4558;
            if (_7182)
            {
                _4558 = all(bool2(_10544.x > 0.0f.xx.x, _10544.y > 0.0f.xx.y));
            }
            else
            {
                _4558 = _7182;
            }
            bool _4564;
            if (_4558)
            {
                _4564 = all(bool2(_10544.x < 1.0f.xx.x, _10544.y < 1.0f.xx.y));
            }
            else
            {
                _4564 = _4558;
            }
            bool _4571;
            if (_7182)
            {
                _4571 = all(bool2(_10546.x > 0.0f.xx.x, _10546.y > 0.0f.xx.y));
            }
            else
            {
                _4571 = _7182;
            }
            bool _4577;
            if (_4571)
            {
                _4577 = all(bool2(_10546.x < 1.0f.xx.x, _10546.y < 1.0f.xx.y));
            }
            else
            {
                _4577 = _4571;
            }
            bool _4584;
            if (_7214)
            {
                _4584 = all(bool2(_10547.x > 0.0f.xx.x, _10547.y > 0.0f.xx.y));
            }
            else
            {
                _4584 = _7214;
            }
            bool _4590;
            if (_4584)
            {
                _4590 = all(bool2(_10547.x < 1.0f.xx.x, _10547.y < 1.0f.xx.y));
            }
            else
            {
                _4590 = _4584;
            }
            bool _4597;
            if (_7214)
            {
                _4597 = all(bool2(_10548.x > 0.0f.xx.x, _10548.y > 0.0f.xx.y));
            }
            else
            {
                _4597 = _7214;
            }
            bool _4603;
            if (_4597)
            {
                _4603 = all(bool2(_10548.x < 1.0f.xx.x, _10548.y < 1.0f.xx.y));
            }
            else
            {
                _4603 = _4597;
            }
            bool _4605 = !_7182;
            if (_4605)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7256;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7256);
                }
            }
            bool _4610 = !_7214;
            if (_4610)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7266;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7266);
                }
            }
            if (_7182 && _4610)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7276;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7276);
                }
            }
            if (_4605 && _7214)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7286;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7286);
                }
            }
            float _4629 = float(_4564);
            float _4631 = float(_4577);
            bool _4634 = _4590 && _4603;
            float _10639;
            if (_4634)
            {
                _10639 = 1.0f;
            }
            else
            {
                _10639 = (_4590 || _4603) ? 0.5f : 0.0f;
            }
            bool _10644;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4564)) && (!_4577))
            {
                bool _4664;
                if (_4634)
                {
                    float _10642;
                    do
                    {
                        bool _7370 = all(bool2(_10547.x > 0.0f.xx.x, _10547.y > 0.0f.xx.y));
                        bool _7376;
                        if (_7370)
                        {
                            _7376 = all(bool2(_10547.x < 1.0f.xx.x, _10547.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7376 = _7370;
                        }
                        bool _7307 = !_7376;
                        bool _7314;
                        if (!_7307)
                        {
                            bool _7381 = all(bool2(_10548.x > 0.0f.xx.x, _10548.y > 0.0f.xx.y));
                            bool _7387;
                            if (_7381)
                            {
                                _7387 = all(bool2(_10548.x < 1.0f.xx.x, _10548.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7387 = _7381;
                            }
                            _7314 = !_7387;
                        }
                        else
                        {
                            _7314 = _7307;
                        }
                        if (_7314)
                        {
                            _10642 = 0.0f;
                            break;
                        }
                        uint _7394_dummy_parameter;
                        uint _7410_dummy_parameter;
                        float4 _7335 = mul(float4((float2(_10547.x, 1.0f - _10547.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10547 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7394_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7337 = _7335.w;
                        if (abs(_7337) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10642 = 0.0f;
                            break;
                        }
                        float _7348 = abs(cbFI_DeviceToViewDepth.y / ((_7335.z / _7337) - cbFI_DeviceToViewDepth.x));
                        float _7351 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10548 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7410_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10642 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7348 - _7351) / max(max(_7348, _7351), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4664 = _10642 >= 0.5f;
                }
                else
                {
                    _4664 = _4634;
                }
                bool _4672;
                if (_4664)
                {
                    _4672 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4672 = _4664;
                }
                bool _10645;
                if (_4672)
                {
                    uint _7460_dummy_parameter;
                    float2 _10643;
                    do
                    {
                        float _7486 = 1.0f - _10547.y;
                        float4 _7497 = mul(float4((float2(_10547.x, _7486) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10547 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7460_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7499 = _7497.w;
                        if (!(_7499 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10643 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7512 = ((_7497.xy / _7499.xx) + 1.0f.xx) * 0.5f;
                        _10643 = float2(_7512.x - _10547.x, _7486 - _7512.y);
                        break;
                    } while(false);
                    float2 _4685 = float2(cbFI_DisplaySize);
                    _10645 = length(((_10547 + _10643) - _10548) * _4685) <= ((0.100000001490116119384765625f * length(_10643 * _4685)) + 8.0f);
                }
                else
                {
                    _10645 = _4664;
                }
                _10644 = _10645;
            }
            else
            {
                _10644 = true;
            }
            bool _4699 = !_10644;
            bool _12701 = _4699 ? false : _4603;
            bool _12702 = _4699 ? false : _4590;
            bool _10698;
            float4 _10729;
            if (!(((_4564 && _4577) && _12702) && _12701))
            {
                float4 _4721 = _10684 * float4(_4629, _4631, float(_12702), float(_12701));
                float _4723 = dot(_4721, 1.0f.xxxx);
                bool _4726 = !(_4723 > 0.0f);
                float4 _10730;
                if (!_4726)
                {
                    _10730 = _4721 / _4723.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7534;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7534);
                    }
                    _10730 = 0.0f.xxxx;
                }
                _10729 = _10730;
                _10698 = _4726;
            }
            else
            {
                _10729 = _10684;
                _10698 = false;
            }
            _11906 = float3(_4629, _4631, _10639);
            _10728 = _10729;
            _10697 = _10698;
        }
        else
        {
            _11906 = float3(float(_7182), _4548, 0.0f);
            _10728 = _10684;
            _10697 = false;
        }
        bool _4744 = !_10697;
        float4 _10813;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4744)
        {
            float _4751 = _10728.x + _10728.y;
            float4 _10814;
            if (_4751 > 0.001000000047497451305389404296875f)
            {
                _10814 = float4(_10728.x / _4751, _10728.y / _4751, 0.0f, 0.0f);
            }
            else
            {
                _10814 = float4(_4414, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10813 = _10814;
        }
        else
        {
            _10813 = _10728;
        }
        float4 _10990;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4744) && _7182)
        {
            float _10787;
            do
            {
                uint4 _7674 = r_warped_motion_qdata_tp1.Load(int3(_10574, 0));
                uint _7675 = _7674.x;
                if (_7675 != 0u)
                {
                    float _10786;
                    if (_7675 == 0u)
                    {
                        _10786 = -1.0f;
                    }
                    else
                    {
                        _10786 = float((_7675 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10787 = _10786;
                    break;
                }
                int _10769;
                uint _10770;
                _10770 = _7675;
                _10769 = -1;
                uint _10785;
                for (; _10769 <= 1; _10770 = _10785, _10769++)
                {
                    _10785 = _10770;
                    for (int _10783 = -1; _10783 <= 1; )
                    {
                        _10785 = max(_10785, r_warped_motion_qdata_tp1.Load(int3(clamp(_10574 + int2(_10783, _10769), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10783++;
                        continue;
                    }
                }
                if (_10770 != 0u)
                {
                    float _10782;
                    if (_10770 == 0u)
                    {
                        _10782 = -1.0f;
                    }
                    else
                    {
                        _10782 = float((_10770 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10787 = _10782;
                    break;
                }
                uint _10772;
                _10772 = 4294967295u;
                uint _12672;
                for (int _10771 = 0; _10771 < 8; _10772 = _12672, _10771++)
                {
                    int _10775 = 0;
                    for (;;)
                    {
                        if (_10775 < 5)
                        {
                            int2 _7625 = _10574 + (_1093[_10771] * _1102[_10775].xx);
                            bool _7628 = any(bool2(_7625.x < int2(0, 0).x, _7625.y < int2(0, 0).y));
                            bool _7636;
                            if (!_7628)
                            {
                                _7636 = any(bool2(_7625.x >= cbFI_MvDepthLaneSize.x, _7625.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7636 = _7628;
                            }
                            if (_7636)
                            {
                                _12672 = _10772;
                                break;
                            }
                            uint4 _7714 = r_warped_motion_qdata_tp1.Load(int3(_7625, 0));
                            uint _7715 = _7714.x;
                            if (_7715 != 0u)
                            {
                                _12672 = min(_10772, _7715);
                                break;
                            }
                            _10775++;
                            continue;
                        }
                        else
                        {
                            _12672 = _10772;
                            break;
                        }
                    }
                }
                float _10774;
                if (_10772 == 4294967295u)
                {
                    _10774 = -1.0f;
                }
                else
                {
                    float _10773;
                    if (_10772 == 0u)
                    {
                        _10773 = -1.0f;
                    }
                    else
                    {
                        _10773 = float((_10772 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10774 = _10773;
                }
                _10787 = _10774;
                break;
            } while(false);
            float _4787 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4790 = r_warped_motion_qdata_tp1.Load(int3(_10574, 0)).x == 0u;
            bool _4796;
            if (_4790)
            {
                bool _7740 = all(bool2(_10544.x > 0.0f.xx.x, _10544.y > 0.0f.xx.y));
                bool _7746;
                if (_7740)
                {
                    _7746 = all(bool2(_10544.x < 1.0f.xx.x, _10544.y < 1.0f.xx.y));
                }
                else
                {
                    _7746 = _7740;
                }
                _4796 = _7746;
            }
            else
            {
                _4796 = _4790;
            }
            bool _4801;
            if (_4796)
            {
                bool _7751 = all(bool2(_10546.x > 0.0f.xx.x, _10546.y > 0.0f.xx.y));
                bool _7757;
                if (_7751)
                {
                    _7757 = all(bool2(_10546.x < 1.0f.xx.x, _10546.y < 1.0f.xx.y));
                }
                else
                {
                    _7757 = _7751;
                }
                _4801 = _7757;
            }
            else
            {
                _4801 = _4796;
            }
            bool _10799;
            float4 _10808;
            if (_4801)
            {
                uint _7764_dummy_parameter;
                float _7788 = log((r_depth_tm1.Load(int3(int2(floor(_10544 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7764_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _7796_dummy_parameter;
                float _7820 = log((r_depth_tp1.Load(int3(int2(floor(_10546 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7796_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _4812 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4819;
                if (_4812)
                {
                    _4819 = _7820 > (_7788 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4819 = _4812;
                }
                bool _10804;
                float4 _10826;
                if (_4819)
                {
                    _10826 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _10804 = true;
                }
                else
                {
                    bool _4825 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _4832;
                    if (_4825)
                    {
                        _4832 = _7788 > (_7820 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _4832 = _4825;
                    }
                    bool4 _12703 = _4832.xxxx;
                    _10826 = float4(_12703.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10813.x, _12703.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10813.y, _12703.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10813.z, _12703.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10813.w);
                    _10804 = _4832 ? true : false;
                }
                _10808 = _10826;
                _10799 = _10804;
            }
            else
            {
                _10808 = _10813;
                _10799 = false;
            }
            float4 _10881;
            if (_10799)
            {
                _10881 = 1.0f.xxxx;
            }
            else
            {
                bool _4843 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4849;
                if (_4843)
                {
                    _4849 = _10808.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4849 = _4843;
                }
                bool _4854;
                if (_4849)
                {
                    bool _7826 = all(bool2(_10546.x > 0.0f.xx.x, _10546.y > 0.0f.xx.y));
                    bool _7832;
                    if (_7826)
                    {
                        _7832 = all(bool2(_10546.x < 1.0f.xx.x, _10546.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7832 = _7826;
                    }
                    _4854 = _7832;
                }
                else
                {
                    _4854 = _4849;
                }
                float4 _10882;
                if (_4854)
                {
                    float _10835;
                    if (_10787 >= 0.0f)
                    {
                        _10835 = _10787 - _4787;
                    }
                    else
                    {
                        float _10831;
                        _10831 = 2.0f;
                        float _7889;
                        for (int _10830 = 0; _10830 < 24; _10831 = _7889, _10830++)
                        {
                            float _7853 = float(_10830 & 7) * 0.785398185253143310546875f;
                            int _7855 = _10830 >> 3;
                            int _10832;
                            if (_7855 == 0)
                            {
                                _10832 = 16;
                            }
                            else
                            {
                                _10832 = (_7855 == 1) ? 48 : 96;
                            }
                            uint _7921_dummy_parameter;
                            _7889 = min(_10831, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10546 + ((cbFI_MvDepthLaneSizeRcp * float(_10832)) * float2(cos(_7853), sin(_7853))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7921_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10835 = _10831;
                    }
                    uint _7953_dummy_parameter;
                    float4 _10883;
                    if (r_depth_tp1.Load(int3(int2(floor(_10546 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7953_dummy_parameter))))), 0)).x > ((exp((_10835 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10883 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10883 = 1.0f.xxxx;
                    }
                    _10882 = _10883;
                }
                else
                {
                    _10882 = 1.0f.xxxx;
                }
                _10881 = _10882;
            }
            bool _4882 = _10787 >= 0.0f;
            bool _4883 = (!_10799) && _4882;
            bool _4890;
            if (_4883)
            {
                _4890 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4890 = _4883;
            }
            bool _4896;
            if (_4890)
            {
                _4896 = _10808.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4896 = _4890;
            }
            bool _4901;
            if (_4896)
            {
                bool _7977 = all(bool2(_10544.x > 0.0f.xx.x, _10544.y > 0.0f.xx.y));
                bool _7983;
                if (_7977)
                {
                    _7983 = all(bool2(_10544.x < 1.0f.xx.x, _10544.y < 1.0f.xx.y));
                }
                else
                {
                    _7983 = _7977;
                }
                _4901 = _7983;
            }
            else
            {
                _4901 = _4896;
            }
            float4 _10906;
            if (_4901)
            {
                float _10875;
                if (_4882)
                {
                    _10875 = _10787 - _4787;
                }
                else
                {
                    float _10871;
                    _10871 = 2.0f;
                    float _8040;
                    for (int _10870 = 0; _10870 < 24; _10871 = _8040, _10870++)
                    {
                        float _8004 = float(_10870 & 7) * 0.785398185253143310546875f;
                        int _8006 = _10870 >> 3;
                        int _10872;
                        if (_8006 == 0)
                        {
                            _10872 = 16;
                        }
                        else
                        {
                            _10872 = (_8006 == 1) ? 48 : 96;
                        }
                        uint _8056_dummy_parameter;
                        _8040 = min(_10871, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10544 + ((cbFI_MvDepthLaneSizeRcp * float(_10872)) * float2(cos(_8004), sin(_8004))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8056_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10875 = _10871;
                }
                uint _8104_dummy_parameter;
                float4 _10907;
                if (r_depth_tm1.Load(int3(int2(floor(_10544 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8104_dummy_parameter))))), 0)).x > ((exp((_10875 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10384 = _10881;
                    _10384.x = 0.0f;
                    _10907 = _10384;
                }
                else
                {
                    _10907 = _10881;
                }
                _10906 = _10907;
            }
            else
            {
                _10906 = _10881;
            }
            float4 _10919;
            if (_4883)
            {
                float _8130 = (exp(((_10787 - _4787) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _4939 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4945;
                if (_4939)
                {
                    _4945 = _10808.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4945 = _4939;
                }
                bool _4950;
                if (_4945)
                {
                    bool _8135 = all(bool2(_10548.x > 0.0f.xx.x, _10548.y > 0.0f.xx.y));
                    bool _8141;
                    if (_8135)
                    {
                        _8141 = all(bool2(_10548.x < 1.0f.xx.x, _10548.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8141 = _8135;
                    }
                    _4950 = _8141;
                }
                else
                {
                    _4950 = _4945;
                }
                bool _4958;
                if (_4950)
                {
                    uint _8148_dummy_parameter;
                    _4958 = r_depth_tp1.Load(int3(int2(floor(_10548 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8148_dummy_parameter))))), 0)).x > _8130;
                }
                else
                {
                    _4958 = _4950;
                }
                float4 _10917;
                if (_4958)
                {
                    float4 _10387 = _10906;
                    _10387.w = 0.0f;
                    _10917 = _10387;
                }
                else
                {
                    _10917 = _10906;
                }
                bool _4965 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4971;
                if (_4965)
                {
                    _4971 = _10808.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4971 = _4965;
                }
                bool _4976;
                if (_4971)
                {
                    bool _8165 = all(bool2(_10547.x > 0.0f.xx.x, _10547.y > 0.0f.xx.y));
                    bool _8171;
                    if (_8165)
                    {
                        _8171 = all(bool2(_10547.x < 1.0f.xx.x, _10547.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8171 = _8165;
                    }
                    _4976 = _8171;
                }
                else
                {
                    _4976 = _4971;
                }
                bool _4984;
                if (_4976)
                {
                    uint _8178_dummy_parameter;
                    _4984 = r_depth_tm1.Load(int3(int2(floor(_10547 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8178_dummy_parameter))))), 0)).x > _8130;
                }
                else
                {
                    _4984 = _4976;
                }
                float4 _10920;
                if (_4984)
                {
                    float4 _10390 = _10917;
                    _10390.z = 0.0f;
                    _10920 = _10390;
                }
                else
                {
                    _10920 = _10917;
                }
                _10919 = _10920;
            }
            else
            {
                _10919 = _10906;
            }
            float4 _10991;
            if (any(bool4(_10919.x < 1.0f.xxxx.x, _10919.y < 1.0f.xxxx.y, _10919.z < 1.0f.xxxx.z, _10919.w < 1.0f.xxxx.w)))
            {
                float4 _4995 = _10808 * _10919;
                float _4997 = dot(_4995, 1.0f.xxxx);
                float4 _10992;
                if (_4997 > 0.0f)
                {
                    _10992 = _4995 / _4997.xxxx;
                }
                else
                {
                    bool _5008 = _10919.y == 0.0f;
                    bool _5014;
                    if (_5008)
                    {
                        _5014 = _10919.x > 0.0f;
                    }
                    else
                    {
                        _5014 = _5008;
                    }
                    bool _5019;
                    if (_5014)
                    {
                        bool _8195 = all(bool2(_10544.x > 0.0f.xx.x, _10544.y > 0.0f.xx.y));
                        bool _8201;
                        if (_8195)
                        {
                            _8201 = all(bool2(_10544.x < 1.0f.xx.x, _10544.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8201 = _8195;
                        }
                        _5019 = _8201;
                    }
                    else
                    {
                        _5019 = _5014;
                    }
                    float4 _10993;
                    if (_5019)
                    {
                        _10993 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5024 = _10919.x == 0.0f;
                        bool _5030;
                        if (_5024)
                        {
                            _5030 = _10919.y > 0.0f;
                        }
                        else
                        {
                            _5030 = _5024;
                        }
                        bool _5035;
                        if (_5030)
                        {
                            bool _8206 = all(bool2(_10546.x > 0.0f.xx.x, _10546.y > 0.0f.xx.y));
                            bool _8212;
                            if (_8206)
                            {
                                _8212 = all(bool2(_10546.x < 1.0f.xx.x, _10546.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _8212 = _8206;
                            }
                            _5035 = _8212;
                        }
                        else
                        {
                            _5035 = _5030;
                        }
                        bool4 _12706 = _5035.xxxx;
                        _10993 = float4(_12706.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10808.x, _12706.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10808.y, _12706.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10808.z, _12706.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10808.w);
                    }
                    _10992 = _10993;
                }
                _10991 = _10992;
            }
            else
            {
                _10991 = _10808;
            }
            _10990 = _10991;
        }
        else
        {
            _10990 = _10813;
        }
        float4 _11569;
        bool _11589;
        float3 _11703;
        if (((cbFI_pad0 & 32768u) != 0u) && _4744)
        {
            bool _5052 = _10990.x > 0.00999999977648258209228515625f;
            bool _5055 = _10990.y > 0.00999999977648258209228515625f;
            bool _5064 = (_10990.z + _10990.w) > 0.0199999995529651641845703125f;
            bool _5070;
            if (_5064)
            {
                bool _8217 = all(bool2(_10547.x > 0.0f.xx.x, _10547.y > 0.0f.xx.y));
                bool _8223;
                if (_8217)
                {
                    _8223 = all(bool2(_10547.x < 1.0f.xx.x, _10547.y < 1.0f.xx.y));
                }
                else
                {
                    _8223 = _8217;
                }
                _5070 = _8223;
            }
            else
            {
                _5070 = _5064;
            }
            bool _5075;
            if (_5070)
            {
                bool _8228 = all(bool2(_10548.x > 0.0f.xx.x, _10548.y > 0.0f.xx.y));
                bool _8234;
                if (_8228)
                {
                    _8234 = all(bool2(_10548.x < 1.0f.xx.x, _10548.y < 1.0f.xx.y));
                }
                else
                {
                    _8234 = _8228;
                }
                _5075 = _8234;
            }
            else
            {
                _5075 = _5070;
            }
            bool _5082;
            if (_5075)
            {
                float _11001;
                do
                {
                    bool _8317 = all(bool2(_10547.x > 0.0f.xx.x, _10547.y > 0.0f.xx.y));
                    bool _8323;
                    if (_8317)
                    {
                        _8323 = all(bool2(_10547.x < 1.0f.xx.x, _10547.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8323 = _8317;
                    }
                    bool _8254 = !_8323;
                    bool _8261;
                    if (!_8254)
                    {
                        bool _8328 = all(bool2(_10548.x > 0.0f.xx.x, _10548.y > 0.0f.xx.y));
                        bool _8334;
                        if (_8328)
                        {
                            _8334 = all(bool2(_10548.x < 1.0f.xx.x, _10548.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8334 = _8328;
                        }
                        _8261 = !_8334;
                    }
                    else
                    {
                        _8261 = _8254;
                    }
                    if (_8261)
                    {
                        _11001 = 0.0f;
                        break;
                    }
                    uint _8341_dummy_parameter;
                    uint _8357_dummy_parameter;
                    float4 _8282 = mul(float4((float2(_10547.x, 1.0f - _10547.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10547 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8341_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _8284 = _8282.w;
                    if (abs(_8284) < 9.9999999747524270787835121154785e-07f)
                    {
                        _11001 = 0.0f;
                        break;
                    }
                    float _8295 = abs(cbFI_DeviceToViewDepth.y / ((_8282.z / _8284) - cbFI_DeviceToViewDepth.x));
                    float _8298 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10548 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8357_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _11001 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8295 - _8298) / max(max(_8295, _8298), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5082 = _11001 < 0.5f;
            }
            else
            {
                _5082 = _5075;
            }
            float4 _11016;
            if (_5082)
            {
                uint _8407_dummy_parameter;
                uint _8438_dummy_parameter;
                float4 _11017;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10547 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8407_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10548 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8438_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _11017 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _11017 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _11016 = _11017;
            }
            else
            {
                _11016 = 1.0f.xxxx;
            }
            bool _5106;
            if (_7182)
            {
                bool _8467 = all(bool2(_10544.x > 0.0f.xx.x, _10544.y > 0.0f.xx.y));
                bool _8473;
                if (_8467)
                {
                    _8473 = all(bool2(_10544.x < 1.0f.xx.x, _10544.y < 1.0f.xx.y));
                }
                else
                {
                    _8473 = _8467;
                }
                _5106 = _8473;
            }
            else
            {
                _5106 = _7182;
            }
            bool _5112;
            if (_7182)
            {
                bool _8478 = all(bool2(_10546.x > 0.0f.xx.x, _10546.y > 0.0f.xx.y));
                bool _8484;
                if (_8478)
                {
                    _8484 = all(bool2(_10546.x < 1.0f.xx.x, _10546.y < 1.0f.xx.y));
                }
                else
                {
                    _8484 = _8478;
                }
                _5112 = _8484;
            }
            else
            {
                _5112 = _7182;
            }
            bool _5118;
            if (_7214)
            {
                bool _8489 = all(bool2(_10547.x > 0.0f.xx.x, _10547.y > 0.0f.xx.y));
                bool _8495;
                if (_8489)
                {
                    _8495 = all(bool2(_10547.x < 1.0f.xx.x, _10547.y < 1.0f.xx.y));
                }
                else
                {
                    _8495 = _8489;
                }
                _5118 = _8495;
            }
            else
            {
                _5118 = _7214;
            }
            bool _5124;
            if (_7214)
            {
                bool _8500 = all(bool2(_10548.x > 0.0f.xx.x, _10548.y > 0.0f.xx.y));
                bool _8506;
                if (_8500)
                {
                    _8506 = all(bool2(_10548.x < 1.0f.xx.x, _10548.y < 1.0f.xx.y));
                }
                else
                {
                    _8506 = _8500;
                }
                _5124 = _8506;
            }
            else
            {
                _5124 = _7214;
            }
            bool _5127 = _5118 != _5124;
            bool _5133;
            if (_5127)
            {
                _5133 = _5106 || _5112;
            }
            else
            {
                _5133 = _5127;
            }
            float4 _11115;
            if (_5133)
            {
                float4 _10417 = _11016;
                _10417.z = 0.0f;
                _10417.w = 0.0f;
                _11115 = _10417;
            }
            else
            {
                _11115 = _11016;
            }
            bool _5140 = _5106 && _5052;
            bool _5143 = _5112 && _5055;
            float4 _11220;
            float3 _11804;
            if (_5140 || _5143)
            {
                float _11110;
                do
                {
                    uint4 _8645 = r_warped_motion_qdata_tp1.Load(int3(_10574, 0));
                    uint _8646 = _8645.x;
                    if (_8646 != 0u)
                    {
                        float _11109;
                        if (_8646 == 0u)
                        {
                            _11109 = -1.0f;
                        }
                        else
                        {
                            _11109 = float((_8646 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11110 = _11109;
                        break;
                    }
                    int _11092;
                    uint _11093;
                    _11093 = _8646;
                    _11092 = -1;
                    uint _11108;
                    for (; _11092 <= 1; _11093 = _11108, _11092++)
                    {
                        _11108 = _11093;
                        for (int _11106 = -1; _11106 <= 1; )
                        {
                            _11108 = max(_11108, r_warped_motion_qdata_tp1.Load(int3(clamp(_10574 + int2(_11106, _11092), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11106++;
                            continue;
                        }
                    }
                    if (_11093 != 0u)
                    {
                        float _11105;
                        if (_11093 == 0u)
                        {
                            _11105 = -1.0f;
                        }
                        else
                        {
                            _11105 = float((_11093 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11110 = _11105;
                        break;
                    }
                    uint _11095;
                    _11095 = 4294967295u;
                    uint _12673;
                    for (int _11094 = 0; _11094 < 8; _11095 = _12673, _11094++)
                    {
                        int _11098 = 0;
                        for (;;)
                        {
                            if (_11098 < 5)
                            {
                                int2 _8596 = _10574 + (_1093[_11094] * _1102[_11098].xx);
                                bool _8599 = any(bool2(_8596.x < int2(0, 0).x, _8596.y < int2(0, 0).y));
                                bool _8607;
                                if (!_8599)
                                {
                                    _8607 = any(bool2(_8596.x >= cbFI_MvDepthLaneSize.x, _8596.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8607 = _8599;
                                }
                                if (_8607)
                                {
                                    _12673 = _11095;
                                    break;
                                }
                                uint4 _8685 = r_warped_motion_qdata_tp1.Load(int3(_8596, 0));
                                uint _8686 = _8685.x;
                                if (_8686 != 0u)
                                {
                                    _12673 = min(_11095, _8686);
                                    break;
                                }
                                _11098++;
                                continue;
                            }
                            else
                            {
                                _12673 = _11095;
                                break;
                            }
                        }
                    }
                    float _11097;
                    if (_11095 == 4294967295u)
                    {
                        _11097 = -1.0f;
                    }
                    else
                    {
                        float _11096;
                        if (_11095 == 0u)
                        {
                            _11096 = -1.0f;
                        }
                        else
                        {
                            _11096 = float((_11095 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11097 = _11096;
                    }
                    _11110 = _11097;
                    break;
                } while(false);
                bool _5151 = _11110 < 0.0f;
                float _11111;
                if (_5151)
                {
                    _11111 = 0.0f;
                }
                else
                {
                    _11111 = _11110 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8707_dummy_parameter;
                uint _8739_dummy_parameter;
                float4 _11148;
                if ((_5151 && _5140) && _5143)
                {
                    uint _8771_dummy_parameter;
                    float _8795 = log((r_depth_tm1.Load(int3(int2(floor(_10544 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8771_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8803_dummy_parameter;
                    float _8827 = log((r_depth_tp1.Load(int3(int2(floor(_10546 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8803_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _11149;
                    if (_8795 > (_8827 + 0.07999999821186065673828125f))
                    {
                        float4 _10421 = _11115;
                        _10421.x = 0.0f;
                        _11149 = _10421;
                    }
                    else
                    {
                        float4 _11150;
                        if (_8827 > (_8795 + 0.07999999821186065673828125f))
                        {
                            float4 _10423 = _11115;
                            _10423.y = 0.0f;
                            _11150 = _10423;
                        }
                        else
                        {
                            _11150 = _11115;
                        }
                        _11149 = _11150;
                    }
                    _11148 = _11149;
                }
                else
                {
                    _11148 = _11115;
                }
                float _5203 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5205 = _11110 >= 0.0f;
                float _11131;
                if (_5205)
                {
                    _11131 = _11110 - _5203;
                }
                else
                {
                    float _11127;
                    if (_5140)
                    {
                        float _11126;
                        _11126 = 2.0f;
                        float _8885;
                        for (int _11125 = 0; _11125 < 24; _11126 = _8885, _11125++)
                        {
                            float _8849 = float(_11125 & 7) * 0.785398185253143310546875f;
                            int _8851 = _11125 >> 3;
                            int _11128;
                            if (_8851 == 0)
                            {
                                _11128 = 16;
                            }
                            else
                            {
                                _11128 = (_8851 == 1) ? 48 : 96;
                            }
                            uint _8901_dummy_parameter;
                            _8885 = min(_11126, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10544 + ((cbFI_MvDepthLaneSizeRcp * float(_11128)) * float2(cos(_8849), sin(_8849))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8901_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11127 = _11126;
                    }
                    else
                    {
                        _11127 = 0.0f;
                    }
                    _11131 = _11127;
                }
                float _11138;
                if (_5205)
                {
                    _11138 = _11110 - _5203;
                }
                else
                {
                    float _11134;
                    if (_5143)
                    {
                        float _11133;
                        _11133 = 2.0f;
                        float _8999;
                        for (int _11132 = 0; _11132 < 24; _11133 = _8999, _11132++)
                        {
                            float _8963 = float(_11132 & 7) * 0.785398185253143310546875f;
                            int _8965 = _11132 >> 3;
                            int _11135;
                            if (_8965 == 0)
                            {
                                _11135 = 16;
                            }
                            else
                            {
                                _11135 = (_8965 == 1) ? 48 : 96;
                            }
                            uint _9031_dummy_parameter;
                            _8999 = min(_11133, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10546 + ((cbFI_MvDepthLaneSizeRcp * float(_11135)) * float2(cos(_8963), sin(_8963))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9031_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11134 = _11133;
                    }
                    else
                    {
                        _11134 = 0.0f;
                    }
                    _11138 = _11134;
                }
                float _11139;
                if (_5140)
                {
                    uint _9063_dummy_parameter;
                    _11139 = r_depth_tm1.Load(int3(int2(floor(_10544 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9063_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11139 = 0.0f;
                }
                float _11140;
                if (_5143)
                {
                    uint _9082_dummy_parameter;
                    _11140 = r_depth_tp1.Load(int3(int2(floor(_10546 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9082_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11140 = 0.0f;
                }
                bool _5260;
                if (_5140)
                {
                    _5260 = _11139 > ((exp((_11131 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5260 = _5140;
                }
                float4 _11156;
                if (_5260)
                {
                    float4 _10425 = _11148;
                    _10425.x = 0.0f;
                    _11156 = _10425;
                }
                else
                {
                    _11156 = _11148;
                }
                bool _5272;
                if (_5143)
                {
                    _5272 = _11140 > ((exp((_11138 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5272 = _5143;
                }
                float4 _11158;
                if (_5272)
                {
                    float4 _10427 = _11156;
                    _10427.y = 0.0f;
                    _11158 = _10427;
                }
                else
                {
                    _11158 = _11156;
                }
                float4 _11221;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5205)
                {
                    bool _5292;
                    if (_5140)
                    {
                        _5292 = _11139 < ((exp((_11131 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5292 = _5140;
                    }
                    float4 _11160;
                    if (_5292)
                    {
                        float4 _10429 = _11158;
                        _10429.x = 0.0f;
                        _11160 = _10429;
                    }
                    else
                    {
                        _11160 = _11158;
                    }
                    bool _5304;
                    if (_5143)
                    {
                        _5304 = _11140 < ((exp((_11138 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5304 = _5143;
                    }
                    float4 _11222;
                    if (_5304)
                    {
                        float4 _10431 = _11160;
                        _10431.y = 0.0f;
                        _11222 = _10431;
                    }
                    else
                    {
                        _11222 = _11160;
                    }
                    _11221 = _11222;
                }
                else
                {
                    _11221 = _11158;
                }
                _11804 = float3(_11111, log((r_depth_tm1.Load(int3(int2(floor(_10544 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8707_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_10546 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8739_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _11220 = _11221;
            }
            else
            {
                _11804 = float3(0.0f, 0.0f, 0.5f);
                _11220 = _11115;
            }
            bool _5315 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5064;
            bool _5321;
            if (_5315)
            {
                _5321 = _5118 || _5124;
            }
            else
            {
                _5321 = _5315;
            }
            float4 _11243;
            if (_5321)
            {
                float _11215;
                do
                {
                    uint4 _9261 = r_warped_motion_qdata_tp1.Load(int3(_10574, 0));
                    uint _9262 = _9261.x;
                    if (_9262 != 0u)
                    {
                        float _11214;
                        if (_9262 == 0u)
                        {
                            _11214 = -1.0f;
                        }
                        else
                        {
                            _11214 = float((_9262 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11215 = _11214;
                        break;
                    }
                    int _11197;
                    uint _11198;
                    _11198 = _9262;
                    _11197 = -1;
                    uint _11213;
                    for (; _11197 <= 1; _11198 = _11213, _11197++)
                    {
                        _11213 = _11198;
                        for (int _11211 = -1; _11211 <= 1; )
                        {
                            _11213 = max(_11213, r_warped_motion_qdata_tp1.Load(int3(clamp(_10574 + int2(_11211, _11197), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11211++;
                            continue;
                        }
                    }
                    if (_11198 != 0u)
                    {
                        float _11210;
                        if (_11198 == 0u)
                        {
                            _11210 = -1.0f;
                        }
                        else
                        {
                            _11210 = float((_11198 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11215 = _11210;
                        break;
                    }
                    uint _11200;
                    _11200 = 4294967295u;
                    uint _12674;
                    for (int _11199 = 0; _11199 < 8; _11200 = _12674, _11199++)
                    {
                        int _11203 = 0;
                        for (;;)
                        {
                            if (_11203 < 5)
                            {
                                int2 _9212 = _10574 + (_1093[_11199] * _1102[_11203].xx);
                                bool _9215 = any(bool2(_9212.x < int2(0, 0).x, _9212.y < int2(0, 0).y));
                                bool _9223;
                                if (!_9215)
                                {
                                    _9223 = any(bool2(_9212.x >= cbFI_MvDepthLaneSize.x, _9212.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _9223 = _9215;
                                }
                                if (_9223)
                                {
                                    _12674 = _11200;
                                    break;
                                }
                                uint4 _9301 = r_warped_motion_qdata_tp1.Load(int3(_9212, 0));
                                uint _9302 = _9301.x;
                                if (_9302 != 0u)
                                {
                                    _12674 = min(_11200, _9302);
                                    break;
                                }
                                _11203++;
                                continue;
                            }
                            else
                            {
                                _12674 = _11200;
                                break;
                            }
                        }
                    }
                    float _11202;
                    if (_11200 == 4294967295u)
                    {
                        _11202 = -1.0f;
                    }
                    else
                    {
                        float _11201;
                        if (_11200 == 0u)
                        {
                            _11201 = -1.0f;
                        }
                        else
                        {
                            _11201 = float((_11200 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11202 = _11201;
                    }
                    _11215 = _11202;
                    break;
                } while(false);
                float4 _11244;
                if (_11215 >= 0.0f)
                {
                    float _9323 = (exp((_11215 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5340;
                    if (_5118)
                    {
                        uint _9330_dummy_parameter;
                        _5340 = r_depth_tm1.Load(int3(int2(floor(_10547 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9330_dummy_parameter))))), 0)).x > _9323;
                    }
                    else
                    {
                        _5340 = _5118;
                    }
                    float4 _11233;
                    if (_5340)
                    {
                        float4 _10433 = _11220;
                        _10433.z = 0.0f;
                        _11233 = _10433;
                    }
                    else
                    {
                        _11233 = _11220;
                    }
                    bool _5352;
                    if (_5124)
                    {
                        uint _9349_dummy_parameter;
                        _5352 = r_depth_tp1.Load(int3(int2(floor(_10548 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9349_dummy_parameter))))), 0)).x > _9323;
                    }
                    else
                    {
                        _5352 = _5124;
                    }
                    float4 _11245;
                    if (_5352)
                    {
                        float4 _10435 = _11233;
                        _10435.w = 0.0f;
                        _11245 = _10435;
                    }
                    else
                    {
                        _11245 = _11233;
                    }
                    _11244 = _11245;
                }
                else
                {
                    _11244 = _11220;
                }
                _11243 = _11244;
            }
            else
            {
                _11243 = _11220;
            }
            bool _5360 = _5106 != _5112;
            bool _5367;
            if (_5360)
            {
                _5367 = _5106 ? _5052 : _5055;
            }
            else
            {
                _5367 = _5360;
            }
            bool _5374;
            if (_5367)
            {
                _5374 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5374 = _5367;
            }
            float4 _11328;
            if (_5374)
            {
                bool2 _5379 = _5106.xx;
                float2 _5380 = float2(_5379.x ? _10544.x : _10546.x, _5379.y ? _10544.y : _10546.y);
                float _11235;
                if (_5106)
                {
                    uint _9368_dummy_parameter;
                    _11235 = r_depth_tm1.Load(int3(int2(floor(_5380 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9368_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9384_dummy_parameter;
                    _11235 = r_depth_tp1.Load(int3(int2(floor(_5380 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9384_dummy_parameter))))), 0)).x;
                }
                float4x4 _11236;
                if (_5106)
                {
                    _11236 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _11236 = cbFI_MotionTP1ToTM1;
                }
                float2 _11237;
                do
                {
                    float _9411 = _5380.x;
                    float _9414 = 1.0f - _5380.y;
                    float4 _9425 = mul(float4((float2(_9411, _9414) * 2.0f) - 1.0f.xx, _11235, 1.0f), _11236);
                    float _9427 = _9425.w;
                    if (!(_9427 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11237 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9440 = ((_9425.xy / _9427.xx) + 1.0f.xx) * 0.5f;
                    _11237 = float2(_9440.x - _9411, _9414 - _9440.y);
                    break;
                } while(false);
                float2 _5410 = float2(cbFI_DisplaySize);
                float4 _11329;
                if (!(length(((_5380 + _11237) - float2(_5379.x ? _10546.x : _10544.x, _5379.y ? _10546.y : _10544.y)) * _5410) <= ((0.100000001490116119384765625f * length(_11237 * _5410)) + 8.0f)))
                {
                    float4 _11330;
                    if (_5106)
                    {
                        float4 _10445 = _11243;
                        _10445.x = 0.0f;
                        _11330 = _10445;
                    }
                    else
                    {
                        float4 _10447 = _11243;
                        _10447.y = 0.0f;
                        _11330 = _10447;
                    }
                    _11329 = _11330;
                }
                else
                {
                    _11329 = _11243;
                }
                _11328 = _11329;
            }
            else
            {
                _11328 = _11243;
            }
            float4 _5435 = _10990 * _11328;
            float _5437 = dot(_5435, 1.0f.xxxx);
            float4 _11570;
            bool _11590;
            if (_5437 > 0.0f)
            {
                _11590 = _10697;
                _11570 = _5435 / _5437.xxxx;
            }
            else
            {
                bool _5448 = any(bool4(_11328.x < 1.0f.xxxx.x, _11328.y < 1.0f.xxxx.y, _11328.z < 1.0f.xxxx.z, _11328.w < 1.0f.xxxx.w));
                if (_5448)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9462;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9462);
                    }
                }
                bool4 _12709 = _5448.xxxx;
                _11590 = _5448 ? true : _10697;
                _11570 = float4(_12709.x ? 0.0f.xxxx.x : _10990.x, _12709.y ? 0.0f.xxxx.y : _10990.y, _12709.z ? 0.0f.xxxx.z : _10990.z, _12709.w ? 0.0f.xxxx.w : _10990.w);
            }
            _11703 = _11804;
            _11589 = _11590;
            _11569 = _11570;
        }
        else
        {
            _11703 = float3(0.0f, 0.0f, 0.5f);
            _11589 = _10697;
            _11569 = _10990;
        }
        uint _5457 = (cbFI_pad0 >> 24u) & 31u;
        uint _5461 = (cbFI_pad0 >> 16u) & 255u;
        bool _5463 = _5457 != 0u;
        bool _5465 = _5461 == 12u;
        bool _5468 = _5461 == 13u;
        float4 _11586;
        if ((_5463 || _5465) || _5468)
        {
            float _11331;
            do
            {
                bool _9546 = all(bool2(_10547.x > 0.0f.xx.x, _10547.y > 0.0f.xx.y));
                bool _9552;
                if (_9546)
                {
                    _9552 = all(bool2(_10547.x < 1.0f.xx.x, _10547.y < 1.0f.xx.y));
                }
                else
                {
                    _9552 = _9546;
                }
                bool _9483 = !_9552;
                bool _9490;
                if (!_9483)
                {
                    bool _9557 = all(bool2(_10548.x > 0.0f.xx.x, _10548.y > 0.0f.xx.y));
                    bool _9563;
                    if (_9557)
                    {
                        _9563 = all(bool2(_10548.x < 1.0f.xx.x, _10548.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9563 = _9557;
                    }
                    _9490 = !_9563;
                }
                else
                {
                    _9490 = _9483;
                }
                if (_9490)
                {
                    _11331 = 0.0f;
                    break;
                }
                uint _9570_dummy_parameter;
                uint _9586_dummy_parameter;
                float4 _9511 = mul(float4((float2(_10547.x, 1.0f - _10547.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10547 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9570_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9513 = _9511.w;
                if (abs(_9513) < 9.9999999747524270787835121154785e-07f)
                {
                    _11331 = 0.0f;
                    break;
                }
                float _9524 = abs(cbFI_DeviceToViewDepth.y / ((_9511.z / _9513) - cbFI_DeviceToViewDepth.x));
                float _9527 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10548 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9586_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _11331 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9524 - _9527) / max(max(_9524, _9527), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9634 = all(bool2(_10548.x > 0.0f.xx.x, _10548.y > 0.0f.xx.y));
            bool _9640;
            if (_9634)
            {
                _9640 = all(bool2(_10548.x < 1.0f.xx.x, _10548.y < 1.0f.xx.y));
            }
            else
            {
                _9640 = _9634;
            }
            float _11332;
            if (_9640)
            {
                uint _9647_dummy_parameter;
                _11332 = length((_6268 + (r_motion_tp1.Load(int3(int2(floor(_10548 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9647_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _11332 = 1000000.0f;
            }
            float _11343;
            if ((_5457 & 1u) != 0u)
            {
                _11343 = _11331;
            }
            else
            {
                _11343 = 1.0f;
            }
            float _11344;
            if ((_5457 & 2u) != 0u)
            {
                _11344 = _11343 * (1.0f - smoothstep(2.0f, 8.0f, _11332));
            }
            else
            {
                _11344 = _11343;
            }
            float _11345;
            if ((_5457 & 4u) != 0u)
            {
                _11345 = _11344 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6989 - _6997) - length(_6973 - _6981))));
            }
            else
            {
                _11345 = _11344;
            }
            float _11580;
            if ((_5457 & 8u) != 0u)
            {
                _11580 = lerp(1.0f, _11345, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6973 - _6981)));
            }
            else
            {
                _11580 = _11345;
            }
            bool _5543 = (_5457 & 16u) != 0u;
            bool _5552;
            if (_5543)
            {
                _5552 = length(_10542 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5552 = _5543;
            }
            float _12711 = _5552 ? 1.0f : _11580;
            bool _5558 = _5463 && _7182;
            bool _5563;
            if (_5558)
            {
                bool _9672 = all(bool2(_10544.x > 0.0f.xx.x, _10544.y > 0.0f.xx.y));
                bool _9678;
                if (_9672)
                {
                    _9678 = all(bool2(_10544.x < 1.0f.xx.x, _10544.y < 1.0f.xx.y));
                }
                else
                {
                    _9678 = _9672;
                }
                _5563 = _9678;
            }
            else
            {
                _5563 = _5558;
            }
            bool _5568;
            if (_5563)
            {
                bool _9683 = all(bool2(_10546.x > 0.0f.xx.x, _10546.y > 0.0f.xx.y));
                bool _9689;
                if (_9683)
                {
                    _9689 = all(bool2(_10546.x < 1.0f.xx.x, _10546.y < 1.0f.xx.y));
                }
                else
                {
                    _9689 = _9683;
                }
                _5568 = _9689;
            }
            else
            {
                _5568 = _5563;
            }
            float4 _11587;
            if (_5568)
            {
                float _5574 = _11569.x + _11569.y;
                float _5583 = (_11569.z + _11569.w) * (1.0f - _12711);
                float _11583;
                if (_5574 > 9.9999997473787516355514526367188e-06f)
                {
                    _11583 = _11569.x / _5574;
                }
                else
                {
                    _11583 = _4414;
                }
                _11587 = float4(_11569.x + (_5583 * _11583), _11569.y + (_5583 * (1.0f - _11583)), _11569.zw * _12711);
            }
            else
            {
                _11587 = _11569;
            }
            _11586 = _11587;
        }
        else
        {
            _11586 = _11569;
        }
        float3 _12476;
        if (_11589)
        {
            float3 _9695 = r_current_interpolation_source.Load(int3(_3770, 0)).xyz;
            float3 _12477;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _7182)
            {
                uint _9702_dummy_parameter;
                float _11694;
                _11694 = r_depth_tm1.Load(int3(int2(floor(_10544 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9702_dummy_parameter))))), 0)).x;
                float _5695;
                for (int _11693 = 0; _11693 < 24; _11694 = _5695, _11693++)
                {
                    float _5667 = float(_11693 & 7) * 0.785398185253143310546875f;
                    int _5669 = _11693 >> 3;
                    int _12527;
                    if (_5669 == 0)
                    {
                        _12527 = 16;
                    }
                    else
                    {
                        _12527 = (_5669 == 1) ? 48 : 96;
                    }
                    uint _9722_dummy_parameter;
                    _5695 = min(_11694, r_depth_tm1.Load(int3(int2(floor(clamp(_10544 + ((cbFI_MvDepthLaneSizeRcp * float(_12527)) * float2(cos(_5667), sin(_5667))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9722_dummy_parameter))))), 0)).x);
                }
                float2 _11695;
                do
                {
                    float _9744 = 1.0f - _10544.y;
                    float4 _9755 = mul(float4((float2(_10544.x, _9744) * 2.0f) - 1.0f.xx, _11694, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9757 = _9755.w;
                    if (!(_9757 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11695 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9770 = ((_9755.xy / _9757.xx) + 1.0f.xx) * 0.5f;
                    _11695 = float2(_9770.x - _10544.x, _9744 - _9770.y);
                    break;
                } while(false);
                float2 _5706 = _10544 + _11695;
                bool _9788 = all(bool2(_5706.x > 0.0f.xx.x, _5706.y > 0.0f.xx.y));
                bool _9794;
                if (_9788)
                {
                    _9794 = all(bool2(_5706.x < 1.0f.xx.x, _5706.y < 1.0f.xx.y));
                }
                else
                {
                    _9794 = _9788;
                }
                float3 _12478;
                if (_9794)
                {
                    float _5712 = abs(cbFI_DeviceToViewDepth.y / (_11694 - cbFI_DeviceToViewDepth.x));
                    uint _9814_dummy_parameter;
                    int2 _9814 = int2(spvTextureSize(r_depth_m2, uint(0), _9814_dummy_parameter));
                    float _5716 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5706 * float2(_9814))), int2(0, 0), _9814 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12483;
                    if (abs(_5716 - _5712) <= (0.20000000298023223876953125f * max(_5716, _5712)))
                    {
                        uint _9848_dummy_parameter;
                        int2 _9848 = int2(spvTextureSize(r_colour_m2, uint(0), _9848_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9871;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9871);
                        }
                        _12483 = r_colour_m2.Load(int3(clamp(int2(floor(_5706 * float2(_9848))), int2(0, 0), _9848 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9881;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9881);
                        }
                        _12483 = _9695;
                    }
                    _12478 = _12483;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9891;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9891);
                    }
                    _12478 = _9695;
                }
                _12477 = _12478;
            }
            else
            {
                _12477 = _9695;
            }
            _12476 = _12477;
        }
        else
        {
            _12476 = (((_6973 * _11586.x) + (_6981 * _11586.y)) + (_6989 * _11586.z)) + (_6997 * _11586.w);
        }
        uint _5744 = cbFI_pad0 & 255u;
        bool _12368;
        float3 _12475;
        if (_5744 != 0u)
        {
            float3 _5749 = r_present_backbuffer.Load(int3(_3770, 0)).xyz;
            float3 _5753 = r_current_interpolation_source.Load(int3(_3770, 0)).xyz;
            float3 _5757 = abs(_5749 - _5753);
            float3 _11698;
            if (_5744 == 2u)
            {
                _11698 = (abs(_5753) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11698 = 0.000244140625f.xxx;
            }
            bool _5773 = any(bool3(_5757.x > _11698.x, _5757.y > _11698.y, _5757.z > _11698.z));
            bool3 _12712 = _5773.xxx;
            _12475 = float3(_12712.x ? _5749.x : _12476.x, _12712.y ? _5749.y : _12476.y, _12712.z ? _5749.z : _12476.z);
            _12368 = _5773;
        }
        else
        {
            _12475 = _12476;
            _12368 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9906;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9906);
        }
        float3 _12458;
        if (_5461 == 1u)
        {
            _12458 = lerp(_6973, _6981, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12459;
            if (_5461 == 2u)
            {
                _12459 = lerp(_6989, _6997, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12460;
                if (_5461 == 3u)
                {
                    _12460 = float(_12368).xxx;
                }
                else
                {
                    float3 _12461;
                    if (_5461 == 4u)
                    {
                        _12461 = float3(((_10542 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12462;
                        if (_5461 == 5u)
                        {
                            _12462 = float3(((_6268 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12463;
                            if (_5461 == 6u)
                            {
                                _12463 = float3(_11586.xy, _11586.z + _11586.w);
                            }
                            else
                            {
                                float3 _12464;
                                if (_5461 == 7u)
                                {
                                    _12464 = r_current_interpolation_source.Load(int3(_3770, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12465;
                                    if (_5461 == 8u)
                                    {
                                        _12465 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4189, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12466;
                                        if (_5465)
                                        {
                                            uint _9928_dummy_parameter;
                                            uint _9960_dummy_parameter;
                                            _12466 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4189 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9928_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4189 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9960_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12467;
                                            if (_5468)
                                            {
                                                _12467 = _6989;
                                            }
                                            else
                                            {
                                                float3 _12468;
                                                if (_5461 == 20u)
                                                {
                                                    _12468 = _6973;
                                                }
                                                else
                                                {
                                                    float3 _12469;
                                                    if (_5461 == 21u)
                                                    {
                                                        _12469 = _6981;
                                                    }
                                                    else
                                                    {
                                                        float3 _12470;
                                                        if (_5461 == 22u)
                                                        {
                                                            _12470 = _6997;
                                                        }
                                                        else
                                                        {
                                                            float3 _12471;
                                                            if (_5461 == 18u)
                                                            {
                                                                _12471 = _12114;
                                                            }
                                                            else
                                                            {
                                                                float3 _12472;
                                                                if (_5461 == 19u)
                                                                {
                                                                    _12472 = _11906;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12714 = (_5461 == 23u).xxx;
                                                                    _12472 = float3(_12714.x ? _11703.x : _12475.x, _12714.y ? _11703.y : _12475.y, _12714.z ? _11703.z : _12475.z);
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
                                            _12466 = _12467;
                                        }
                                        _12465 = _12466;
                                    }
                                    _12464 = _12465;
                                }
                                _12463 = _12464;
                            }
                            _12462 = _12463;
                        }
                        _12461 = _12462;
                    }
                    _12460 = _12461;
                }
                _12459 = _12460;
            }
            _12458 = _12459;
        }
        float3 _12457;
        if ((_5461 >= 9u) && (_5461 <= 11u))
        {
            uint _5937 = 64u + uint((_10574.y * cbFI_MvDepthLaneSize.x) + _10574.x);
            uint _5941 = rw_nfru_diagnostics.Load<uint>(_5937 * 4 + 0) & 15u;
            float3 _12488;
            if (_5461 == 10u)
            {
                float3 _12456;
                if ((rw_nfru_diagnostics.Load<uint>(_5937 * 4 + 0) & 32u) != 0u)
                {
                    _12456 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12455;
                    if ((rw_nfru_diagnostics.Load<uint>(_5937 * 4 + 0) & 16u) != 0u)
                    {
                        _12455 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5962 = ((rw_nfru_diagnostics.Load<uint>(_5937 * 4 + 0) & 64u) != 0u).xxx;
                        _12455 = float3(_5962.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5962.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5962.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12456 = _12455;
                }
                _12488 = _12456;
            }
            else
            {
                float3 _12489;
                if (_5461 == 11u)
                {
                    uint _5975 = (rw_nfru_diagnostics.Load<uint>(_5937 * 4 + 0) >> 8u) & 15u;
                    uint _5978 = (rw_nfru_diagnostics.Load<uint>(_5937 * 4 + 0) >> 12u) & 15u;
                    float3 _12448;
                    if ((_5941 == 2u) || (_5941 == 3u))
                    {
                        _12448 = _3466[_5941];
                    }
                    else
                    {
                        bool _5990 = _5975 == 3u;
                        bool _5992 = _5978 == 3u;
                        float3 _12449;
                        if (_5990 && _5992)
                        {
                            _12449 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12450;
                            if (_5990)
                            {
                                _12450 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12451;
                                if (_5992)
                                {
                                    _12451 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12452;
                                    if ((_5975 == 4u) || (_5978 == 4u))
                                    {
                                        _12452 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12453;
                                        if ((_5975 == 1u) || (_5978 == 1u))
                                        {
                                            _12453 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12716 = (_5941 == 1u).xxx;
                                            _12453 = float3(_12716.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12716.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12716.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12452 = _12453;
                                    }
                                    _12451 = _12452;
                                }
                                _12450 = _12451;
                            }
                            _12449 = _12450;
                        }
                        _12448 = _12449;
                    }
                    _12489 = _12448;
                }
                else
                {
                    _12489 = _3466[min(_5941, 7u)];
                }
                _12488 = _12489;
            }
            _12457 = _12488;
        }
        else
        {
            _12457 = _12458;
        }
        float4 _12492;
        if ((_5461 >= 14u) && (_5461 <= 16u))
        {
            float2 _12490;
            if (_5461 == 14u)
            {
                uint _6048_dummy_parameter;
                uint _6054_dummy_parameter;
                _12490 = r_flow_tm1.Load(int3(clamp(int2(floor(_4189 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6048_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6054_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12491;
                if (_5461 == 16u)
                {
                    uint _10011 = r_warped_flow_qdata_tm1.Load(int3(_4205, 0)).x & 2147483647u;
                    uint _10043 = uint(max((int((_10011 >> 16u) & 15u) - 6), 0));
                    _12491 = ((float2(float((1 - (2 * int((_10011 >> 15u) & 1u))) * int(((_10011 >> uint(7)) & 127u) << _10043)), float((1 - (2 * int((_10011 >> 14u) & 1u))) * int((_10011 & 127u) << _10043))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12491 = _6268 * float2(cbFI_DisplaySize);
                }
                _12490 = _12491;
            }
            uint2 _6087 = uint2(clamp(round(_12490 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6089 = _6087.x;
            uint _6096 = _6087.y;
            _12492 = float4(float(_6089 & 255u), float((_6089 >> 8u) | ((_6096 & 15u) << 4u)), float(_6096 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12493;
            if (_5461 == 17u)
            {
                _12493 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4205, 0)).x != 0u), _4548, 0.0f, 1.0f);
            }
            else
            {
                _12493 = float4(_12457, 1.0f);
            }
            _12492 = _12493;
        }
        rw_output[_3770] = _12492.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6140 = ((uint(_3770.y) * uint(cbFI_DisplaySize.x)) + uint(_3770.x)) * 6u;
            uint _10089 = spvPackHalf2x16(clamp(_6972.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6140 * 4 + 0, (((_10089 & 32767u) >> 4u) | ((((_10089 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6972.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10124 = spvPackHalf2x16(clamp(_6980.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6140 + 1u) * 4 + 0, (((_10124 & 32767u) >> 4u) | ((((_10124 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6980.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10159 = spvPackHalf2x16(clamp(_6988.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6140 + 2u) * 4 + 0, (((_10159 & 32767u) >> 4u) | ((((_10159 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6988.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10194 = spvPackHalf2x16(clamp(_6996.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6140 + 3u) * 4 + 0, (((_10194 & 32767u) >> 4u) | ((((_10194 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6996.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _10221 = r_current_interpolation_source.Load(int3(_3770, 0));
            uint _10235 = spvPackHalf2x16(clamp(_10221.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6140 + 4u) * 4 + 0, (((_10235 & 32767u) >> 4u) | ((((_10235 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10221.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12526;
            if (_12368 || (_5461 != 0u))
            {
                _12526 = 4294967295u;
            }
            else
            {
                uint _10270 = spvPackHalf2x16(clamp(_12492.xy, 0.0f.xx, 65000.0f.xx));
                _12526 = (((_10270 & 32767u) >> 4u) | ((((_10270 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12492.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6140 + 5u) * 4 + 0, _12526);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3770] = float4(r_current_interpolation_source.Load(int3(_3770, 0)).xyz, 1.0f).xyz;
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
