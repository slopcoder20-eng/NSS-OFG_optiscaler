static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19801;

static const int2 _1248[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1257[5] = { 2, 4, 7, 11, 16 };
static const float3 _4566[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4884 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4884.x >= cbFI_DisplaySize.x, _4884.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4884] = float4(r_present_backbuffer.Load(int3(_4884, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4884] = float4(r_current_interpolation_source.Load(int3(_4884, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7774 = cbFI_DisplaySize - int2(1, 1);
                int2 _7775 = clamp(_4884, int2(0, 0), _7774);
                uint _7785 = uint((_7775.y * cbFI_DisplaySize.x) + _7775.x) * 2u;
                uint _7788 = rw_nfru_select.Load<uint>(_7785 * 4 + 0);
                float2 _7789 = spvUnpackHalf2x16(_7788);
                uint _7793 = rw_nfru_select.Load<uint>((_7785 + 1u) * 4 + 0);
                float2 _7794 = spvUnpackHalf2x16(_7793);
                float _7795 = _7789.x;
                float _7797 = _7794.x;
                if (_7794.y > 1.5f)
                {
                    rw_output[_4884] = float4(_7795, _7789.y, _7797, 1.0f).xyz;
                    break;
                }
                int _23238;
                float _23239;
                float3 _23240;
                float _23241;
                float _23242;
                _23242 = 0.0f;
                _23241 = 0.0f;
                _23240 = 0.0f.xxx;
                _23239 = 0.0f;
                _23238 = -2;
                float3 _23245;
                float _23246;
                float _23247;
                float _23248;
                for (; _23238 <= 2; _23242 = _23248, _23241 = _23247, _23240 = _23245, _23239 = _23246, _23238++)
                {
                    _23248 = _23242;
                    _23247 = _23241;
                    _23246 = _23239;
                    _23245 = _23240;
                    for (int _23243 = -2; _23243 <= 2; )
                    {
                        float _7691 = float((_23243 * _23243) + (_23238 * _23238));
                        float _7696 = exp(_7691 * (-0.319999992847442626953125f));
                        int2 _7701 = int2(_23243, _23238);
                        int2 _7811 = clamp(_4884 + (_7701 * int2(2, 2)), int2(0, 0), _7774);
                        uint _7821 = uint((_7811.y * cbFI_DisplaySize.x) + _7811.x) * 2u;
                        float _7718 = exp(_7691 * (-0.5f));
                        int2 _7843 = clamp(_4884 + (_7701 * int2(6, 6)), int2(0, 0), _7774);
                        _23248 += _7718;
                        _23247 += (_7718 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7843.y * cbFI_DisplaySize.x) + _7843.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23246 += _7696;
                        _23245 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7821 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7821 + 1u) * 4 + 0)).x, _19801).xyz * _7696);
                        _23243++;
                        continue;
                    }
                }
                float3 _7748 = _23240 / _23239.xxx;
                rw_output[_4884] = float4(_7748 + ((float4(_7795, _7789.y, _7797, _7794.y).xyz - _7748) * clamp(_23241 / _23242, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5396 = (float2(_4884) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5398 = float2(cbFI_MvDepthLaneSize);
        int2 _5407 = int2(floor(_5396 * _5398));
        int2 _5412 = int2(floor(_5396 * float2(cbFI_FlowLaneSize)));
        float4 _7914 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5396 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7920 = r_warped_filled_flow_tm1.Load(int3(_5412, 0)).xy;
        float2 _7926 = r_warped_filled_motion_tp1.Load(int3(_5407, 0)).xy;
        bool _7948 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19802;
        if (_7948)
        {
            float _7961 = ((2.0f * _5396.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19802 = float2(atan(_7961) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5396.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7961 * _7961))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19802 = _5396;
        }
        bool _5433 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19823;
        bool _19965;
        int2 _20046;
        float3 _22330;
        if (_5433)
        {
            float _19804;
            float _19806;
            _19806 = 2.0f;
            _19804 = -1.0f;
            uint _4983[9];
            float _23249;
            float _23252;
            for (int _19803 = 0; _19803 < 9; _19806 = _23252, _19804 = _23249, _19803++)
            {
                _4983[_19803] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5407 + int2((_19803 % 3) - 1, (_19803 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4983[_19803] != 0u)
                {
                    float _23233;
                    if (_4983[_19803] == 0u)
                    {
                        _23233 = -1.0f;
                    }
                    else
                    {
                        _23233 = float((_4983[_19803] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23252 = min(_19806, _23233);
                    _23249 = max(_19804, _23233);
                }
                else
                {
                    _23252 = _19806;
                    _23249 = _19804;
                }
            }
            float _5479 = float(_19804 >= 0.0f);
            float3 _19369 = 0.0f.xxx;
            _19369.y = _5479;
            float2 _19824;
            bool _19966;
            int2 _20047;
            float3 _22331;
            if ((_19804 - _19806) > 0.0199999995529651641845703125f)
            {
                float _19812;
                int2 _19813;
                float2 _19814;
                int2 _19816;
                float2 _19822;
                _19822 = _7926;
                _19816 = _5407;
                _19814 = _7926;
                _19813 = _5407;
                _19812 = -1.0f;
                float _23257;
                int2 _23261;
                float2 _23272;
                int2 _23283;
                float2 _23316;
                float _23701;
                int _19811 = 0;
                float _23214 = 1000000000.0f;
                for (; _19811 < 9; _23214 = _23701, _19822 = _23316, _19816 = _23283, _19814 = _23272, _19813 = _23261, _19812 = _23257, _19811++)
                {
                    if (_4983[_19811] == 0u)
                    {
                        _23701 = _23214;
                        _23316 = _19822;
                        _23283 = _19816;
                        _23272 = _19814;
                        _23261 = _19813;
                        _23257 = _19812;
                        continue;
                    }
                    int2 _5514 = clamp(_5407 + int2((_19811 % 3) - 1, (_19811 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8036 = _4983[_19811] & 2147483647u;
                    uint _8068 = uint(max((int((_8036 >> 16u) & 15u) - 6), 0));
                    float2 _5520 = (float2(float((1 - (2 * int((_8036 >> 15u) & 1u))) * int(((_8036 >> uint(7)) & 127u) << _8068)), float((1 - (2 * int((_8036 >> 14u) & 1u))) * int((_8036 & 127u) << _8068))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23200;
                    if (_4983[_19811] == 0u)
                    {
                        _23200 = -1.0f;
                    }
                    else
                    {
                        _23200 = float((_4983[_19811] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5525 = _23200 - 0.100000001490116119384765625f;
                    float2 _23201;
                    if (_7948)
                    {
                        float2 _8145 = clamp((((_19802 + (_5520 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8148 = tan(_8145.x);
                        _23201 = (float2(_8148 / cbFI_DeviceToViewDepth.z, (tan(_8145.y) * sqrt(1.0f + (_8148 * _8148))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23201 = _19802 + (_5520 * cbFI_Timestep);
                    }
                    float _5532 = cbFI_Timestep - 1.0f;
                    float2 _23202;
                    if (_7948)
                    {
                        float2 _8216 = clamp((((_19802 + (_5520 * _5532)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8219 = tan(_8216.x);
                        _23202 = (float2(_8219 / cbFI_DeviceToViewDepth.z, (tan(_8216.y) * sqrt(1.0f + (_8219 * _8219))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23202 = _19802 + (_5520 * _5532);
                    }
                    bool _8252 = all(bool2(_23201.x > 0.0f.xx.x, _23201.y > 0.0f.xx.y));
                    bool _8258;
                    if (_8252)
                    {
                        _8258 = all(bool2(_23201.x < 1.0f.xx.x, _23201.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8258 = _8252;
                    }
                    float _23205;
                    if (_8258)
                    {
                        uint _8265_dummy_parameter;
                        _23205 = max((_5525 - (log((r_depth_tm1.Load(int3(int2(floor(_23201 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8265_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23205 = 0.0f;
                    }
                    bool _8295 = all(bool2(_23202.x > 0.0f.xx.x, _23202.y > 0.0f.xx.y));
                    bool _8301;
                    if (_8295)
                    {
                        _8301 = all(bool2(_23202.x < 1.0f.xx.x, _23202.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8301 = _8295;
                    }
                    float _23206;
                    if (_8301)
                    {
                        uint _8308_dummy_parameter;
                        _23206 = _23205 + max((_5525 - (log((r_depth_tp1.Load(int3(int2(floor(_23202 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8308_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23206 = _23205;
                    }
                    float _23258;
                    int2 _23262;
                    float2 _23273;
                    int2 _23284;
                    float2 _23317;
                    float _23702;
                    if (_23206 == 0.0f)
                    {
                        bool _5567 = _5525 > _19812;
                        bool2 _23710 = _5567.xx;
                        _23702 = _23214;
                        _23317 = float2(_23710.x ? _5520.x : _19822.x, _23710.y ? _5520.y : _19822.y);
                        _23284 = int2(_23710.x ? _5514.x : _19816.x, _23710.y ? _5514.y : _19816.y);
                        _23273 = _19814;
                        _23262 = _19813;
                        _23258 = _5567 ? _5525 : _19812;
                    }
                    else
                    {
                        bool _5576 = _23206 < _23214;
                        bool2 _23706 = _5576.xx;
                        _23702 = _5576 ? _23206 : _23214;
                        _23317 = _19822;
                        _23284 = _19816;
                        _23273 = float2(_23706.x ? _5520.x : _19814.x, _23706.y ? _5520.y : _19814.y);
                        _23262 = int2(_23706.x ? _5514.x : _19813.x, _23706.y ? _5514.y : _19813.y);
                        _23258 = _19812;
                    }
                    _23701 = _23702;
                    _23316 = _23317;
                    _23283 = _23284;
                    _23272 = _23273;
                    _23261 = _23262;
                    _23257 = _23258;
                }
                bool _5588 = _19812 < 0.0f;
                bool2 _23716 = _5588.xx;
                int2 _23719 = int2(_23716.x ? _19813.x : _19816.x, _23716.y ? _19813.y : _19816.y);
                _22331 = float3(1.0f, _5479, float(any(bool2(_23719.x != _5407.x, _23719.y != _5407.y))));
                _20047 = _23719;
                _19966 = _5588 ? false : true;
                _19824 = float2(_23716.x ? _19814.x : _19822.x, _23716.y ? _19814.y : _19822.y);
            }
            else
            {
                _22331 = _19369;
                _20047 = _5407;
                _19966 = false;
                _19824 = _7926;
            }
            _22330 = _22331;
            _20046 = _20047;
            _19965 = _19966;
            _19823 = _19824;
        }
        else
        {
            _22330 = 0.0f.xxx;
            _20046 = _5407;
            _19965 = false;
            _19823 = _7926;
        }
        float2 _19825;
        if (_7948)
        {
            float2 _8373 = clamp((((_19802 + (_19823 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8376 = tan(_8373.x);
            _19825 = (float2(_8376 / cbFI_DeviceToViewDepth.z, (tan(_8373.y) * sqrt(1.0f + (_8376 * _8376))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19825 = _19802 + (_19823 * cbFI_Timestep);
        }
        float _5611 = cbFI_Timestep - 1.0f;
        float2 _19827;
        if (_7948)
        {
            float2 _8444 = clamp((((_19802 + (_19823 * _5611)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8447 = tan(_8444.x);
            _19827 = (float2(_8447 / cbFI_DeviceToViewDepth.z, (tan(_8444.y) * sqrt(1.0f + (_8447 * _8447))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19827 = _19802 + (_19823 * _5611);
        }
        float _5616 = -cbFI_Timestep;
        float2 _19828;
        if (_7948)
        {
            float2 _8515 = clamp((((_19802 + (_7920 * _5616)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8518 = tan(_8515.x);
            _19828 = (float2(_8518 / cbFI_DeviceToViewDepth.z, (tan(_8515.y) * sqrt(1.0f + (_8518 * _8518))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19828 = _19802 + (_7920 * _5616);
        }
        float _5621 = 1.0f - cbFI_Timestep;
        float2 _19829;
        if (_7948)
        {
            float2 _8586 = clamp((((_19802 + (_7920 * _5621)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8589 = tan(_8586.x);
            _19829 = (float2(_8589 / cbFI_DeviceToViewDepth.z, (tan(_8586.y) * sqrt(1.0f + (_8589 * _8589))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19829 = _19802 + (_7920 * _5621);
        }
        float4 _8624 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19825, 0.0f);
        float3 _8625 = _8624.xyz;
        float4 _8632 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19827, 0.0f);
        float3 _8633 = _8632.xyz;
        float4 _8640 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19828, 0.0f);
        float3 _8641 = _8640.xyz;
        float4 _8648 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19829, 0.0f);
        float3 _8649 = _8648.xyz;
        float4 _8663 = exp(_7914 - max(max(max(_7914.x, _7914.y), _7914.z), _7914.w).xxxx);
        float4 _8670 = _8663 / (dot(_8663, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5637 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _20036;
        float _21344;
        if (_5637)
        {
            float2 _5643 = 0.5f.xx / _5398;
            float _5646 = _5643.x;
            float _5647 = -_5646;
            float _5649 = _5643.y;
            float _5650 = -_5649;
            float2 _5652 = _5396 + float2(_5647, _5650);
            float2 _5654 = float2(cbFI_DisplaySize);
            bool _19846;
            do
            {
                bool _8750 = all(bool2(_5652.x > 0.0f.xx.x, _5652.y > 0.0f.xx.y));
                bool _8756;
                if (_8750)
                {
                    _8756 = all(bool2(_5652.x < 1.0f.xx.x, _5652.y < 1.0f.xx.y));
                }
                else
                {
                    _8756 = _8750;
                }
                if (!_8756)
                {
                    _19846 = false;
                    break;
                }
                uint _8763_dummy_parameter;
                float4x4 _19844;
                do
                {
                    float4x4 _8777;
                    bool _19843;
                    do
                    {
                        _8777 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19843 = false;
                            break;
                        }
                        uint _8811 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8811 + 32u) * 4 + 0) != 1u)
                        {
                            _19843 = false;
                            break;
                        }
                        uint _19840;
                        _19840 = 0u;
                        for (; _19840 < 4u; _19840++)
                        {
                            for (uint _19841 = 0u; _19841 < 4u; )
                            {
                                _8777[_19840][_19841] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8811 + (_19840 * 4u)) + _19841) * 4 + 0));
                                _19841++;
                                continue;
                            }
                        }
                        _19843 = true;
                        break;
                    } while(false);
                    if (_19843)
                    {
                        _19844 = _8777;
                        break;
                    }
                    _19844 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19845;
                do
                {
                    float _8888 = _5652.x;
                    float _8891 = 1.0f - _5652.y;
                    float4 _8902 = mul(float4((float2(_8888, _8891) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5652 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8763_dummy_parameter))))), 0)).x, 1.0f), _19844);
                    float _8904 = _8902.w;
                    if (!(_8904 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19845 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8917 = ((_8902.xy / _8904.xx) + 1.0f.xx) * 0.5f;
                    _19845 = float2(_8917.x - _8888, _8891 - _8917.y);
                    break;
                } while(false);
                float2 _8714 = abs(_19845);
                if (any(bool2(_8714.x > 100000.0f.xx.x, _8714.y > 100000.0f.xx.y)))
                {
                    _19846 = false;
                    break;
                }
                float _8722 = length(_19845 * _5654);
                uint _8937_dummy_parameter;
                bool _8736 = _8722 > ((8.0f * _5654.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8743;
                if (_8736)
                {
                    _8743 = length((r_motion_tp1.Load(int3(int2(floor(_5652 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8937_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5654) < (0.20000000298023223876953125f * _8722);
                }
                else
                {
                    _8743 = _8736;
                }
                _19846 = _8743;
                break;
            } while(false);
            float2 _5664 = _5396 + float2(_5646, _5650);
            bool _19853;
            do
            {
                bool _9023 = all(bool2(_5664.x > 0.0f.xx.x, _5664.y > 0.0f.xx.y));
                bool _9029;
                if (_9023)
                {
                    _9029 = all(bool2(_5664.x < 1.0f.xx.x, _5664.y < 1.0f.xx.y));
                }
                else
                {
                    _9029 = _9023;
                }
                if (!_9029)
                {
                    _19853 = false;
                    break;
                }
                uint _9036_dummy_parameter;
                float4x4 _19851;
                do
                {
                    float4x4 _9050;
                    bool _19850;
                    do
                    {
                        _9050 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19850 = false;
                            break;
                        }
                        uint _9084 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9084 + 32u) * 4 + 0) != 1u)
                        {
                            _19850 = false;
                            break;
                        }
                        uint _19847;
                        _19847 = 0u;
                        for (; _19847 < 4u; _19847++)
                        {
                            for (uint _19848 = 0u; _19848 < 4u; )
                            {
                                _9050[_19847][_19848] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9084 + (_19847 * 4u)) + _19848) * 4 + 0));
                                _19848++;
                                continue;
                            }
                        }
                        _19850 = true;
                        break;
                    } while(false);
                    if (_19850)
                    {
                        _19851 = _9050;
                        break;
                    }
                    _19851 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19852;
                do
                {
                    float _9161 = _5664.x;
                    float _9164 = 1.0f - _5664.y;
                    float4 _9175 = mul(float4((float2(_9161, _9164) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5664 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9036_dummy_parameter))))), 0)).x, 1.0f), _19851);
                    float _9177 = _9175.w;
                    if (!(_9177 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19852 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9190 = ((_9175.xy / _9177.xx) + 1.0f.xx) * 0.5f;
                    _19852 = float2(_9190.x - _9161, _9164 - _9190.y);
                    break;
                } while(false);
                float2 _8987 = abs(_19852);
                if (any(bool2(_8987.x > 100000.0f.xx.x, _8987.y > 100000.0f.xx.y)))
                {
                    _19853 = false;
                    break;
                }
                float _8995 = length(_19852 * _5654);
                uint _9210_dummy_parameter;
                bool _9009 = _8995 > ((8.0f * _5654.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9016;
                if (_9009)
                {
                    _9016 = length((r_motion_tp1.Load(int3(int2(floor(_5664 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9210_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5654) < (0.20000000298023223876953125f * _8995);
                }
                else
                {
                    _9016 = _9009;
                }
                _19853 = _9016;
                break;
            } while(false);
            float2 _5677 = _5396 + float2(_5647, _5649);
            bool _19860;
            do
            {
                bool _9296 = all(bool2(_5677.x > 0.0f.xx.x, _5677.y > 0.0f.xx.y));
                bool _9302;
                if (_9296)
                {
                    _9302 = all(bool2(_5677.x < 1.0f.xx.x, _5677.y < 1.0f.xx.y));
                }
                else
                {
                    _9302 = _9296;
                }
                if (!_9302)
                {
                    _19860 = false;
                    break;
                }
                uint _9309_dummy_parameter;
                float4x4 _19858;
                do
                {
                    float4x4 _9323;
                    bool _19857;
                    do
                    {
                        _9323 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19857 = false;
                            break;
                        }
                        uint _9357 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9357 + 32u) * 4 + 0) != 1u)
                        {
                            _19857 = false;
                            break;
                        }
                        uint _19854;
                        _19854 = 0u;
                        for (; _19854 < 4u; _19854++)
                        {
                            for (uint _19855 = 0u; _19855 < 4u; )
                            {
                                _9323[_19854][_19855] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9357 + (_19854 * 4u)) + _19855) * 4 + 0));
                                _19855++;
                                continue;
                            }
                        }
                        _19857 = true;
                        break;
                    } while(false);
                    if (_19857)
                    {
                        _19858 = _9323;
                        break;
                    }
                    _19858 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19859;
                do
                {
                    float _9434 = _5677.x;
                    float _9437 = 1.0f - _5677.y;
                    float4 _9448 = mul(float4((float2(_9434, _9437) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5677 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9309_dummy_parameter))))), 0)).x, 1.0f), _19858);
                    float _9450 = _9448.w;
                    if (!(_9450 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19859 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9463 = ((_9448.xy / _9450.xx) + 1.0f.xx) * 0.5f;
                    _19859 = float2(_9463.x - _9434, _9437 - _9463.y);
                    break;
                } while(false);
                float2 _9260 = abs(_19859);
                if (any(bool2(_9260.x > 100000.0f.xx.x, _9260.y > 100000.0f.xx.y)))
                {
                    _19860 = false;
                    break;
                }
                float _9268 = length(_19859 * _5654);
                uint _9483_dummy_parameter;
                bool _9282 = _9268 > ((8.0f * _5654.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9289;
                if (_9282)
                {
                    _9289 = length((r_motion_tp1.Load(int3(int2(floor(_5677 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9483_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5654) < (0.20000000298023223876953125f * _9268);
                }
                else
                {
                    _9289 = _9282;
                }
                _19860 = _9289;
                break;
            } while(false);
            float2 _5689 = _5396 + _5643;
            bool _19867;
            do
            {
                bool _9569 = all(bool2(_5689.x > 0.0f.xx.x, _5689.y > 0.0f.xx.y));
                bool _9575;
                if (_9569)
                {
                    _9575 = all(bool2(_5689.x < 1.0f.xx.x, _5689.y < 1.0f.xx.y));
                }
                else
                {
                    _9575 = _9569;
                }
                if (!_9575)
                {
                    _19867 = false;
                    break;
                }
                uint _9582_dummy_parameter;
                float4x4 _19865;
                do
                {
                    float4x4 _9596;
                    bool _19864;
                    do
                    {
                        _9596 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19864 = false;
                            break;
                        }
                        uint _9630 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9630 + 32u) * 4 + 0) != 1u)
                        {
                            _19864 = false;
                            break;
                        }
                        uint _19861;
                        _19861 = 0u;
                        for (; _19861 < 4u; _19861++)
                        {
                            for (uint _19862 = 0u; _19862 < 4u; )
                            {
                                _9596[_19861][_19862] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9630 + (_19861 * 4u)) + _19862) * 4 + 0));
                                _19862++;
                                continue;
                            }
                        }
                        _19864 = true;
                        break;
                    } while(false);
                    if (_19864)
                    {
                        _19865 = _9596;
                        break;
                    }
                    _19865 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19866;
                do
                {
                    float _9707 = _5689.x;
                    float _9710 = 1.0f - _5689.y;
                    float4 _9721 = mul(float4((float2(_9707, _9710) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5689 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9582_dummy_parameter))))), 0)).x, 1.0f), _19865);
                    float _9723 = _9721.w;
                    if (!(_9723 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19866 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9736 = ((_9721.xy / _9723.xx) + 1.0f.xx) * 0.5f;
                    _19866 = float2(_9736.x - _9707, _9710 - _9736.y);
                    break;
                } while(false);
                float2 _9533 = abs(_19866);
                if (any(bool2(_9533.x > 100000.0f.xx.x, _9533.y > 100000.0f.xx.y)))
                {
                    _19867 = false;
                    break;
                }
                float _9541 = length(_19866 * _5654);
                uint _9756_dummy_parameter;
                bool _9555 = _9541 > ((8.0f * _5654.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9562;
                if (_9555)
                {
                    _9562 = length((r_motion_tp1.Load(int3(int2(floor(_5689 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9756_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5654) < (0.20000000298023223876953125f * _9541);
                }
                else
                {
                    _9562 = _9555;
                }
                _19867 = _9562;
                break;
            } while(false);
            float _5695 = 0.25f * (((float(_19846) + float(_19853)) + float(_19860)) + float(_19867));
            float4 _20037;
            if (_5695 < 1.0f)
            {
                bool _19874;
                do
                {
                    bool _9842 = all(bool2(_19825.x > 0.0f.xx.x, _19825.y > 0.0f.xx.y));
                    bool _9848;
                    if (_9842)
                    {
                        _9848 = all(bool2(_19825.x < 1.0f.xx.x, _19825.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9848 = _9842;
                    }
                    if (!_9848)
                    {
                        _19874 = false;
                        break;
                    }
                    uint _9855_dummy_parameter;
                    float4x4 _19872;
                    do
                    {
                        float4x4 _9869;
                        bool _19871;
                        do
                        {
                            _9869 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19871 = false;
                                break;
                            }
                            uint _9903 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9903 + 32u) * 4 + 0) != 1u)
                            {
                                _19871 = false;
                                break;
                            }
                            uint _19868;
                            _19868 = 0u;
                            for (; _19868 < 4u; _19868++)
                            {
                                for (uint _19869 = 0u; _19869 < 4u; )
                                {
                                    _9869[_19868][_19869] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9903 + (_19868 * 4u)) + _19869) * 4 + 0));
                                    _19869++;
                                    continue;
                                }
                            }
                            _19871 = true;
                            break;
                        } while(false);
                        if (_19871)
                        {
                            _19872 = _9869;
                            break;
                        }
                        _19872 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19873;
                    do
                    {
                        float _9983 = 1.0f - _19825.y;
                        float4 _9994 = mul(float4((float2(_19825.x, _9983) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19825 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9855_dummy_parameter))))), 0)).x, 1.0f), _19872);
                        float _9996 = _9994.w;
                        if (!(_9996 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19873 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10009 = ((_9994.xy / _9996.xx) + 1.0f.xx) * 0.5f;
                        _19873 = float2(_10009.x - _19825.x, _9983 - _10009.y);
                        break;
                    } while(false);
                    float2 _9806 = abs(_19873);
                    if (any(bool2(_9806.x > 100000.0f.xx.x, _9806.y > 100000.0f.xx.y)))
                    {
                        _19874 = false;
                        break;
                    }
                    float _9814 = length(_19873 * _5654);
                    uint _10029_dummy_parameter;
                    bool _9828 = _9814 > ((8.0f * _5654.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9835;
                    if (_9828)
                    {
                        _9835 = length((r_motion_tp1.Load(int3(int2(floor(_19825 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10029_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5654) < (0.20000000298023223876953125f * _9814);
                    }
                    else
                    {
                        _9835 = _9828;
                    }
                    _19874 = _9835;
                    break;
                } while(false);
                bool _19881;
                do
                {
                    bool _10115 = all(bool2(_19827.x > 0.0f.xx.x, _19827.y > 0.0f.xx.y));
                    bool _10121;
                    if (_10115)
                    {
                        _10121 = all(bool2(_19827.x < 1.0f.xx.x, _19827.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10121 = _10115;
                    }
                    if (!_10121)
                    {
                        _19881 = false;
                        break;
                    }
                    uint _10128_dummy_parameter;
                    float4x4 _19879;
                    do
                    {
                        float4x4 _10142;
                        bool _19878;
                        do
                        {
                            _10142 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19878 = false;
                                break;
                            }
                            uint _10176 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10176 + 32u) * 4 + 0) != 1u)
                            {
                                _19878 = false;
                                break;
                            }
                            uint _19875;
                            _19875 = 0u;
                            for (; _19875 < 4u; _19875++)
                            {
                                for (uint _19876 = 0u; _19876 < 4u; )
                                {
                                    _10142[_19875][_19876] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10176 + (_19875 * 4u)) + _19876) * 4 + 0));
                                    _19876++;
                                    continue;
                                }
                            }
                            _19878 = true;
                            break;
                        } while(false);
                        if (_19878)
                        {
                            _19879 = _10142;
                            break;
                        }
                        _19879 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19880;
                    do
                    {
                        float _10256 = 1.0f - _19827.y;
                        float4 _10267 = mul(float4((float2(_19827.x, _10256) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19827 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10128_dummy_parameter))))), 0)).x, 1.0f), _19879);
                        float _10269 = _10267.w;
                        if (!(_10269 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19880 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10282 = ((_10267.xy / _10269.xx) + 1.0f.xx) * 0.5f;
                        _19880 = float2(_10282.x - _19827.x, _10256 - _10282.y);
                        break;
                    } while(false);
                    float2 _10079 = abs(_19880);
                    if (any(bool2(_10079.x > 100000.0f.xx.x, _10079.y > 100000.0f.xx.y)))
                    {
                        _19881 = false;
                        break;
                    }
                    float _10087 = length(_19880 * _5654);
                    uint _10302_dummy_parameter;
                    bool _10101 = _10087 > ((8.0f * _5654.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10108;
                    if (_10101)
                    {
                        _10108 = length((r_motion_tp1.Load(int3(int2(floor(_19827 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10302_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5654) < (0.20000000298023223876953125f * _10087);
                    }
                    else
                    {
                        _10108 = _10101;
                    }
                    _19881 = _10108;
                    break;
                } while(false);
                bool _19888;
                do
                {
                    bool _10388 = all(bool2(_19828.x > 0.0f.xx.x, _19828.y > 0.0f.xx.y));
                    bool _10394;
                    if (_10388)
                    {
                        _10394 = all(bool2(_19828.x < 1.0f.xx.x, _19828.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10394 = _10388;
                    }
                    if (!_10394)
                    {
                        _19888 = false;
                        break;
                    }
                    uint _10401_dummy_parameter;
                    float4x4 _19886;
                    do
                    {
                        float4x4 _10415;
                        bool _19885;
                        do
                        {
                            _10415 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19885 = false;
                                break;
                            }
                            uint _10449 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10449 + 32u) * 4 + 0) != 1u)
                            {
                                _19885 = false;
                                break;
                            }
                            uint _19882;
                            _19882 = 0u;
                            for (; _19882 < 4u; _19882++)
                            {
                                for (uint _19883 = 0u; _19883 < 4u; )
                                {
                                    _10415[_19882][_19883] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10449 + (_19882 * 4u)) + _19883) * 4 + 0));
                                    _19883++;
                                    continue;
                                }
                            }
                            _19885 = true;
                            break;
                        } while(false);
                        if (_19885)
                        {
                            _19886 = _10415;
                            break;
                        }
                        _19886 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19887;
                    do
                    {
                        float _10529 = 1.0f - _19828.y;
                        float4 _10540 = mul(float4((float2(_19828.x, _10529) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19828 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10401_dummy_parameter))))), 0)).x, 1.0f), _19886);
                        float _10542 = _10540.w;
                        if (!(_10542 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19887 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10555 = ((_10540.xy / _10542.xx) + 1.0f.xx) * 0.5f;
                        _19887 = float2(_10555.x - _19828.x, _10529 - _10555.y);
                        break;
                    } while(false);
                    float2 _10352 = abs(_19887);
                    if (any(bool2(_10352.x > 100000.0f.xx.x, _10352.y > 100000.0f.xx.y)))
                    {
                        _19888 = false;
                        break;
                    }
                    float _10360 = length(_19887 * _5654);
                    uint _10575_dummy_parameter;
                    bool _10374 = _10360 > ((8.0f * _5654.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10381;
                    if (_10374)
                    {
                        _10381 = length((r_motion_tp1.Load(int3(int2(floor(_19828 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10575_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5654) < (0.20000000298023223876953125f * _10360);
                    }
                    else
                    {
                        _10381 = _10374;
                    }
                    _19888 = _10381;
                    break;
                } while(false);
                bool _19895;
                do
                {
                    bool _10661 = all(bool2(_19829.x > 0.0f.xx.x, _19829.y > 0.0f.xx.y));
                    bool _10667;
                    if (_10661)
                    {
                        _10667 = all(bool2(_19829.x < 1.0f.xx.x, _19829.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10667 = _10661;
                    }
                    if (!_10667)
                    {
                        _19895 = false;
                        break;
                    }
                    uint _10674_dummy_parameter;
                    float4x4 _19893;
                    do
                    {
                        float4x4 _10688;
                        bool _19892;
                        do
                        {
                            _10688 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19892 = false;
                                break;
                            }
                            uint _10722 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10722 + 32u) * 4 + 0) != 1u)
                            {
                                _19892 = false;
                                break;
                            }
                            uint _19889;
                            _19889 = 0u;
                            for (; _19889 < 4u; _19889++)
                            {
                                for (uint _19890 = 0u; _19890 < 4u; )
                                {
                                    _10688[_19889][_19890] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10722 + (_19889 * 4u)) + _19890) * 4 + 0));
                                    _19890++;
                                    continue;
                                }
                            }
                            _19892 = true;
                            break;
                        } while(false);
                        if (_19892)
                        {
                            _19893 = _10688;
                            break;
                        }
                        _19893 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19894;
                    do
                    {
                        float _10802 = 1.0f - _19829.y;
                        float4 _10813 = mul(float4((float2(_19829.x, _10802) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19829 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10674_dummy_parameter))))), 0)).x, 1.0f), _19893);
                        float _10815 = _10813.w;
                        if (!(_10815 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19894 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10828 = ((_10813.xy / _10815.xx) + 1.0f.xx) * 0.5f;
                        _19894 = float2(_10828.x - _19829.x, _10802 - _10828.y);
                        break;
                    } while(false);
                    float2 _10625 = abs(_19894);
                    if (any(bool2(_10625.x > 100000.0f.xx.x, _10625.y > 100000.0f.xx.y)))
                    {
                        _19895 = false;
                        break;
                    }
                    float _10633 = length(_19894 * _5654);
                    uint _10848_dummy_parameter;
                    bool _10647 = _10633 > ((8.0f * _5654.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10654;
                    if (_10647)
                    {
                        _10654 = length((r_motion_tp1.Load(int3(int2(floor(_19829 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10848_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5654) < (0.20000000298023223876953125f * _10633);
                    }
                    else
                    {
                        _10654 = _10647;
                    }
                    _19895 = _10654;
                    break;
                } while(false);
                float4 _5722 = _8670 * float4(_19874 ? 0.0f : 1.0f, _19881 ? 0.0f : 1.0f, _19888 ? 0.0f : 1.0f, _19895 ? 0.0f : 1.0f);
                float _5724 = dot(_5722, 1.0f.xxxx);
                float4 _20038;
                if (_5724 > 0.001000000047497451305389404296875f)
                {
                    _20038 = _5722 / _5724.xxxx;
                }
                else
                {
                    _20038 = _8670;
                }
                _20037 = _20038;
            }
            else
            {
                _20037 = _8670;
            }
            _21344 = _5695;
            _20036 = _20037;
        }
        else
        {
            _21344 = 0.0f;
            _20036 = _8670;
        }
        bool _5741 = _5433 && (!_19965);
        bool _5750;
        if (_5741)
        {
            _5750 = (_20036.z + _20036.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5750 = _5741;
        }
        bool _5761;
        if (_5750)
        {
            _5761 = length((_19828 - _19825) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5761 = _5750;
        }
        bool _20125;
        if (_5761)
        {
            uint4 _10877 = r_warped_motion_qdata_tp1.Load(int3(_20046, 0));
            uint _10878 = _10877.x;
            bool _20128;
            if (_10878 != 0u)
            {
                float _20114;
                if (_10878 == 0u)
                {
                    _20114 = -1.0f;
                }
                else
                {
                    _20114 = float((_10878 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5771 = _20114 - 0.12000000476837158203125f;
                bool _10897 = all(bool2(_19828.x > 0.0f.xx.x, _19828.y > 0.0f.xx.y));
                bool _10903;
                if (_10897)
                {
                    _10903 = all(bool2(_19828.x < 1.0f.xx.x, _19828.y < 1.0f.xx.y));
                }
                else
                {
                    _10903 = _10897;
                }
                bool _5781;
                if (_10903)
                {
                    uint _10910_dummy_parameter;
                    _5781 = (log((r_depth_tm1.Load(int3(int2(floor(_19828 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10910_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5771;
                }
                else
                {
                    _5781 = _10903;
                }
                bool _5795;
                if (!_5781)
                {
                    bool _10940 = all(bool2(_19829.x > 0.0f.xx.x, _19829.y > 0.0f.xx.y));
                    bool _10946;
                    if (_10940)
                    {
                        _10946 = all(bool2(_19829.x < 1.0f.xx.x, _19829.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10946 = _10940;
                    }
                    bool _5793;
                    if (_10946)
                    {
                        uint _10953_dummy_parameter;
                        _5793 = (log((r_depth_tp1.Load(int3(int2(floor(_19829 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10953_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5771;
                    }
                    else
                    {
                        _5793 = _10946;
                    }
                    _5795 = _5793;
                }
                else
                {
                    _5795 = _5781;
                }
                _20128 = _5795;
            }
            else
            {
                _20128 = false;
            }
            _20125 = _20128;
        }
        else
        {
            _20125 = false;
        }
        bool _5800 = _19965 || _20125;
        bool _5805;
        if (_5800)
        {
            bool _10983 = all(bool2(_19825.x > 0.0f.xx.x, _19825.y > 0.0f.xx.y));
            bool _10989;
            if (_10983)
            {
                _10989 = all(bool2(_19825.x < 1.0f.xx.x, _19825.y < 1.0f.xx.y));
            }
            else
            {
                _10989 = _10983;
            }
            _5805 = _10989;
        }
        else
        {
            _5805 = _5800;
        }
        bool _5810;
        if (_5805)
        {
            bool _10994 = all(bool2(_19827.x > 0.0f.xx.x, _19827.y > 0.0f.xx.y));
            bool _11000;
            if (_10994)
            {
                _11000 = all(bool2(_19827.x < 1.0f.xx.x, _19827.y < 1.0f.xx.y));
            }
            else
            {
                _11000 = _10994;
            }
            _5810 = _11000;
        }
        else
        {
            _5810 = _5805;
        }
        float4 _20248;
        if (_5810)
        {
            float _5816 = _20036.x + _20036.y;
            float _5821 = _20036.z + _20036.w;
            float _20143;
            if (_5816 > 0.001000000047497451305389404296875f)
            {
                _20143 = _20036.x / _5816;
            }
            else
            {
                _20143 = _5621;
            }
            _20248 = float4(_20036.x + (_5821 * _20143), _20036.y + (_5821 * (1.0f - _20143)), 0.0f, 0.0f);
        }
        else
        {
            _20248 = _20036;
        }
        bool _11028 = (cbFI_pad0 & 1024u) != 0u;
        bool _11004 = !_11028;
        bool _11005 = !_11004;
        bool _11022;
        if (_11005)
        {
            _11022 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_20046.y * cbFI_MvDepthLaneSize.x) + _20046.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11022 = _11004;
        }
        bool _11054;
        if (_11005)
        {
            _11054 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5412.y * cbFI_FlowLaneSize.x) + _5412.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11054 = _11004;
        }
        float _5856 = float(_11054);
        bool _20269;
        float4 _20308;
        float3 _22064;
        if (_11028)
        {
            bool _5866;
            if (_11022)
            {
                _5866 = all(bool2(_19825.x > 0.0f.xx.x, _19825.y > 0.0f.xx.y));
            }
            else
            {
                _5866 = _11022;
            }
            bool _5872;
            if (_5866)
            {
                _5872 = all(bool2(_19825.x < 1.0f.xx.x, _19825.y < 1.0f.xx.y));
            }
            else
            {
                _5872 = _5866;
            }
            bool _5879;
            if (_11022)
            {
                _5879 = all(bool2(_19827.x > 0.0f.xx.x, _19827.y > 0.0f.xx.y));
            }
            else
            {
                _5879 = _11022;
            }
            bool _5885;
            if (_5879)
            {
                _5885 = all(bool2(_19827.x < 1.0f.xx.x, _19827.y < 1.0f.xx.y));
            }
            else
            {
                _5885 = _5879;
            }
            bool _5892;
            if (_11054)
            {
                _5892 = all(bool2(_19828.x > 0.0f.xx.x, _19828.y > 0.0f.xx.y));
            }
            else
            {
                _5892 = _11054;
            }
            bool _5898;
            if (_5892)
            {
                _5898 = all(bool2(_19828.x < 1.0f.xx.x, _19828.y < 1.0f.xx.y));
            }
            else
            {
                _5898 = _5892;
            }
            bool _5905;
            if (_11054)
            {
                _5905 = all(bool2(_19829.x > 0.0f.xx.x, _19829.y > 0.0f.xx.y));
            }
            else
            {
                _5905 = _11054;
            }
            bool _5911;
            if (_5905)
            {
                _5911 = all(bool2(_19829.x < 1.0f.xx.x, _19829.y < 1.0f.xx.y));
            }
            else
            {
                _5911 = _5905;
            }
            bool _5913 = !_11022;
            if (_5913)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11096;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11096);
                }
            }
            bool _5918 = !_11054;
            if (_5918)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11106;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11106);
                }
            }
            if (_11022 && _5918)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11116;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11116);
                }
            }
            if (_5913 && _11054)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11126;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11126);
                }
            }
            float _5937 = float(_5872);
            float _5939 = float(_5885);
            bool _5942 = _5898 && _5911;
            float _20177;
            if (_5942)
            {
                _20177 = 1.0f;
            }
            else
            {
                _20177 = (_5898 || _5911) ? 0.5f : 0.0f;
            }
            bool _20192;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5872)) && (!_5885))
            {
                bool _5972;
                if (_5942)
                {
                    float _20185;
                    do
                    {
                        bool _11210 = all(bool2(_19828.x > 0.0f.xx.x, _19828.y > 0.0f.xx.y));
                        bool _11216;
                        if (_11210)
                        {
                            _11216 = all(bool2(_19828.x < 1.0f.xx.x, _19828.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11216 = _11210;
                        }
                        bool _11147 = !_11216;
                        bool _11154;
                        if (!_11147)
                        {
                            bool _11221 = all(bool2(_19829.x > 0.0f.xx.x, _19829.y > 0.0f.xx.y));
                            bool _11227;
                            if (_11221)
                            {
                                _11227 = all(bool2(_19829.x < 1.0f.xx.x, _19829.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11227 = _11221;
                            }
                            _11154 = !_11227;
                        }
                        else
                        {
                            _11154 = _11147;
                        }
                        if (_11154)
                        {
                            _20185 = 0.0f;
                            break;
                        }
                        uint _11234_dummy_parameter;
                        uint _11250_dummy_parameter;
                        float4x4 _20184;
                        do
                        {
                            float4x4 _11264;
                            bool _20183;
                            do
                            {
                                _11264 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20183 = false;
                                    break;
                                }
                                uint _11298 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11298 + 32u) * 4 + 0) != 1u)
                                {
                                    _20183 = false;
                                    break;
                                }
                                uint _20180;
                                _20180 = 0u;
                                for (; _20180 < 4u; _20180++)
                                {
                                    for (uint _20181 = 0u; _20181 < 4u; )
                                    {
                                        _11264[_20180][_20181] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11298 + 16u) + (_20180 * 4u)) + _20181) * 4 + 0));
                                        _20181++;
                                        continue;
                                    }
                                }
                                _20183 = true;
                                break;
                            } while(false);
                            if (_20183)
                            {
                                _20184 = _11264;
                                break;
                            }
                            _20184 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11175 = mul(float4((float2(_19828.x, 1.0f - _19828.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19828 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11234_dummy_parameter))))), 0)).x, 1.0f), _20184);
                        float _11177 = _11175.w;
                        if (abs(_11177) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20185 = 0.0f;
                            break;
                        }
                        float _11188 = abs(cbFI_DeviceToViewDepth.y / ((_11175.z / _11177) - cbFI_DeviceToViewDepth.x));
                        float _11191 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19829 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11250_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20185 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11188 - _11191) / max(max(_11188, _11191), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5972 = _20185 >= 0.5f;
                }
                else
                {
                    _5972 = _5942;
                }
                bool _5980;
                if (_5972)
                {
                    _5980 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5980 = _5972;
                }
                bool _20193;
                if (_5980)
                {
                    uint _11402_dummy_parameter;
                    float4x4 _20190;
                    do
                    {
                        float4x4 _11416;
                        bool _20189;
                        do
                        {
                            _11416 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20189 = false;
                                break;
                            }
                            uint _11450 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11450 + 32u) * 4 + 0) != 1u)
                            {
                                _20189 = false;
                                break;
                            }
                            uint _20186;
                            _20186 = 0u;
                            for (; _20186 < 4u; _20186++)
                            {
                                for (uint _20187 = 0u; _20187 < 4u; )
                                {
                                    _11416[_20186][_20187] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11450 + 16u) + (_20186 * 4u)) + _20187) * 4 + 0));
                                    _20187++;
                                    continue;
                                }
                            }
                            _20189 = true;
                            break;
                        } while(false);
                        if (_20189)
                        {
                            _20190 = _11416;
                            break;
                        }
                        _20190 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20191;
                    do
                    {
                        float _11530 = 1.0f - _19828.y;
                        float4 _11541 = mul(float4((float2(_19828.x, _11530) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19828 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11402_dummy_parameter))))), 0)).x, 1.0f), _20190);
                        float _11543 = _11541.w;
                        if (!(_11543 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20191 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11556 = ((_11541.xy / _11543.xx) + 1.0f.xx) * 0.5f;
                        _20191 = float2(_11556.x - _19828.x, _11530 - _11556.y);
                        break;
                    } while(false);
                    float2 _5993 = float2(cbFI_DisplaySize);
                    _20193 = length(((_19828 + _20191) - _19829) * _5993) <= ((0.100000001490116119384765625f * length(_20191 * _5993)) + 8.0f);
                }
                else
                {
                    _20193 = _5972;
                }
                _20192 = _20193;
            }
            else
            {
                _20192 = true;
            }
            bool _6007 = !_20192;
            bool _23720 = _6007 ? false : _5911;
            bool _23721 = _6007 ? false : _5898;
            bool _20270;
            float4 _20309;
            if (!(((_5872 && _5885) && _23721) && _23720))
            {
                float4 _6029 = _20248 * float4(_5937, _5939, float(_23721), float(_23720));
                float _6031 = dot(_6029, 1.0f.xxxx);
                bool _6034 = !(_6031 > 0.0f);
                float4 _20310;
                if (!_6034)
                {
                    _20310 = _6029 / _6031.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11578;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11578);
                    }
                    _20310 = 0.0f.xxxx;
                }
                _20309 = _20310;
                _20270 = _6034;
            }
            else
            {
                _20309 = _20248;
                _20270 = false;
            }
            _22064 = float3(_5937, _5939, _20177);
            _20308 = _20309;
            _20269 = _20270;
        }
        else
        {
            _22064 = float3(float(_11022), _5856, 0.0f);
            _20308 = _20248;
            _20269 = false;
        }
        bool _6052 = !_20269;
        float4 _20401;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6052)
        {
            float _6059 = _20308.x + _20308.y;
            float4 _20402;
            if (_6059 > 0.001000000047497451305389404296875f)
            {
                _20402 = float4(_20308.x / _6059, _20308.y / _6059, 0.0f, 0.0f);
            }
            else
            {
                _20402 = float4(_5621, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20401 = _20402;
        }
        else
        {
            _20401 = _20308;
        }
        float4 _20578;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6052) && _11022)
        {
            float _20375;
            do
            {
                uint4 _11718 = r_warped_motion_qdata_tp1.Load(int3(_20046, 0));
                uint _11719 = _11718.x;
                if (_11719 != 0u)
                {
                    float _20374;
                    if (_11719 == 0u)
                    {
                        _20374 = -1.0f;
                    }
                    else
                    {
                        _20374 = float((_11719 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20375 = _20374;
                    break;
                }
                int _20357;
                uint _20358;
                _20358 = _11719;
                _20357 = -1;
                uint _20373;
                for (; _20357 <= 1; _20358 = _20373, _20357++)
                {
                    _20373 = _20358;
                    for (int _20371 = -1; _20371 <= 1; )
                    {
                        _20373 = max(_20373, r_warped_motion_qdata_tp1.Load(int3(clamp(_20046 + int2(_20371, _20357), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20371++;
                        continue;
                    }
                }
                if (_20358 != 0u)
                {
                    float _20370;
                    if (_20358 == 0u)
                    {
                        _20370 = -1.0f;
                    }
                    else
                    {
                        _20370 = float((_20358 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20375 = _20370;
                    break;
                }
                uint _20360;
                _20360 = 4294967295u;
                uint _23353;
                for (int _20359 = 0; _20359 < 8; _20360 = _23353, _20359++)
                {
                    int _20363 = 0;
                    for (;;)
                    {
                        if (_20363 < 5)
                        {
                            int2 _11669 = _20046 + (_1248[_20359] * _1257[_20363].xx);
                            bool _11672 = any(bool2(_11669.x < int2(0, 0).x, _11669.y < int2(0, 0).y));
                            bool _11680;
                            if (!_11672)
                            {
                                _11680 = any(bool2(_11669.x >= cbFI_MvDepthLaneSize.x, _11669.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11680 = _11672;
                            }
                            if (_11680)
                            {
                                _23353 = _20360;
                                break;
                            }
                            uint4 _11758 = r_warped_motion_qdata_tp1.Load(int3(_11669, 0));
                            uint _11759 = _11758.x;
                            if (_11759 != 0u)
                            {
                                _23353 = min(_20360, _11759);
                                break;
                            }
                            _20363++;
                            continue;
                        }
                        else
                        {
                            _23353 = _20360;
                            break;
                        }
                    }
                }
                float _20362;
                if (_20360 == 4294967295u)
                {
                    _20362 = -1.0f;
                }
                else
                {
                    float _20361;
                    if (_20360 == 0u)
                    {
                        _20361 = -1.0f;
                    }
                    else
                    {
                        _20361 = float((_20360 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20362 = _20361;
                }
                _20375 = _20362;
                break;
            } while(false);
            float _6095 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6098 = r_warped_motion_qdata_tp1.Load(int3(_20046, 0)).x == 0u;
            bool _6104;
            if (_6098)
            {
                bool _11784 = all(bool2(_19825.x > 0.0f.xx.x, _19825.y > 0.0f.xx.y));
                bool _11790;
                if (_11784)
                {
                    _11790 = all(bool2(_19825.x < 1.0f.xx.x, _19825.y < 1.0f.xx.y));
                }
                else
                {
                    _11790 = _11784;
                }
                _6104 = _11790;
            }
            else
            {
                _6104 = _6098;
            }
            bool _6109;
            if (_6104)
            {
                bool _11795 = all(bool2(_19827.x > 0.0f.xx.x, _19827.y > 0.0f.xx.y));
                bool _11801;
                if (_11795)
                {
                    _11801 = all(bool2(_19827.x < 1.0f.xx.x, _19827.y < 1.0f.xx.y));
                }
                else
                {
                    _11801 = _11795;
                }
                _6109 = _11801;
            }
            else
            {
                _6109 = _6104;
            }
            bool _20387;
            float4 _20396;
            if (_6109)
            {
                uint _11808_dummy_parameter;
                float _11832 = log((r_depth_tm1.Load(int3(int2(floor(_19825 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11808_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _11840_dummy_parameter;
                float _11864 = log((r_depth_tp1.Load(int3(int2(floor(_19827 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11840_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _6120 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6127;
                if (_6120)
                {
                    _6127 = _11864 > (_11832 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6127 = _6120;
                }
                bool _20392;
                float4 _20414;
                if (_6127)
                {
                    _20414 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20392 = true;
                }
                else
                {
                    bool _6133 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6140;
                    if (_6133)
                    {
                        _6140 = _11832 > (_11864 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6140 = _6133;
                    }
                    bool4 _23722 = _6140.xxxx;
                    _20414 = float4(_23722.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20401.x, _23722.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20401.y, _23722.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20401.z, _23722.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20401.w);
                    _20392 = _6140 ? true : false;
                }
                _20396 = _20414;
                _20387 = _20392;
            }
            else
            {
                _20396 = _20401;
                _20387 = false;
            }
            float4 _20469;
            if (_20387)
            {
                _20469 = 1.0f.xxxx;
            }
            else
            {
                bool _6151 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6157;
                if (_6151)
                {
                    _6157 = _20396.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6157 = _6151;
                }
                bool _6162;
                if (_6157)
                {
                    bool _11870 = all(bool2(_19827.x > 0.0f.xx.x, _19827.y > 0.0f.xx.y));
                    bool _11876;
                    if (_11870)
                    {
                        _11876 = all(bool2(_19827.x < 1.0f.xx.x, _19827.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11876 = _11870;
                    }
                    _6162 = _11876;
                }
                else
                {
                    _6162 = _6157;
                }
                float4 _20470;
                if (_6162)
                {
                    float _20423;
                    if (_20375 >= 0.0f)
                    {
                        _20423 = _20375 - _6095;
                    }
                    else
                    {
                        float _20419;
                        _20419 = 2.0f;
                        float _11933;
                        for (int _20418 = 0; _20418 < 24; _20419 = _11933, _20418++)
                        {
                            float _11897 = float(_20418 & 7) * 0.785398185253143310546875f;
                            int _11899 = _20418 >> 3;
                            int _20420;
                            if (_11899 == 0)
                            {
                                _20420 = 16;
                            }
                            else
                            {
                                _20420 = (_11899 == 1) ? 48 : 96;
                            }
                            uint _11965_dummy_parameter;
                            _11933 = min(_20419, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19827 + ((cbFI_MvDepthLaneSizeRcp * float(_20420)) * float2(cos(_11897), sin(_11897))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11965_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20423 = _20419;
                    }
                    uint _11997_dummy_parameter;
                    float4 _20471;
                    if (r_depth_tp1.Load(int3(int2(floor(_19827 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11997_dummy_parameter))))), 0)).x > ((exp((_20423 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20471 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20471 = 1.0f.xxxx;
                    }
                    _20470 = _20471;
                }
                else
                {
                    _20470 = 1.0f.xxxx;
                }
                _20469 = _20470;
            }
            bool _6190 = _20375 >= 0.0f;
            bool _6191 = (!_20387) && _6190;
            bool _6198;
            if (_6191)
            {
                _6198 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6198 = _6191;
            }
            bool _6204;
            if (_6198)
            {
                _6204 = _20396.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6204 = _6198;
            }
            bool _6209;
            if (_6204)
            {
                bool _12021 = all(bool2(_19825.x > 0.0f.xx.x, _19825.y > 0.0f.xx.y));
                bool _12027;
                if (_12021)
                {
                    _12027 = all(bool2(_19825.x < 1.0f.xx.x, _19825.y < 1.0f.xx.y));
                }
                else
                {
                    _12027 = _12021;
                }
                _6209 = _12027;
            }
            else
            {
                _6209 = _6204;
            }
            float4 _20494;
            if (_6209)
            {
                float _20463;
                if (_6190)
                {
                    _20463 = _20375 - _6095;
                }
                else
                {
                    float _20459;
                    _20459 = 2.0f;
                    float _12084;
                    for (int _20458 = 0; _20458 < 24; _20459 = _12084, _20458++)
                    {
                        float _12048 = float(_20458 & 7) * 0.785398185253143310546875f;
                        int _12050 = _20458 >> 3;
                        int _20460;
                        if (_12050 == 0)
                        {
                            _20460 = 16;
                        }
                        else
                        {
                            _20460 = (_12050 == 1) ? 48 : 96;
                        }
                        uint _12100_dummy_parameter;
                        _12084 = min(_20459, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19825 + ((cbFI_MvDepthLaneSizeRcp * float(_20460)) * float2(cos(_12048), sin(_12048))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12100_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20463 = _20459;
                }
                uint _12148_dummy_parameter;
                float4 _20495;
                if (r_depth_tm1.Load(int3(int2(floor(_19825 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12148_dummy_parameter))))), 0)).x > ((exp((_20463 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19521 = _20469;
                    _19521.x = 0.0f;
                    _20495 = _19521;
                }
                else
                {
                    _20495 = _20469;
                }
                _20494 = _20495;
            }
            else
            {
                _20494 = _20469;
            }
            float4 _20507;
            if (_6191)
            {
                float _12174 = (exp(((_20375 - _6095) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6247 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6253;
                if (_6247)
                {
                    _6253 = _20396.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6253 = _6247;
                }
                bool _6258;
                if (_6253)
                {
                    bool _12179 = all(bool2(_19829.x > 0.0f.xx.x, _19829.y > 0.0f.xx.y));
                    bool _12185;
                    if (_12179)
                    {
                        _12185 = all(bool2(_19829.x < 1.0f.xx.x, _19829.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12185 = _12179;
                    }
                    _6258 = _12185;
                }
                else
                {
                    _6258 = _6253;
                }
                bool _6266;
                if (_6258)
                {
                    uint _12192_dummy_parameter;
                    _6266 = r_depth_tp1.Load(int3(int2(floor(_19829 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12192_dummy_parameter))))), 0)).x > _12174;
                }
                else
                {
                    _6266 = _6258;
                }
                float4 _20505;
                if (_6266)
                {
                    float4 _19524 = _20494;
                    _19524.w = 0.0f;
                    _20505 = _19524;
                }
                else
                {
                    _20505 = _20494;
                }
                bool _6273 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6279;
                if (_6273)
                {
                    _6279 = _20396.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6279 = _6273;
                }
                bool _6284;
                if (_6279)
                {
                    bool _12209 = all(bool2(_19828.x > 0.0f.xx.x, _19828.y > 0.0f.xx.y));
                    bool _12215;
                    if (_12209)
                    {
                        _12215 = all(bool2(_19828.x < 1.0f.xx.x, _19828.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12215 = _12209;
                    }
                    _6284 = _12215;
                }
                else
                {
                    _6284 = _6279;
                }
                bool _6292;
                if (_6284)
                {
                    uint _12222_dummy_parameter;
                    _6292 = r_depth_tm1.Load(int3(int2(floor(_19828 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12222_dummy_parameter))))), 0)).x > _12174;
                }
                else
                {
                    _6292 = _6284;
                }
                float4 _20508;
                if (_6292)
                {
                    float4 _19527 = _20505;
                    _19527.z = 0.0f;
                    _20508 = _19527;
                }
                else
                {
                    _20508 = _20505;
                }
                _20507 = _20508;
            }
            else
            {
                _20507 = _20494;
            }
            float4 _20579;
            if (any(bool4(_20507.x < 1.0f.xxxx.x, _20507.y < 1.0f.xxxx.y, _20507.z < 1.0f.xxxx.z, _20507.w < 1.0f.xxxx.w)))
            {
                float4 _6303 = _20396 * _20507;
                float _6305 = dot(_6303, 1.0f.xxxx);
                float4 _20580;
                if (_6305 > 0.0f)
                {
                    _20580 = _6303 / _6305.xxxx;
                }
                else
                {
                    bool _6316 = _20507.y == 0.0f;
                    bool _6322;
                    if (_6316)
                    {
                        _6322 = _20507.x > 0.0f;
                    }
                    else
                    {
                        _6322 = _6316;
                    }
                    bool _6327;
                    if (_6322)
                    {
                        bool _12239 = all(bool2(_19825.x > 0.0f.xx.x, _19825.y > 0.0f.xx.y));
                        bool _12245;
                        if (_12239)
                        {
                            _12245 = all(bool2(_19825.x < 1.0f.xx.x, _19825.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12245 = _12239;
                        }
                        _6327 = _12245;
                    }
                    else
                    {
                        _6327 = _6322;
                    }
                    float4 _20581;
                    if (_6327)
                    {
                        _20581 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6332 = _20507.x == 0.0f;
                        bool _6338;
                        if (_6332)
                        {
                            _6338 = _20507.y > 0.0f;
                        }
                        else
                        {
                            _6338 = _6332;
                        }
                        bool _6343;
                        if (_6338)
                        {
                            bool _12250 = all(bool2(_19827.x > 0.0f.xx.x, _19827.y > 0.0f.xx.y));
                            bool _12256;
                            if (_12250)
                            {
                                _12256 = all(bool2(_19827.x < 1.0f.xx.x, _19827.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12256 = _12250;
                            }
                            _6343 = _12256;
                        }
                        else
                        {
                            _6343 = _6338;
                        }
                        bool4 _23725 = _6343.xxxx;
                        _20581 = float4(_23725.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20396.x, _23725.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20396.y, _23725.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20396.z, _23725.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20396.w);
                    }
                    _20580 = _20581;
                }
                _20579 = _20580;
            }
            else
            {
                _20579 = _20396;
            }
            _20578 = _20579;
        }
        else
        {
            _20578 = _20401;
        }
        float4 _21308;
        bool _21614;
        float3 _21804;
        if (((cbFI_pad0 & 32768u) != 0u) && _6052)
        {
            bool _6360 = _20578.x > 0.00999999977648258209228515625f;
            bool _6363 = _20578.y > 0.00999999977648258209228515625f;
            bool _6372 = (_20578.z + _20578.w) > 0.0199999995529651641845703125f;
            bool _6378;
            if (_6372)
            {
                bool _12261 = all(bool2(_19828.x > 0.0f.xx.x, _19828.y > 0.0f.xx.y));
                bool _12267;
                if (_12261)
                {
                    _12267 = all(bool2(_19828.x < 1.0f.xx.x, _19828.y < 1.0f.xx.y));
                }
                else
                {
                    _12267 = _12261;
                }
                _6378 = _12267;
            }
            else
            {
                _6378 = _6372;
            }
            bool _6383;
            if (_6378)
            {
                bool _12272 = all(bool2(_19829.x > 0.0f.xx.x, _19829.y > 0.0f.xx.y));
                bool _12278;
                if (_12272)
                {
                    _12278 = all(bool2(_19829.x < 1.0f.xx.x, _19829.y < 1.0f.xx.y));
                }
                else
                {
                    _12278 = _12272;
                }
                _6383 = _12278;
            }
            else
            {
                _6383 = _6378;
            }
            bool _6390;
            if (_6383)
            {
                float _20594;
                do
                {
                    bool _12361 = all(bool2(_19828.x > 0.0f.xx.x, _19828.y > 0.0f.xx.y));
                    bool _12367;
                    if (_12361)
                    {
                        _12367 = all(bool2(_19828.x < 1.0f.xx.x, _19828.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12367 = _12361;
                    }
                    bool _12298 = !_12367;
                    bool _12305;
                    if (!_12298)
                    {
                        bool _12372 = all(bool2(_19829.x > 0.0f.xx.x, _19829.y > 0.0f.xx.y));
                        bool _12378;
                        if (_12372)
                        {
                            _12378 = all(bool2(_19829.x < 1.0f.xx.x, _19829.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12378 = _12372;
                        }
                        _12305 = !_12378;
                    }
                    else
                    {
                        _12305 = _12298;
                    }
                    if (_12305)
                    {
                        _20594 = 0.0f;
                        break;
                    }
                    uint _12385_dummy_parameter;
                    uint _12401_dummy_parameter;
                    float4x4 _20593;
                    do
                    {
                        float4x4 _12415;
                        bool _20592;
                        do
                        {
                            _12415 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20592 = false;
                                break;
                            }
                            uint _12449 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12449 + 32u) * 4 + 0) != 1u)
                            {
                                _20592 = false;
                                break;
                            }
                            uint _20589;
                            _20589 = 0u;
                            for (; _20589 < 4u; _20589++)
                            {
                                for (uint _20590 = 0u; _20590 < 4u; )
                                {
                                    _12415[_20589][_20590] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12449 + 16u) + (_20589 * 4u)) + _20590) * 4 + 0));
                                    _20590++;
                                    continue;
                                }
                            }
                            _20592 = true;
                            break;
                        } while(false);
                        if (_20592)
                        {
                            _20593 = _12415;
                            break;
                        }
                        _20593 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12326 = mul(float4((float2(_19828.x, 1.0f - _19828.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19828 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12385_dummy_parameter))))), 0)).x, 1.0f), _20593);
                    float _12328 = _12326.w;
                    if (abs(_12328) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20594 = 0.0f;
                        break;
                    }
                    float _12339 = abs(cbFI_DeviceToViewDepth.y / ((_12326.z / _12328) - cbFI_DeviceToViewDepth.x));
                    float _12342 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19829 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12401_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20594 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12339 - _12342) / max(max(_12339, _12342), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6390 = _20594 < 0.5f;
            }
            else
            {
                _6390 = _6383;
            }
            float4 _20613;
            if (_6390)
            {
                uint _12553_dummy_parameter;
                uint _12584_dummy_parameter;
                float4 _20614;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19828 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12553_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19829 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12584_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20614 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20614 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20613 = _20614;
            }
            else
            {
                _20613 = 1.0f.xxxx;
            }
            bool _6414;
            if (_11022)
            {
                bool _12613 = all(bool2(_19825.x > 0.0f.xx.x, _19825.y > 0.0f.xx.y));
                bool _12619;
                if (_12613)
                {
                    _12619 = all(bool2(_19825.x < 1.0f.xx.x, _19825.y < 1.0f.xx.y));
                }
                else
                {
                    _12619 = _12613;
                }
                _6414 = _12619;
            }
            else
            {
                _6414 = _11022;
            }
            bool _6420;
            if (_11022)
            {
                bool _12624 = all(bool2(_19827.x > 0.0f.xx.x, _19827.y > 0.0f.xx.y));
                bool _12630;
                if (_12624)
                {
                    _12630 = all(bool2(_19827.x < 1.0f.xx.x, _19827.y < 1.0f.xx.y));
                }
                else
                {
                    _12630 = _12624;
                }
                _6420 = _12630;
            }
            else
            {
                _6420 = _11022;
            }
            bool _6426;
            if (_11054)
            {
                bool _12635 = all(bool2(_19828.x > 0.0f.xx.x, _19828.y > 0.0f.xx.y));
                bool _12641;
                if (_12635)
                {
                    _12641 = all(bool2(_19828.x < 1.0f.xx.x, _19828.y < 1.0f.xx.y));
                }
                else
                {
                    _12641 = _12635;
                }
                _6426 = _12641;
            }
            else
            {
                _6426 = _11054;
            }
            bool _6432;
            if (_11054)
            {
                bool _12646 = all(bool2(_19829.x > 0.0f.xx.x, _19829.y > 0.0f.xx.y));
                bool _12652;
                if (_12646)
                {
                    _12652 = all(bool2(_19829.x < 1.0f.xx.x, _19829.y < 1.0f.xx.y));
                }
                else
                {
                    _12652 = _12646;
                }
                _6432 = _12652;
            }
            else
            {
                _6432 = _11054;
            }
            bool _6435 = _6426 != _6432;
            bool _6441;
            if (_6435)
            {
                _6441 = _6414 || _6420;
            }
            else
            {
                _6441 = _6435;
            }
            float4 _20716;
            if (_6441)
            {
                float4 _19554 = _20613;
                _19554.z = 0.0f;
                _19554.w = 0.0f;
                _20716 = _19554;
            }
            else
            {
                _20716 = _20613;
            }
            bool _6448 = _6414 && _6360;
            bool _6451 = _6420 && _6363;
            float4 _20821;
            float3 _21913;
            if (_6448 || _6451)
            {
                float _20711;
                do
                {
                    uint4 _12791 = r_warped_motion_qdata_tp1.Load(int3(_20046, 0));
                    uint _12792 = _12791.x;
                    if (_12792 != 0u)
                    {
                        float _20710;
                        if (_12792 == 0u)
                        {
                            _20710 = -1.0f;
                        }
                        else
                        {
                            _20710 = float((_12792 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20711 = _20710;
                        break;
                    }
                    int _20693;
                    uint _20694;
                    _20694 = _12792;
                    _20693 = -1;
                    uint _20709;
                    for (; _20693 <= 1; _20694 = _20709, _20693++)
                    {
                        _20709 = _20694;
                        for (int _20707 = -1; _20707 <= 1; )
                        {
                            _20709 = max(_20709, r_warped_motion_qdata_tp1.Load(int3(clamp(_20046 + int2(_20707, _20693), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20707++;
                            continue;
                        }
                    }
                    if (_20694 != 0u)
                    {
                        float _20706;
                        if (_20694 == 0u)
                        {
                            _20706 = -1.0f;
                        }
                        else
                        {
                            _20706 = float((_20694 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20711 = _20706;
                        break;
                    }
                    uint _20696;
                    _20696 = 4294967295u;
                    uint _23354;
                    for (int _20695 = 0; _20695 < 8; _20696 = _23354, _20695++)
                    {
                        int _20699 = 0;
                        for (;;)
                        {
                            if (_20699 < 5)
                            {
                                int2 _12742 = _20046 + (_1248[_20695] * _1257[_20699].xx);
                                bool _12745 = any(bool2(_12742.x < int2(0, 0).x, _12742.y < int2(0, 0).y));
                                bool _12753;
                                if (!_12745)
                                {
                                    _12753 = any(bool2(_12742.x >= cbFI_MvDepthLaneSize.x, _12742.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12753 = _12745;
                                }
                                if (_12753)
                                {
                                    _23354 = _20696;
                                    break;
                                }
                                uint4 _12831 = r_warped_motion_qdata_tp1.Load(int3(_12742, 0));
                                uint _12832 = _12831.x;
                                if (_12832 != 0u)
                                {
                                    _23354 = min(_20696, _12832);
                                    break;
                                }
                                _20699++;
                                continue;
                            }
                            else
                            {
                                _23354 = _20696;
                                break;
                            }
                        }
                    }
                    float _20698;
                    if (_20696 == 4294967295u)
                    {
                        _20698 = -1.0f;
                    }
                    else
                    {
                        float _20697;
                        if (_20696 == 0u)
                        {
                            _20697 = -1.0f;
                        }
                        else
                        {
                            _20697 = float((_20696 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20698 = _20697;
                    }
                    _20711 = _20698;
                    break;
                } while(false);
                bool _6459 = _20711 < 0.0f;
                float _20712;
                if (_6459)
                {
                    _20712 = 0.0f;
                }
                else
                {
                    _20712 = _20711 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12853_dummy_parameter;
                uint _12885_dummy_parameter;
                float4 _20749;
                if ((_6459 && _6448) && _6451)
                {
                    uint _12917_dummy_parameter;
                    float _12941 = log((r_depth_tm1.Load(int3(int2(floor(_19825 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12917_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12949_dummy_parameter;
                    float _12973 = log((r_depth_tp1.Load(int3(int2(floor(_19827 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12949_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20750;
                    if (_12941 > (_12973 + 0.07999999821186065673828125f))
                    {
                        float4 _19558 = _20716;
                        _19558.x = 0.0f;
                        _20750 = _19558;
                    }
                    else
                    {
                        float4 _20751;
                        if (_12973 > (_12941 + 0.07999999821186065673828125f))
                        {
                            float4 _19560 = _20716;
                            _19560.y = 0.0f;
                            _20751 = _19560;
                        }
                        else
                        {
                            _20751 = _20716;
                        }
                        _20750 = _20751;
                    }
                    _20749 = _20750;
                }
                else
                {
                    _20749 = _20716;
                }
                float _6511 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6513 = _20711 >= 0.0f;
                float _20732;
                if (_6513)
                {
                    _20732 = _20711 - _6511;
                }
                else
                {
                    float _20728;
                    if (_6448)
                    {
                        float _20727;
                        _20727 = 2.0f;
                        float _13031;
                        for (int _20726 = 0; _20726 < 24; _20727 = _13031, _20726++)
                        {
                            float _12995 = float(_20726 & 7) * 0.785398185253143310546875f;
                            int _12997 = _20726 >> 3;
                            int _20729;
                            if (_12997 == 0)
                            {
                                _20729 = 16;
                            }
                            else
                            {
                                _20729 = (_12997 == 1) ? 48 : 96;
                            }
                            uint _13047_dummy_parameter;
                            _13031 = min(_20727, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19825 + ((cbFI_MvDepthLaneSizeRcp * float(_20729)) * float2(cos(_12995), sin(_12995))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13047_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20728 = _20727;
                    }
                    else
                    {
                        _20728 = 0.0f;
                    }
                    _20732 = _20728;
                }
                float _20739;
                if (_6513)
                {
                    _20739 = _20711 - _6511;
                }
                else
                {
                    float _20735;
                    if (_6451)
                    {
                        float _20734;
                        _20734 = 2.0f;
                        float _13145;
                        for (int _20733 = 0; _20733 < 24; _20734 = _13145, _20733++)
                        {
                            float _13109 = float(_20733 & 7) * 0.785398185253143310546875f;
                            int _13111 = _20733 >> 3;
                            int _20736;
                            if (_13111 == 0)
                            {
                                _20736 = 16;
                            }
                            else
                            {
                                _20736 = (_13111 == 1) ? 48 : 96;
                            }
                            uint _13177_dummy_parameter;
                            _13145 = min(_20734, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19827 + ((cbFI_MvDepthLaneSizeRcp * float(_20736)) * float2(cos(_13109), sin(_13109))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13177_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20735 = _20734;
                    }
                    else
                    {
                        _20735 = 0.0f;
                    }
                    _20739 = _20735;
                }
                float _20740;
                if (_6448)
                {
                    uint _13209_dummy_parameter;
                    _20740 = r_depth_tm1.Load(int3(int2(floor(_19825 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13209_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20740 = 0.0f;
                }
                float _20741;
                if (_6451)
                {
                    uint _13228_dummy_parameter;
                    _20741 = r_depth_tp1.Load(int3(int2(floor(_19827 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13228_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20741 = 0.0f;
                }
                bool _6568;
                if (_6448)
                {
                    _6568 = _20740 > ((exp((_20732 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6568 = _6448;
                }
                float4 _20757;
                if (_6568)
                {
                    float4 _19562 = _20749;
                    _19562.x = 0.0f;
                    _20757 = _19562;
                }
                else
                {
                    _20757 = _20749;
                }
                bool _6580;
                if (_6451)
                {
                    _6580 = _20741 > ((exp((_20739 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6580 = _6451;
                }
                float4 _20759;
                if (_6580)
                {
                    float4 _19564 = _20757;
                    _19564.y = 0.0f;
                    _20759 = _19564;
                }
                else
                {
                    _20759 = _20757;
                }
                float4 _20822;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6513)
                {
                    bool _6600;
                    if (_6448)
                    {
                        _6600 = _20740 < ((exp((_20732 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6600 = _6448;
                    }
                    float4 _20761;
                    if (_6600)
                    {
                        float4 _19566 = _20759;
                        _19566.x = 0.0f;
                        _20761 = _19566;
                    }
                    else
                    {
                        _20761 = _20759;
                    }
                    bool _6612;
                    if (_6451)
                    {
                        _6612 = _20741 < ((exp((_20739 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6612 = _6451;
                    }
                    float4 _20823;
                    if (_6612)
                    {
                        float4 _19568 = _20761;
                        _19568.y = 0.0f;
                        _20823 = _19568;
                    }
                    else
                    {
                        _20823 = _20761;
                    }
                    _20822 = _20823;
                }
                else
                {
                    _20822 = _20759;
                }
                _21913 = float3(_20712, log((r_depth_tm1.Load(int3(int2(floor(_19825 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12853_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_19827 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12885_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _20821 = _20822;
            }
            else
            {
                _21913 = float3(0.0f, 0.0f, 0.5f);
                _20821 = _20716;
            }
            bool _6623 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6372;
            bool _6629;
            if (_6623)
            {
                _6629 = _6426 || _6432;
            }
            else
            {
                _6629 = _6623;
            }
            float4 _20864;
            if (_6629)
            {
                float _20816;
                do
                {
                    uint4 _13407 = r_warped_motion_qdata_tp1.Load(int3(_20046, 0));
                    uint _13408 = _13407.x;
                    if (_13408 != 0u)
                    {
                        float _20815;
                        if (_13408 == 0u)
                        {
                            _20815 = -1.0f;
                        }
                        else
                        {
                            _20815 = float((_13408 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20816 = _20815;
                        break;
                    }
                    int _20798;
                    uint _20799;
                    _20799 = _13408;
                    _20798 = -1;
                    uint _20814;
                    for (; _20798 <= 1; _20799 = _20814, _20798++)
                    {
                        _20814 = _20799;
                        for (int _20812 = -1; _20812 <= 1; )
                        {
                            _20814 = max(_20814, r_warped_motion_qdata_tp1.Load(int3(clamp(_20046 + int2(_20812, _20798), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20812++;
                            continue;
                        }
                    }
                    if (_20799 != 0u)
                    {
                        float _20811;
                        if (_20799 == 0u)
                        {
                            _20811 = -1.0f;
                        }
                        else
                        {
                            _20811 = float((_20799 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20816 = _20811;
                        break;
                    }
                    uint _20801;
                    _20801 = 4294967295u;
                    uint _23355;
                    for (int _20800 = 0; _20800 < 8; _20801 = _23355, _20800++)
                    {
                        int _20804 = 0;
                        for (;;)
                        {
                            if (_20804 < 5)
                            {
                                int2 _13358 = _20046 + (_1248[_20800] * _1257[_20804].xx);
                                bool _13361 = any(bool2(_13358.x < int2(0, 0).x, _13358.y < int2(0, 0).y));
                                bool _13369;
                                if (!_13361)
                                {
                                    _13369 = any(bool2(_13358.x >= cbFI_MvDepthLaneSize.x, _13358.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13369 = _13361;
                                }
                                if (_13369)
                                {
                                    _23355 = _20801;
                                    break;
                                }
                                uint4 _13447 = r_warped_motion_qdata_tp1.Load(int3(_13358, 0));
                                uint _13448 = _13447.x;
                                if (_13448 != 0u)
                                {
                                    _23355 = min(_20801, _13448);
                                    break;
                                }
                                _20804++;
                                continue;
                            }
                            else
                            {
                                _23355 = _20801;
                                break;
                            }
                        }
                    }
                    float _20803;
                    if (_20801 == 4294967295u)
                    {
                        _20803 = -1.0f;
                    }
                    else
                    {
                        float _20802;
                        if (_20801 == 0u)
                        {
                            _20802 = -1.0f;
                        }
                        else
                        {
                            _20802 = float((_20801 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20803 = _20802;
                    }
                    _20816 = _20803;
                    break;
                } while(false);
                float4 _20865;
                if (_20816 >= 0.0f)
                {
                    float _13469 = (exp((_20816 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6648;
                    if (_6426)
                    {
                        uint _13476_dummy_parameter;
                        _6648 = r_depth_tm1.Load(int3(int2(floor(_19828 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13476_dummy_parameter))))), 0)).x > _13469;
                    }
                    else
                    {
                        _6648 = _6426;
                    }
                    float4 _20834;
                    if (_6648)
                    {
                        float4 _19570 = _20821;
                        _19570.z = 0.0f;
                        _20834 = _19570;
                    }
                    else
                    {
                        _20834 = _20821;
                    }
                    bool _6660;
                    if (_6432)
                    {
                        uint _13495_dummy_parameter;
                        _6660 = r_depth_tp1.Load(int3(int2(floor(_19829 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13495_dummy_parameter))))), 0)).x > _13469;
                    }
                    else
                    {
                        _6660 = _6432;
                    }
                    float4 _20866;
                    if (_6660)
                    {
                        float4 _19572 = _20834;
                        _19572.w = 0.0f;
                        _20866 = _19572;
                    }
                    else
                    {
                        _20866 = _20834;
                    }
                    _20865 = _20866;
                }
                else
                {
                    _20865 = _20821;
                }
                _20864 = _20865;
            }
            else
            {
                _20864 = _20821;
            }
            bool _6668 = _6414 != _6420;
            bool _6675;
            if (_6668)
            {
                _6675 = _6414 ? _6360 : _6363;
            }
            else
            {
                _6675 = _6668;
            }
            bool _6682;
            if (_6675)
            {
                _6682 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6682 = _6675;
            }
            float4 _20967;
            if (_6682)
            {
                bool2 _6687 = _6414.xx;
                float2 _6688 = float2(_6687.x ? _19825.x : _19827.x, _6687.y ? _19825.y : _19827.y);
                float _20848;
                if (_6414)
                {
                    uint _13514_dummy_parameter;
                    _20848 = r_depth_tm1.Load(int3(int2(floor(_6688 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13514_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13530_dummy_parameter;
                    _20848 = r_depth_tp1.Load(int3(int2(floor(_6688 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13530_dummy_parameter))))), 0)).x;
                }
                float4x4 _20855;
                if (_6414)
                {
                    float4x4 _20844;
                    do
                    {
                        float4x4 _13544;
                        bool _20843;
                        do
                        {
                            _13544 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20843 = false;
                                break;
                            }
                            uint _13578 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13578 + 32u) * 4 + 0) != 1u)
                            {
                                _20843 = false;
                                break;
                            }
                            uint _20840;
                            _20840 = 0u;
                            for (; _20840 < 4u; _20840++)
                            {
                                for (uint _20841 = 0u; _20841 < 4u; )
                                {
                                    _13544[_20840][_20841] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13578 + 16u) + (_20840 * 4u)) + _20841) * 4 + 0));
                                    _20841++;
                                    continue;
                                }
                            }
                            _20843 = true;
                            break;
                        } while(false);
                        if (_20843)
                        {
                            _20844 = _13544;
                            break;
                        }
                        _20844 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20855 = _20844;
                }
                else
                {
                    float4x4 _20839;
                    do
                    {
                        float4x4 _13650;
                        bool _20838;
                        do
                        {
                            _13650 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20838 = false;
                                break;
                            }
                            uint _13684 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13684 + 32u) * 4 + 0) != 1u)
                            {
                                _20838 = false;
                                break;
                            }
                            uint _20835;
                            _20835 = 0u;
                            for (; _20835 < 4u; _20835++)
                            {
                                for (uint _20836 = 0u; _20836 < 4u; )
                                {
                                    _13650[_20835][_20836] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13684 + (_20835 * 4u)) + _20836) * 4 + 0));
                                    _20836++;
                                    continue;
                                }
                            }
                            _20838 = true;
                            break;
                        } while(false);
                        if (_20838)
                        {
                            _20839 = _13650;
                            break;
                        }
                        _20839 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20855 = _20839;
                }
                float2 _20856;
                do
                {
                    float _13761 = _6688.x;
                    float _13764 = 1.0f - _6688.y;
                    float4 _13775 = mul(float4((float2(_13761, _13764) * 2.0f) - 1.0f.xx, _20848, 1.0f), _20855);
                    float _13777 = _13775.w;
                    if (!(_13777 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20856 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13790 = ((_13775.xy / _13777.xx) + 1.0f.xx) * 0.5f;
                    _20856 = float2(_13790.x - _13761, _13764 - _13790.y);
                    break;
                } while(false);
                float2 _6718 = float2(cbFI_DisplaySize);
                float4 _20968;
                if (!(length(((_6688 + _20856) - float2(_6687.x ? _19827.x : _19825.x, _6687.y ? _19827.y : _19825.y)) * _6718) <= ((0.100000001490116119384765625f * length(_20856 * _6718)) + 8.0f)))
                {
                    float4 _20969;
                    if (_6414)
                    {
                        float4 _19582 = _20864;
                        _19582.x = 0.0f;
                        _20969 = _19582;
                    }
                    else
                    {
                        float4 _19584 = _20864;
                        _19584.y = 0.0f;
                        _20969 = _19584;
                    }
                    _20968 = _20969;
                }
                else
                {
                    _20968 = _20864;
                }
                _20967 = _20968;
            }
            else
            {
                _20967 = _20864;
            }
            float4 _6743 = _20578 * _20967;
            float _6745 = dot(_6743, 1.0f.xxxx);
            float4 _21309;
            bool _21615;
            if (_6745 > 0.0f)
            {
                _21615 = _20269;
                _21309 = _6743 / _6745.xxxx;
            }
            else
            {
                bool _6756 = any(bool4(_20967.x < 1.0f.xxxx.x, _20967.y < 1.0f.xxxx.y, _20967.z < 1.0f.xxxx.z, _20967.w < 1.0f.xxxx.w));
                if (_6756)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13812;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13812);
                    }
                }
                bool4 _23728 = _6756.xxxx;
                _21615 = _6756 ? true : _20269;
                _21309 = float4(_23728.x ? 0.0f.xxxx.x : _20578.x, _23728.y ? 0.0f.xxxx.y : _20578.y, _23728.z ? 0.0f.xxxx.z : _20578.z, _23728.w ? 0.0f.xxxx.w : _20578.w);
            }
            _21804 = _21913;
            _21614 = _21615;
            _21308 = _21309;
        }
        else
        {
            _21804 = float3(0.0f, 0.0f, 0.5f);
            _21614 = _20269;
            _21308 = _20578;
        }
        uint _6765 = (cbFI_pad0 >> 24u) & 31u;
        uint _6769 = (cbFI_pad0 >> 16u) & 255u;
        bool _6771 = _6765 != 0u;
        bool _6773 = _6769 == 12u;
        bool _6776 = _6769 == 13u;
        float4 _21329;
        if ((_6771 || _6773) || _6776)
        {
            float _20975;
            do
            {
                bool _13896 = all(bool2(_19828.x > 0.0f.xx.x, _19828.y > 0.0f.xx.y));
                bool _13902;
                if (_13896)
                {
                    _13902 = all(bool2(_19828.x < 1.0f.xx.x, _19828.y < 1.0f.xx.y));
                }
                else
                {
                    _13902 = _13896;
                }
                bool _13833 = !_13902;
                bool _13840;
                if (!_13833)
                {
                    bool _13907 = all(bool2(_19829.x > 0.0f.xx.x, _19829.y > 0.0f.xx.y));
                    bool _13913;
                    if (_13907)
                    {
                        _13913 = all(bool2(_19829.x < 1.0f.xx.x, _19829.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13913 = _13907;
                    }
                    _13840 = !_13913;
                }
                else
                {
                    _13840 = _13833;
                }
                if (_13840)
                {
                    _20975 = 0.0f;
                    break;
                }
                uint _13920_dummy_parameter;
                uint _13936_dummy_parameter;
                float4x4 _20974;
                do
                {
                    float4x4 _13950;
                    bool _20973;
                    do
                    {
                        _13950 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20973 = false;
                            break;
                        }
                        uint _13984 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13984 + 32u) * 4 + 0) != 1u)
                        {
                            _20973 = false;
                            break;
                        }
                        uint _20970;
                        _20970 = 0u;
                        for (; _20970 < 4u; _20970++)
                        {
                            for (uint _20971 = 0u; _20971 < 4u; )
                            {
                                _13950[_20970][_20971] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13984 + 16u) + (_20970 * 4u)) + _20971) * 4 + 0));
                                _20971++;
                                continue;
                            }
                        }
                        _20973 = true;
                        break;
                    } while(false);
                    if (_20973)
                    {
                        _20974 = _13950;
                        break;
                    }
                    _20974 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13861 = mul(float4((float2(_19828.x, 1.0f - _19828.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19828 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13920_dummy_parameter))))), 0)).x, 1.0f), _20974);
                float _13863 = _13861.w;
                if (abs(_13863) < 9.9999999747524270787835121154785e-07f)
                {
                    _20975 = 0.0f;
                    break;
                }
                float _13874 = abs(cbFI_DeviceToViewDepth.y / ((_13861.z / _13863) - cbFI_DeviceToViewDepth.x));
                float _13877 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19829 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13936_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20975 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13874 - _13877) / max(max(_13874, _13877), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14086 = all(bool2(_19829.x > 0.0f.xx.x, _19829.y > 0.0f.xx.y));
            bool _14092;
            if (_14086)
            {
                _14092 = all(bool2(_19829.x < 1.0f.xx.x, _19829.y < 1.0f.xx.y));
            }
            else
            {
                _14092 = _14086;
            }
            float _20976;
            if (_14092)
            {
                uint _14099_dummy_parameter;
                _20976 = length((_7920 + (r_motion_tp1.Load(int3(int2(floor(_19829 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14099_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20976 = 1000000.0f;
            }
            float _20991;
            if ((_6765 & 1u) != 0u)
            {
                _20991 = _20975;
            }
            else
            {
                _20991 = 1.0f;
            }
            float _20992;
            if ((_6765 & 2u) != 0u)
            {
                _20992 = _20991 * (1.0f - smoothstep(2.0f, 8.0f, _20976));
            }
            else
            {
                _20992 = _20991;
            }
            float _20993;
            if ((_6765 & 4u) != 0u)
            {
                _20993 = _20992 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8641 - _8649) - length(_8625 - _8633))));
            }
            else
            {
                _20993 = _20992;
            }
            float _21323;
            if ((_6765 & 8u) != 0u)
            {
                _21323 = lerp(1.0f, _20993, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8625 - _8633)));
            }
            else
            {
                _21323 = _20993;
            }
            bool _6851 = (_6765 & 16u) != 0u;
            bool _6860;
            if (_6851)
            {
                _6860 = length(_19823 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6860 = _6851;
            }
            float _23730 = _6860 ? 1.0f : _21323;
            bool _6866 = _6771 && _11022;
            bool _6871;
            if (_6866)
            {
                bool _14124 = all(bool2(_19825.x > 0.0f.xx.x, _19825.y > 0.0f.xx.y));
                bool _14130;
                if (_14124)
                {
                    _14130 = all(bool2(_19825.x < 1.0f.xx.x, _19825.y < 1.0f.xx.y));
                }
                else
                {
                    _14130 = _14124;
                }
                _6871 = _14130;
            }
            else
            {
                _6871 = _6866;
            }
            bool _6876;
            if (_6871)
            {
                bool _14135 = all(bool2(_19827.x > 0.0f.xx.x, _19827.y > 0.0f.xx.y));
                bool _14141;
                if (_14135)
                {
                    _14141 = all(bool2(_19827.x < 1.0f.xx.x, _19827.y < 1.0f.xx.y));
                }
                else
                {
                    _14141 = _14135;
                }
                _6876 = _14141;
            }
            else
            {
                _6876 = _6871;
            }
            float4 _21330;
            if (_6876)
            {
                float _6882 = _21308.x + _21308.y;
                float _6891 = (_21308.z + _21308.w) * (1.0f - _23730);
                float _21326;
                if (_6882 > 9.9999997473787516355514526367188e-06f)
                {
                    _21326 = _21308.x / _6882;
                }
                else
                {
                    _21326 = _5621;
                }
                _21330 = float4(_21308.x + (_6891 * _21326), _21308.y + (_6891 * (1.0f - _21326)), _21308.zw * _23730);
            }
            else
            {
                _21330 = _21308;
            }
            _21329 = _21330;
        }
        else
        {
            _21329 = _21308;
        }
        float3 _6952 = (((_8625 * _21329.x) + (_8633 * _21329.y)) + (_8641 * _21329.z)) + (_8649 * _21329.w);
        float3 _22929;
        if (_5637 && (_21344 > 0.0f))
        {
            uint _14148_dummy_parameter;
            float2 _14163 = r_motion_tp1.Load(int3(int2(floor(_5396 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14148_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21606;
            if (_7948)
            {
                float2 _14208 = clamp((((_19802 + (_14163 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14211 = tan(_14208.x);
                _21606 = (float2(_14211 / cbFI_DeviceToViewDepth.z, (tan(_14208.y) * sqrt(1.0f + (_14211 * _14211))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21606 = _19802 + (_14163 * cbFI_Timestep);
            }
            float2 _21607;
            if (_7948)
            {
                float2 _14287 = clamp((((_19802 + (_14163 * _5611)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14290 = tan(_14287.x);
                _21607 = (float2(_14290 / cbFI_DeviceToViewDepth.z, (tan(_14287.y) * sqrt(1.0f + (_14290 * _14290))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21607 = _19802 + (_14163 * _5611);
            }
            _22929 = lerp(_6952, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21606, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21607, 0.0f).xyz, cbFI_Timestep.xxx), _21344.xxx);
        }
        else
        {
            _22929 = _6952;
        }
        float3 _22928;
        if (_21614)
        {
            float3 _14332 = r_current_interpolation_source.Load(int3(_4884, 0)).xyz;
            float3 _22930;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11022)
            {
                uint _14339_dummy_parameter;
                float _21737;
                _21737 = r_depth_tm1.Load(int3(int2(floor(_19825 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14339_dummy_parameter))))), 0)).x;
                float _7033;
                for (int _21736 = 0; _21736 < 24; _21737 = _7033, _21736++)
                {
                    float _7005 = float(_21736 & 7) * 0.785398185253143310546875f;
                    int _7007 = _21736 >> 3;
                    int _23197;
                    if (_7007 == 0)
                    {
                        _23197 = 16;
                    }
                    else
                    {
                        _23197 = (_7007 == 1) ? 48 : 96;
                    }
                    uint _14359_dummy_parameter;
                    _7033 = min(_21737, r_depth_tm1.Load(int3(int2(floor(clamp(_19825 + ((cbFI_MvDepthLaneSizeRcp * float(_23197)) * float2(cos(_7005), sin(_7005))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14359_dummy_parameter))))), 0)).x);
                }
                float2 _21738;
                do
                {
                    float _14381 = 1.0f - _19825.y;
                    float4 _14392 = mul(float4((float2(_19825.x, _14381) * 2.0f) - 1.0f.xx, _21737, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14394 = _14392.w;
                    if (!(_14394 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21738 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14407 = ((_14392.xy / _14394.xx) + 1.0f.xx) * 0.5f;
                    _21738 = float2(_14407.x - _19825.x, _14381 - _14407.y);
                    break;
                } while(false);
                float2 _7044 = _19825 + _21738;
                bool _14425 = all(bool2(_7044.x > 0.0f.xx.x, _7044.y > 0.0f.xx.y));
                bool _14431;
                if (_14425)
                {
                    _14431 = all(bool2(_7044.x < 1.0f.xx.x, _7044.y < 1.0f.xx.y));
                }
                else
                {
                    _14431 = _14425;
                }
                float3 _22931;
                if (_14431)
                {
                    float _7050 = abs(cbFI_DeviceToViewDepth.y / (_21737 - cbFI_DeviceToViewDepth.x));
                    uint _14451_dummy_parameter;
                    int2 _14451 = int2(spvTextureSize(r_depth_m2, uint(0), _14451_dummy_parameter));
                    float _7054 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7044 * float2(_14451))), int2(0, 0), _14451 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22936;
                    if (abs(_7054 - _7050) <= (0.20000000298023223876953125f * max(_7054, _7050)))
                    {
                        uint _14485_dummy_parameter;
                        int2 _14485 = int2(spvTextureSize(r_colour_m2, uint(0), _14485_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14508;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14508);
                        }
                        _22936 = r_colour_m2.Load(int3(clamp(int2(floor(_7044 * float2(_14485))), int2(0, 0), _14485 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14518;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14518);
                        }
                        _22936 = _14332;
                    }
                    _22931 = _22936;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14528;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14528);
                    }
                    _22931 = _14332;
                }
                _22930 = _22931;
            }
            else
            {
                _22930 = _14332;
            }
            _22928 = _22930;
        }
        else
        {
            _22928 = _22929;
        }
        bool _7079 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22927;
        float _23003;
        if (_7079)
        {
            float _14705;
            float2 _7083 = float2(cbFI_DisplaySize);
            float3 _21795;
            do
            {
                bool _14766;
                float4x4 _21745;
                do
                {
                    float4x4 _14742;
                    bool _21744;
                    do
                    {
                        _14742 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14766 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14766)
                        {
                            _21744 = false;
                            break;
                        }
                        uint _14776 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14776 + 32u) * 4 + 0) != 1u)
                        {
                            _21744 = false;
                            break;
                        }
                        uint _21741;
                        _21741 = 0u;
                        for (; _21741 < 4u; _21741++)
                        {
                            for (uint _21742 = 0u; _21742 < 4u; )
                            {
                                _14742[_21741][_21742] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14776 + (_21741 * 4u)) + _21742) * 4 + 0));
                                _21742++;
                                continue;
                            }
                        }
                        _21744 = true;
                        break;
                    } while(false);
                    if (_21744)
                    {
                        _21745 = _14742;
                        break;
                    }
                    _21745 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float _14853;
                float _14856;
                float4 _14866;
                float2 _21746;
                do
                {
                    _14853 = _5396.x;
                    _14856 = 1.0f - _5396.y;
                    _14866 = float4((float2(_14853, _14856) * 2.0f) - 1.0f.xx, 1.0000000116860974230803549289703e-07f, 1.0f);
                    float4 _14867 = mul(_14866, _21745);
                    float _14869 = _14867.w;
                    if (!(_14869 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21746 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14882 = ((_14867.xy / _14869.xx) + 1.0f.xx) * 0.5f;
                    _21746 = float2(_14882.x - _14853, _14856 - _14882.y);
                    break;
                } while(false);
                float4x4 _21751;
                do
                {
                    float4x4 _14900;
                    bool _21750;
                    do
                    {
                        _14900 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_14766)
                        {
                            _21750 = false;
                            break;
                        }
                        uint _14934 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14934 + 32u) * 4 + 0) != 1u)
                        {
                            _21750 = false;
                            break;
                        }
                        uint _21747;
                        _21747 = 0u;
                        for (; _21747 < 4u; _21747++)
                        {
                            for (uint _21748 = 0u; _21748 < 4u; )
                            {
                                _14900[_21747][_21748] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14934 + 16u) + (_21747 * 4u)) + _21748) * 4 + 0));
                                _21748++;
                                continue;
                            }
                        }
                        _21750 = true;
                        break;
                    } while(false);
                    if (_21750)
                    {
                        _21751 = _14900;
                        break;
                    }
                    _21751 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float2 _21752;
                do
                {
                    float4 _15025 = mul(_14866, _21751);
                    float _15027 = _15025.w;
                    if (!(_15027 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21752 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15040 = ((_15025.xy / _15027.xx) + 1.0f.xx) * 0.5f;
                    _21752 = float2(_15040.x - _14853, _14856 - _15040.y);
                    break;
                } while(false);
                float2 _14583 = abs(_21746);
                bool2 _23731 = any(bool2(_14583.x > 4.0f.xx.x, _14583.y > 4.0f.xx.y)).xx;
                float2 _14589 = abs(_21752);
                bool2 _23733 = any(bool2(_14589.x > 4.0f.xx.x, _14589.y > 4.0f.xx.y)).xx;
                float2 _15054[3];
                _15054[0] = _5396;
                float2 _15170 = clamp(_5396, 0.0f.xx, 1.0f.xx);
                uint _15178_dummy_parameter;
                _15054[1] = _5396 - ((r_motion_tp1.Load(int3(int2(floor(_15170 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15178_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621);
                _15054[2] = _5396 - (float2(_23731.x ? 0.0f.xx.x : _21746.x, _23731.y ? 0.0f.xx.y : _21746.y) * _5621);
                float _21762;
                float2 _21763;
                _21763 = _5396;
                _21762 = 1000000000.0f;
                float _23735;
                float2 _23737;
                float _23738;
                int _21761 = 0;
                float _23189 = -1.0f;
                for (; _21761 < 3; _23189 = _23735, _21763 = _23737, _21762 = _23738, _21761++)
                {
                    float2 _23179;
                    _23179 = _15054[_21761];
                    for (int _23178 = 0; _23178 < 30; )
                    {
                        uint _15794_dummy_parameter;
                        _23179 += (((_5396 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_23179, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15794_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621)) - _23179) * 0.699999988079071044921875f);
                        _23178++;
                        continue;
                    }
                    float2 _16330 = clamp(_23179, 0.0f.xx, 1.0f.xx);
                    uint _16338_dummy_parameter;
                    bool _16874 = all(bool2(_23179.x > 0.0f.xx.x, _23179.y > 0.0f.xx.y));
                    bool _16880;
                    if (_16874)
                    {
                        _16880 = all(bool2(_23179.x < 1.0f.xx.x, _23179.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _16880 = _16874;
                    }
                    float _23181;
                    if (_16880)
                    {
                        _23181 = length(((_23179 + ((r_motion_tp1.Load(int3(int2(floor(_16330 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16338_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621)) - _5396) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _23181 = 1000000000.0f;
                    }
                    uint _16891_dummy_parameter;
                    float _16931 = log((r_depth_tp1.Load(int3(int2(floor(_16330 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16891_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15130 = _23181 < 0.3499999940395355224609375f;
                    bool _15132 = _21762 < 0.3499999940395355224609375f;
                    bool _15142;
                    if (_15130)
                    {
                        _15142 = (!_15132) || (_16931 > _23189);
                    }
                    else
                    {
                        _15142 = _15130;
                    }
                    bool _15155;
                    if (!_15142)
                    {
                        _15155 = ((!_15130) && (!_15132)) && (_23181 < _21762);
                    }
                    else
                    {
                        _15155 = _15142;
                    }
                    _23735 = _15155 ? _16931 : _23189;
                    bool2 _23736 = _15155.xx;
                    _23737 = float2(_23736.x ? _23179.x : _21763.x, _23736.y ? _23179.y : _21763.y);
                    _23738 = _15155 ? _23181 : _21762;
                }
                float2 _16933[3];
                _16933[0] = _5396;
                float2 _21791;
                do
                {
                    bool _21772;
                    do
                    {
                        bool _17176 = all(bool2(_15170.x > 0.0f.xx.x, _15170.y > 0.0f.xx.y));
                        bool _17182;
                        if (_17176)
                        {
                            _17182 = all(bool2(_15170.x < 1.0f.xx.x, _15170.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17182 = _17176;
                        }
                        if (!_17182)
                        {
                            _21772 = false;
                            break;
                        }
                        uint _17189_dummy_parameter;
                        float4x4 _21770;
                        do
                        {
                            float4x4 _17203;
                            bool _21769;
                            do
                            {
                                _17203 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14766)
                                {
                                    _21769 = false;
                                    break;
                                }
                                uint _17237 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17237 + 32u) * 4 + 0) != 1u)
                                {
                                    _21769 = false;
                                    break;
                                }
                                uint _21766;
                                _21766 = 0u;
                                for (; _21766 < 4u; _21766++)
                                {
                                    for (uint _21767 = 0u; _21767 < 4u; )
                                    {
                                        _17203[_21766][_21767] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17237 + (_21766 * 4u)) + _21767) * 4 + 0));
                                        _21767++;
                                        continue;
                                    }
                                }
                                _21769 = true;
                                break;
                            } while(false);
                            if (_21769)
                            {
                                _21770 = _17203;
                                break;
                            }
                            _21770 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21771;
                        do
                        {
                            float _17314 = _15170.x;
                            float _17317 = 1.0f - _15170.y;
                            float4 _17328 = mul(float4((float2(_17314, _17317) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15170 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17189_dummy_parameter))))), 0)).x, 1.0f), _21770);
                            float _17330 = _17328.w;
                            if (!(_17330 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21771 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17343 = ((_17328.xy / _17330.xx) + 1.0f.xx) * 0.5f;
                            _21771 = float2(_17343.x - _17314, _17317 - _17343.y);
                            break;
                        } while(false);
                        float2 _17140 = abs(_21771);
                        if (any(bool2(_17140.x > 100000.0f.xx.x, _17140.y > 100000.0f.xx.y)))
                        {
                            _21772 = false;
                            break;
                        }
                        float _17148 = length(_21771 * _7083);
                        uint _17363_dummy_parameter;
                        bool _17162 = _17148 > ((8.0f * _7083.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17169;
                        if (_17162)
                        {
                            _17169 = length((r_motion_tp1.Load(int3(int2(floor(_15170 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17363_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7083) < (0.20000000298023223876953125f * _17148);
                        }
                        else
                        {
                            _17169 = _17162;
                        }
                        _21772 = _17169;
                        break;
                    } while(false);
                    if (_21772)
                    {
                        uint _17394_dummy_parameter;
                        _21791 = -(r_motion_tp1.Load(int3(int2(floor(_15170 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17394_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17421_dummy_parameter;
                    float4x4 _21785;
                    do
                    {
                        float4x4 _17435;
                        bool _21784;
                        do
                        {
                            _17435 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14766)
                            {
                                _21784 = false;
                                break;
                            }
                            uint _17469 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_17469 + 32u) * 4 + 0) != 1u)
                            {
                                _21784 = false;
                                break;
                            }
                            uint _21781;
                            _21781 = 0u;
                            for (; _21781 < 4u; _21781++)
                            {
                                for (uint _21782 = 0u; _21782 < 4u; )
                                {
                                    _17435[_21781][_21782] = asfloat(rw_nfru_diagnostics.Load<uint>((((_17469 + 16u) + (_21781 * 4u)) + _21782) * 4 + 0));
                                    _21782++;
                                    continue;
                                }
                            }
                            _21784 = true;
                            break;
                        } while(false);
                        if (_21784)
                        {
                            _21785 = _17435;
                            break;
                        }
                        _21785 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _21790;
                    do
                    {
                        float _17546 = _15170.x;
                        float _17549 = 1.0f - _15170.y;
                        float4 _17560 = mul(float4((float2(_17546, _17549) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15170 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17421_dummy_parameter))))), 0)).x, 1.0f), _21785);
                        float _17562 = _17560.w;
                        if (!(_17562 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21790 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17575 = ((_17560.xy / _17562.xx) + 1.0f.xx) * 0.5f;
                        _21790 = float2(_17575.x - _17546, _17549 - _17575.y);
                        break;
                    } while(false);
                    float2 _17107 = abs(_21790);
                    bool2 _17111 = any(bool2(_17107.x > 4.0f.xx.x, _17107.y > 4.0f.xx.y)).xx;
                    _21791 = float2(_17111.x ? 0.0f.xx.x : _21790.x, _17111.y ? 0.0f.xx.y : _21790.y);
                    break;
                } while(false);
                _16933[1] = _5396 - (_21791 * cbFI_Timestep);
                _16933[2] = _5396 - (float2(_23733.x ? 0.0f.xx.x : _21752.x, _23733.y ? 0.0f.xx.y : _21752.y) * cbFI_Timestep);
                float _21793;
                float2 _21794;
                _21794 = _5396;
                _21793 = 1000000000.0f;
                float _23739;
                float2 _23741;
                float _23742;
                float4x4 _17819;
                float4x4 _18051;
                float4x4 _18363;
                float4x4 _18595;
                int _21792 = 0;
                float _23091 = -1.0f;
                for (; _21792 < 3; _23091 = _23739, _21794 = _23741, _21793 = _23742, _21792++)
                {
                    float2 _23024;
                    _23024 = _16933[_21792];
                    float2 _17629;
                    for (int _23023 = 0; _23023 < 30; _23024 = _17629, _23023++)
                    {
                        float2 _23149;
                        do
                        {
                            float2 _17708 = clamp(_23024, 0.0f.xx, 1.0f.xx);
                            bool _23130;
                            do
                            {
                                bool _17792 = all(bool2(_17708.x > 0.0f.xx.x, _17708.y > 0.0f.xx.y));
                                bool _17798;
                                if (_17792)
                                {
                                    _17798 = all(bool2(_17708.x < 1.0f.xx.x, _17708.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17798 = _17792;
                                }
                                if (!_17798)
                                {
                                    _23130 = false;
                                    break;
                                }
                                uint _17805_dummy_parameter;
                                float4x4 _23128;
                                do
                                {
                                    bool _23127;
                                    do
                                    {
                                        _17819 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14766)
                                        {
                                            _23127 = false;
                                            break;
                                        }
                                        uint _17853 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17853 + 32u) * 4 + 0) != 1u)
                                        {
                                            _23127 = false;
                                            break;
                                        }
                                        uint _23124;
                                        _23124 = 0u;
                                        for (; _23124 < 4u; _23124++)
                                        {
                                            for (uint _23125 = 0u; _23125 < 4u; )
                                            {
                                                _17819[_23124][_23125] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17853 + (_23124 * 4u)) + _23125) * 4 + 0));
                                                _23125++;
                                                continue;
                                            }
                                        }
                                        _23127 = true;
                                        break;
                                    } while(false);
                                    if (_23127)
                                    {
                                        _23128 = _17819;
                                        break;
                                    }
                                    _23128 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _23129;
                                do
                                {
                                    float _17930 = _17708.x;
                                    float _17933 = 1.0f - _17708.y;
                                    float4 _17944 = mul(float4((float2(_17930, _17933) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17708 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17805_dummy_parameter))))), 0)).x, 1.0f), _23128);
                                    float _17946 = _17944.w;
                                    if (!(_17946 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _23129 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _17959 = ((_17944.xy / _17946.xx) + 1.0f.xx) * 0.5f;
                                    _23129 = float2(_17959.x - _17930, _17933 - _17959.y);
                                    break;
                                } while(false);
                                float2 _17756 = abs(_23129);
                                if (any(bool2(_17756.x > 100000.0f.xx.x, _17756.y > 100000.0f.xx.y)))
                                {
                                    _23130 = false;
                                    break;
                                }
                                float _17764 = length(_23129 * _7083);
                                uint _17979_dummy_parameter;
                                bool _17778 = _17764 > ((8.0f * _7083.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17785;
                                if (_17778)
                                {
                                    _17785 = length((r_motion_tp1.Load(int3(int2(floor(_17708 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17979_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7083) < (0.20000000298023223876953125f * _17764);
                                }
                                else
                                {
                                    _17785 = _17778;
                                }
                                _23130 = _17785;
                                break;
                            } while(false);
                            if (_23130)
                            {
                                uint _18010_dummy_parameter;
                                _23149 = -(r_motion_tp1.Load(int3(int2(floor(_17708 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18010_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _18037_dummy_parameter;
                            float4x4 _23143;
                            do
                            {
                                bool _23142;
                                do
                                {
                                    _18051 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14766)
                                    {
                                        _23142 = false;
                                        break;
                                    }
                                    uint _18085 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18085 + 32u) * 4 + 0) != 1u)
                                    {
                                        _23142 = false;
                                        break;
                                    }
                                    uint _23139;
                                    _23139 = 0u;
                                    for (; _23139 < 4u; _23139++)
                                    {
                                        for (uint _23140 = 0u; _23140 < 4u; )
                                        {
                                            _18051[_23139][_23140] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18085 + 16u) + (_23139 * 4u)) + _23140) * 4 + 0));
                                            _23140++;
                                            continue;
                                        }
                                    }
                                    _23142 = true;
                                    break;
                                } while(false);
                                if (_23142)
                                {
                                    _23143 = _18051;
                                    break;
                                }
                                _23143 = cbFI_MotionTM1ToTP1;
                                break;
                            } while(false);
                            float2 _23148;
                            do
                            {
                                float _18162 = _17708.x;
                                float _18165 = 1.0f - _17708.y;
                                float4 _18176 = mul(float4((float2(_18162, _18165) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17708 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18037_dummy_parameter))))), 0)).x, 1.0f), _23143);
                                float _18178 = _18176.w;
                                if (!(_18178 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _23148 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18191 = ((_18176.xy / _18178.xx) + 1.0f.xx) * 0.5f;
                                _23148 = float2(_18191.x - _18162, _18165 - _18191.y);
                                break;
                            } while(false);
                            float2 _17723 = abs(_23148);
                            bool2 _17727 = any(bool2(_17723.x > 4.0f.xx.x, _17723.y > 4.0f.xx.y)).xx;
                            _23149 = float2(_17727.x ? 0.0f.xx.x : _23148.x, _17727.y ? 0.0f.xx.y : _23148.y);
                            break;
                        } while(false);
                        _17629 = _23024 + (((_5396 - (_23149 * cbFI_Timestep)) - _23024) * 0.699999988079071044921875f);
                    }
                    float2 _18252;
                    float2 _23050;
                    do
                    {
                        _18252 = clamp(_23024, 0.0f.xx, 1.0f.xx);
                        bool _23031;
                        do
                        {
                            bool _18336 = all(bool2(_18252.x > 0.0f.xx.x, _18252.y > 0.0f.xx.y));
                            bool _18342;
                            if (_18336)
                            {
                                _18342 = all(bool2(_18252.x < 1.0f.xx.x, _18252.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18342 = _18336;
                            }
                            if (!_18342)
                            {
                                _23031 = false;
                                break;
                            }
                            uint _18349_dummy_parameter;
                            float4x4 _23029;
                            do
                            {
                                bool _23028;
                                do
                                {
                                    _18363 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14766)
                                    {
                                        _23028 = false;
                                        break;
                                    }
                                    uint _18397 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18397 + 32u) * 4 + 0) != 1u)
                                    {
                                        _23028 = false;
                                        break;
                                    }
                                    uint _23025;
                                    _23025 = 0u;
                                    for (; _23025 < 4u; _23025++)
                                    {
                                        for (uint _23026 = 0u; _23026 < 4u; )
                                        {
                                            _18363[_23025][_23026] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18397 + (_23025 * 4u)) + _23026) * 4 + 0));
                                            _23026++;
                                            continue;
                                        }
                                    }
                                    _23028 = true;
                                    break;
                                } while(false);
                                if (_23028)
                                {
                                    _23029 = _18363;
                                    break;
                                }
                                _23029 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _23030;
                            do
                            {
                                float _18477 = 1.0f - _18252.y;
                                float4 _18488 = mul(float4((float2(_18252.x, _18477) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18252 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18349_dummy_parameter))))), 0)).x, 1.0f), _23029);
                                float _18490 = _18488.w;
                                if (!(_18490 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _23030 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18503 = ((_18488.xy / _18490.xx) + 1.0f.xx) * 0.5f;
                                _23030 = float2(_18503.x - _18252.x, _18477 - _18503.y);
                                break;
                            } while(false);
                            float2 _18300 = abs(_23030);
                            if (any(bool2(_18300.x > 100000.0f.xx.x, _18300.y > 100000.0f.xx.y)))
                            {
                                _23031 = false;
                                break;
                            }
                            float _18308 = length(_23030 * _7083);
                            uint _18523_dummy_parameter;
                            bool _18322 = _18308 > ((8.0f * _7083.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18329;
                            if (_18322)
                            {
                                _18329 = length((r_motion_tp1.Load(int3(int2(floor(_18252 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18523_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7083) < (0.20000000298023223876953125f * _18308);
                            }
                            else
                            {
                                _18329 = _18322;
                            }
                            _23031 = _18329;
                            break;
                        } while(false);
                        if (_23031)
                        {
                            uint _18554_dummy_parameter;
                            _23050 = -(r_motion_tp1.Load(int3(int2(floor(_18252 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18554_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18581_dummy_parameter;
                        float4x4 _23044;
                        do
                        {
                            bool _23043;
                            do
                            {
                                _18595 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14766)
                                {
                                    _23043 = false;
                                    break;
                                }
                                uint _18629 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_18629 + 32u) * 4 + 0) != 1u)
                                {
                                    _23043 = false;
                                    break;
                                }
                                uint _23040;
                                _23040 = 0u;
                                for (; _23040 < 4u; _23040++)
                                {
                                    for (uint _23041 = 0u; _23041 < 4u; )
                                    {
                                        _18595[_23040][_23041] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18629 + 16u) + (_23040 * 4u)) + _23041) * 4 + 0));
                                        _23041++;
                                        continue;
                                    }
                                }
                                _23043 = true;
                                break;
                            } while(false);
                            if (_23043)
                            {
                                _23044 = _18595;
                                break;
                            }
                            _23044 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float2 _23049;
                        do
                        {
                            float _18709 = 1.0f - _18252.y;
                            float4 _18720 = mul(float4((float2(_18252.x, _18709) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18252 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18581_dummy_parameter))))), 0)).x, 1.0f), _23044);
                            float _18722 = _18720.w;
                            if (!(_18722 > 9.9999999747524270787835121154785e-07f))
                            {
                                _23049 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18735 = ((_18720.xy / _18722.xx) + 1.0f.xx) * 0.5f;
                            _23049 = float2(_18735.x - _18252.x, _18709 - _18735.y);
                            break;
                        } while(false);
                        float2 _18267 = abs(_23049);
                        bool2 _18271 = any(bool2(_18267.x > 4.0f.xx.x, _18267.y > 4.0f.xx.y)).xx;
                        _23050 = float2(_18271.x ? 0.0f.xx.x : _23049.x, _18271.y ? 0.0f.xx.y : _23049.y);
                        break;
                    } while(false);
                    bool _18753 = all(bool2(_23024.x > 0.0f.xx.x, _23024.y > 0.0f.xx.y));
                    bool _18759;
                    if (_18753)
                    {
                        _18759 = all(bool2(_23024.x < 1.0f.xx.x, _23024.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18759 = _18753;
                    }
                    float _23066;
                    if (_18759)
                    {
                        _23066 = length(((_23024 + (_23050 * cbFI_Timestep)) - _5396) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _23066 = 1000000000.0f;
                    }
                    uint _18786_dummy_parameter;
                    float _18810 = log((r_depth_tm1.Load(int3(int2(floor(_18252 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18786_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _17009 = _23066 < 0.3499999940395355224609375f;
                    bool _17011 = _21793 < 0.3499999940395355224609375f;
                    bool _17021;
                    if (_17009)
                    {
                        _17021 = (!_17011) || (_18810 > _23091);
                    }
                    else
                    {
                        _17021 = _17009;
                    }
                    bool _17034;
                    if (!_17021)
                    {
                        _17034 = ((!_17009) && (!_17011)) && (_23066 < _21793);
                    }
                    else
                    {
                        _17034 = _17021;
                    }
                    _23739 = _17034 ? _18810 : _23091;
                    bool2 _23740 = _17034.xx;
                    _23741 = float2(_23740.x ? _23024.x : _21794.x, _23740.y ? _23024.y : _21794.y);
                    _23742 = _17034 ? _23066 : _21793;
                }
                float3 _18819 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21763, 0.0f).xyz;
                float3 _18827 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21794, 0.0f).xyz;
                uint _18834_dummy_parameter;
                uint _18865_dummy_parameter;
                float _14627 = exp((_21762 * (-2.0f)) * (_21762 * 2.0f));
                float _14634 = exp((_21793 * (-2.0f)) * (_21793 * 2.0f));
                float _14647 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21794, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18865_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21763, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18834_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14661 = ((_14627 * cbFI_Timestep) * ((1.0f - _14634) + ((_14634 * 2.0f) * _14647))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14671 = 1.0f - _14647;
                float _14678 = ((_14634 * _5621) * ((1.0f - _14627) + ((_14627 * 2.0f) * _14671))) + (9.9999997473787516355514526367188e-05f * _5621);
                float _14687 = (((_14627 * _14634) * 4.0f) * _14647) * _14671;
                _14705 = (_14687 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18827 - _18819, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14687)) * max(_14627, _14634));
                if (_6769 == 30u)
                {
                    _21795 = _18819;
                    break;
                }
                if (_6769 == 31u)
                {
                    _21795 = _18827;
                    break;
                }
                if (_6769 == 32u)
                {
                    _21795 = float3(_14627, _14634, _14647);
                    break;
                }
                _21795 = ((_18819 * _14661) + (_18827 * _14678)) / (_14661 + _14678).xxx;
                break;
            } while(false);
            _23003 = _14705;
            _22927 = _21795;
        }
        else
        {
            _23003 = 1.0f;
            _22927 = _22928;
        }
        uint _7099 = cbFI_pad0 & 255u;
        bool _22771;
        float3 _22926;
        if (_7099 != 0u)
        {
            float3 _7104 = r_present_backbuffer.Load(int3(_4884, 0)).xyz;
            float3 _7108 = r_current_interpolation_source.Load(int3(_4884, 0)).xyz;
            float3 _7112 = abs(_7104 - _7108);
            float3 _21796;
            if (_7099 == 2u)
            {
                _21796 = (abs(_7108) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21796 = 0.000244140625f.xxx;
            }
            bool _7128 = any(bool3(_7112.x > _21796.x, _7112.y > _21796.y, _7112.z > _21796.z));
            bool3 _23743 = _7128.xxx;
            _22926 = float3(_23743.x ? _7104.x : _22927.x, _23743.y ? _7104.y : _22927.y, _23743.z ? _7104.z : _22927.z);
            _22771 = _7128;
        }
        else
        {
            _22926 = _22927;
            _22771 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18903;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18903);
        }
        float3 _22908;
        if (_6769 == 1u)
        {
            _22908 = lerp(_8625, _8633, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22909;
            if (_6769 == 2u)
            {
                _22909 = lerp(_8641, _8649, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22910;
                if (_6769 == 3u)
                {
                    _22910 = float(_22771).xxx;
                }
                else
                {
                    float3 _22911;
                    if (_6769 == 4u)
                    {
                        _22911 = float3(((_19823 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22912;
                        if (_6769 == 5u)
                        {
                            _22912 = float3(((_7920 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22913;
                            if (_6769 == 6u)
                            {
                                _22913 = float3(_21329.xy, _21329.z + _21329.w);
                            }
                            else
                            {
                                float3 _22914;
                                if (_6769 == 7u)
                                {
                                    _22914 = r_current_interpolation_source.Load(int3(_4884, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22915;
                                    if (_6769 == 8u)
                                    {
                                        _22915 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5396, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22916;
                                        if (_6773)
                                        {
                                            uint _18925_dummy_parameter;
                                            uint _18957_dummy_parameter;
                                            _22916 = float3(log((r_depth_tp1.Load(int3(int2(floor(_5396 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18925_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_5396 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18957_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22917;
                                            if (_6776)
                                            {
                                                _22917 = _8641;
                                            }
                                            else
                                            {
                                                float3 _22918;
                                                if (_6769 == 20u)
                                                {
                                                    _22918 = _8625;
                                                }
                                                else
                                                {
                                                    float3 _22919;
                                                    if (_6769 == 21u)
                                                    {
                                                        _22919 = _8633;
                                                    }
                                                    else
                                                    {
                                                        float3 _22920;
                                                        if (_6769 == 22u)
                                                        {
                                                            _22920 = _8649;
                                                        }
                                                        else
                                                        {
                                                            float3 _22921;
                                                            if (_6769 == 18u)
                                                            {
                                                                _22921 = _22330;
                                                            }
                                                            else
                                                            {
                                                                float3 _22922;
                                                                if (_6769 == 19u)
                                                                {
                                                                    _22922 = _22064;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22923;
                                                                    if (_6769 == 23u)
                                                                    {
                                                                        _22923 = _21804;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22924;
                                                                        if (_6769 == 24u)
                                                                        {
                                                                            uint _7272 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7277 = float(rw_nfru_diagnostics.Load<uint>((_7272 + 35u) * 4 + 0));
                                                                            float _21797;
                                                                            if (_7277 > 0.0f)
                                                                            {
                                                                                _21797 = float(rw_nfru_diagnostics.Load<uint>((_7272 + 34u) * 4 + 0)) / _7277;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21797 = 0.0f;
                                                                            }
                                                                            _22924 = float3(float(rw_nfru_diagnostics.Load<uint>((_7272 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7272 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21797);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22924 = _22926;
                                                                        }
                                                                        _22923 = _22924;
                                                                    }
                                                                    _22922 = _22923;
                                                                }
                                                                _22921 = _22922;
                                                            }
                                                            _22920 = _22921;
                                                        }
                                                        _22919 = _22920;
                                                    }
                                                    _22918 = _22919;
                                                }
                                                _22917 = _22918;
                                            }
                                            _22916 = _22917;
                                        }
                                        _22915 = _22916;
                                    }
                                    _22914 = _22915;
                                }
                                _22913 = _22914;
                            }
                            _22912 = _22913;
                        }
                        _22911 = _22912;
                    }
                    _22910 = _22911;
                }
                _22909 = _22910;
            }
            _22908 = _22909;
        }
        float3 _22907;
        if ((_6769 >= 9u) && (_6769 <= 11u))
        {
            uint _7337 = 64u + uint((_20046.y * cbFI_MvDepthLaneSize.x) + _20046.x);
            uint _7341 = rw_nfru_diagnostics.Load<uint>(_7337 * 4 + 0) & 15u;
            float3 _22941;
            if (_6769 == 10u)
            {
                float3 _22906;
                if ((rw_nfru_diagnostics.Load<uint>(_7337 * 4 + 0) & 32u) != 0u)
                {
                    _22906 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22905;
                    if ((rw_nfru_diagnostics.Load<uint>(_7337 * 4 + 0) & 16u) != 0u)
                    {
                        _22905 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7362 = ((rw_nfru_diagnostics.Load<uint>(_7337 * 4 + 0) & 64u) != 0u).xxx;
                        _22905 = float3(_7362.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7362.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7362.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22906 = _22905;
                }
                _22941 = _22906;
            }
            else
            {
                float3 _22942;
                if (_6769 == 11u)
                {
                    uint _7375 = (rw_nfru_diagnostics.Load<uint>(_7337 * 4 + 0) >> 8u) & 15u;
                    uint _7378 = (rw_nfru_diagnostics.Load<uint>(_7337 * 4 + 0) >> 12u) & 15u;
                    float3 _22898;
                    if ((_7341 == 2u) || (_7341 == 3u))
                    {
                        _22898 = _4566[_7341];
                    }
                    else
                    {
                        bool _7390 = _7375 == 3u;
                        bool _7392 = _7378 == 3u;
                        float3 _22899;
                        if (_7390 && _7392)
                        {
                            _22899 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22900;
                            if (_7390)
                            {
                                _22900 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22901;
                                if (_7392)
                                {
                                    _22901 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22902;
                                    if ((_7375 == 4u) || (_7378 == 4u))
                                    {
                                        _22902 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22903;
                                        if ((_7375 == 1u) || (_7378 == 1u))
                                        {
                                            _22903 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23745 = (_7341 == 1u).xxx;
                                            _22903 = float3(_23745.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23745.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23745.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22902 = _22903;
                                    }
                                    _22901 = _22902;
                                }
                                _22900 = _22901;
                            }
                            _22899 = _22900;
                        }
                        _22898 = _22899;
                    }
                    _22942 = _22898;
                }
                else
                {
                    _22942 = _4566[min(_7341, 7u)];
                }
                _22941 = _22942;
            }
            _22907 = _22941;
        }
        else
        {
            _22907 = _22908;
        }
        float4 _22945;
        if ((_6769 >= 14u) && (_6769 <= 16u))
        {
            float2 _22943;
            if (_6769 == 14u)
            {
                uint _7448_dummy_parameter;
                uint _7454_dummy_parameter;
                _22943 = r_flow_tm1.Load(int3(clamp(int2(floor(_5396 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7448_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7454_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22944;
                if (_6769 == 16u)
                {
                    uint _19033 = r_warped_flow_qdata_tm1.Load(int3(_5412, 0)).x & 2147483647u;
                    uint _19065 = uint(max((int((_19033 >> 16u) & 15u) - 6), 0));
                    _22944 = ((float2(float((1 - (2 * int((_19033 >> 15u) & 1u))) * int(((_19033 >> uint(7)) & 127u) << _19065)), float((1 - (2 * int((_19033 >> 14u) & 1u))) * int((_19033 & 127u) << _19065))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22944 = _7920 * float2(cbFI_DisplaySize);
                }
                _22943 = _22944;
            }
            uint2 _7487 = uint2(clamp(round(_22943 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7489 = _7487.x;
            uint _7496 = _7487.y;
            _22945 = float4(float(_7489 & 255u), float((_7489 >> 8u) | ((_7496 & 15u) << 4u)), float(_7496 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22946;
            if (_6769 == 17u)
            {
                _22946 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5412, 0)).x != 0u), _5856, 0.0f, 1.0f);
            }
            else
            {
                _22946 = float4(_22907, 1.0f);
            }
            _22945 = _22946;
        }
        rw_output[_4884] = _22945.xyz;
        if (_7079)
        {
            uint _19110 = uint((_4884.y * cbFI_DisplaySize.x) + _4884.x) * 2u;
            rw_nfru_select.Store<uint>(_19110 * 4 + 0, spvPackHalf2x16(_22945.xy));
            rw_nfru_select.Store<uint>((_19110 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22945.z, (_22771 || (_6769 != 0u)) ? 2.0f : _23003)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7554 = ((uint(_4884.y) * uint(cbFI_DisplaySize.x)) + uint(_4884.x)) * 6u;
            uint _19136 = spvPackHalf2x16(clamp(_8624.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7554 * 4 + 0, (((_19136 & 32767u) >> 4u) | ((((_19136 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8624.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19171 = spvPackHalf2x16(clamp(_8632.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7554 + 1u) * 4 + 0, (((_19171 & 32767u) >> 4u) | ((((_19171 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8632.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19206 = spvPackHalf2x16(clamp(_8640.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7554 + 2u) * 4 + 0, (((_19206 & 32767u) >> 4u) | ((((_19206 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8640.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19241 = spvPackHalf2x16(clamp(_8648.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7554 + 3u) * 4 + 0, (((_19241 & 32767u) >> 4u) | ((((_19241 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8648.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19268 = r_current_interpolation_source.Load(int3(_4884, 0));
            uint _19282 = spvPackHalf2x16(clamp(_19268.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7554 + 4u) * 4 + 0, (((_19282 & 32767u) >> 4u) | ((((_19282 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19268.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _23022;
            if (_22771 || (_6769 != 0u))
            {
                _23022 = 4294967295u;
            }
            else
            {
                uint _19317 = spvPackHalf2x16(clamp(_22945.xy, 0.0f.xx, 65000.0f.xx));
                _23022 = (((_19317 & 32767u) >> 4u) | ((((_19317 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22945.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7554 + 5u) * 4 + 0, _23022);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4884] = float4(r_current_interpolation_source.Load(int3(_4884, 0)).xyz, 1.0f).xyz;
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
