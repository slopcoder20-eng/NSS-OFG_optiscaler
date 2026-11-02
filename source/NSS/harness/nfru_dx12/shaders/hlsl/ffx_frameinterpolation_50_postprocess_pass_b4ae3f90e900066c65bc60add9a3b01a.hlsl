static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19749;

static const int2 _1247[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1256[5] = { 2, 4, 7, 11, 16 };
static const float3 _4539[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4857 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4857.x >= cbFI_DisplaySize.x, _4857.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4857] = float4(r_present_backbuffer.Load(int3(_4857, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4857] = float4(r_current_interpolation_source.Load(int3(_4857, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7737 = cbFI_DisplaySize - int2(1, 1);
                int2 _7738 = clamp(_4857, int2(0, 0), _7737);
                uint _7748 = uint((_7738.y * cbFI_DisplaySize.x) + _7738.x) * 2u;
                uint _7751 = rw_nfru_select.Load<uint>(_7748 * 4 + 0);
                float2 _7752 = spvUnpackHalf2x16(_7751);
                uint _7756 = rw_nfru_select.Load<uint>((_7748 + 1u) * 4 + 0);
                float2 _7757 = spvUnpackHalf2x16(_7756);
                float _7758 = _7752.x;
                float _7760 = _7757.x;
                if (_7757.y > 1.5f)
                {
                    rw_output[_4857] = float4(_7758, _7752.y, _7760, 1.0f).xyz;
                    break;
                }
                int _23179;
                float _23180;
                float3 _23181;
                float _23182;
                float _23183;
                _23183 = 0.0f;
                _23182 = 0.0f;
                _23181 = 0.0f.xxx;
                _23180 = 0.0f;
                _23179 = -2;
                float3 _23186;
                float _23187;
                float _23188;
                float _23189;
                for (; _23179 <= 2; _23183 = _23189, _23182 = _23188, _23181 = _23186, _23180 = _23187, _23179++)
                {
                    _23189 = _23183;
                    _23188 = _23182;
                    _23187 = _23180;
                    _23186 = _23181;
                    for (int _23184 = -2; _23184 <= 2; )
                    {
                        float _7654 = float((_23184 * _23184) + (_23179 * _23179));
                        float _7659 = exp(_7654 * (-0.319999992847442626953125f));
                        int2 _7664 = int2(_23184, _23179);
                        int2 _7774 = clamp(_4857 + (_7664 * int2(2, 2)), int2(0, 0), _7737);
                        uint _7784 = uint((_7774.y * cbFI_DisplaySize.x) + _7774.x) * 2u;
                        float _7681 = exp(_7654 * (-0.5f));
                        int2 _7806 = clamp(_4857 + (_7664 * int2(6, 6)), int2(0, 0), _7737);
                        _23189 += _7681;
                        _23188 += (_7681 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7806.y * cbFI_DisplaySize.x) + _7806.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23187 += _7659;
                        _23186 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7784 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7784 + 1u) * 4 + 0)).x, _19749).xyz * _7659);
                        _23184++;
                        continue;
                    }
                }
                float3 _7711 = _23181 / _23180.xxx;
                rw_output[_4857] = float4(_7711 + ((float4(_7758, _7752.y, _7760, _7757.y).xyz - _7711) * clamp(_23182 / _23183, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5363 = (float2(_4857) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5365 = float2(cbFI_MvDepthLaneSize);
        int2 _5374 = int2(floor(_5363 * _5365));
        int2 _5379 = int2(floor(_5363 * float2(cbFI_FlowLaneSize)));
        float4 _7877 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5363 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7883 = r_warped_filled_flow_tm1.Load(int3(_5379, 0)).xy;
        float2 _7889 = r_warped_filled_motion_tp1.Load(int3(_5374, 0)).xy;
        bool _7911 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19750;
        if (_7911)
        {
            float _7924 = ((2.0f * _5363.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19750 = float2(atan(_7924) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5363.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7924 * _7924))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19750 = _5363;
        }
        bool _5400 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19771;
        bool _19913;
        int2 _19994;
        float3 _22275;
        if (_5400)
        {
            float _19752;
            float _19754;
            _19754 = 2.0f;
            _19752 = -1.0f;
            uint _4951[9];
            float _23190;
            float _23193;
            for (int _19751 = 0; _19751 < 9; _19754 = _23193, _19752 = _23190, _19751++)
            {
                _4951[_19751] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5374 + int2((_19751 % 3) - 1, (_19751 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4951[_19751] != 0u)
                {
                    float _23174;
                    if (_4951[_19751] == 0u)
                    {
                        _23174 = -1.0f;
                    }
                    else
                    {
                        _23174 = float((_4951[_19751] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23193 = min(_19754, _23174);
                    _23190 = max(_19752, _23174);
                }
                else
                {
                    _23193 = _19754;
                    _23190 = _19752;
                }
            }
            float _5446 = float(_19752 >= 0.0f);
            float3 _19317 = 0.0f.xxx;
            _19317.y = _5446;
            float2 _19772;
            bool _19914;
            int2 _19995;
            float3 _22276;
            if ((_19752 - _19754) > 0.0199999995529651641845703125f)
            {
                float _19760;
                int2 _19761;
                float2 _19762;
                int2 _19764;
                float2 _19770;
                _19770 = _7889;
                _19764 = _5374;
                _19762 = _7889;
                _19761 = _5374;
                _19760 = -1.0f;
                float _23198;
                int2 _23202;
                float2 _23213;
                int2 _23224;
                float2 _23257;
                float _23642;
                int _19759 = 0;
                float _23155 = 1000000000.0f;
                for (; _19759 < 9; _23155 = _23642, _19770 = _23257, _19764 = _23224, _19762 = _23213, _19761 = _23202, _19760 = _23198, _19759++)
                {
                    if (_4951[_19759] == 0u)
                    {
                        _23642 = _23155;
                        _23257 = _19770;
                        _23224 = _19764;
                        _23213 = _19762;
                        _23202 = _19761;
                        _23198 = _19760;
                        continue;
                    }
                    int2 _5481 = clamp(_5374 + int2((_19759 % 3) - 1, (_19759 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _7999 = _4951[_19759] & 2147483647u;
                    uint _8031 = uint(max((int((_7999 >> 16u) & 15u) - 6), 0));
                    float2 _5487 = (float2(float((1 - (2 * int((_7999 >> 15u) & 1u))) * int(((_7999 >> uint(7)) & 127u) << _8031)), float((1 - (2 * int((_7999 >> 14u) & 1u))) * int((_7999 & 127u) << _8031))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23141;
                    if (_4951[_19759] == 0u)
                    {
                        _23141 = -1.0f;
                    }
                    else
                    {
                        _23141 = float((_4951[_19759] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5492 = _23141 - 0.100000001490116119384765625f;
                    float2 _23142;
                    if (_7911)
                    {
                        float2 _8108 = clamp((((_19750 + (_5487 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8111 = tan(_8108.x);
                        _23142 = (float2(_8111 / cbFI_DeviceToViewDepth.z, (tan(_8108.y) * sqrt(1.0f + (_8111 * _8111))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23142 = _19750 + (_5487 * cbFI_Timestep);
                    }
                    float _5499 = cbFI_Timestep - 1.0f;
                    float2 _23143;
                    if (_7911)
                    {
                        float2 _8179 = clamp((((_19750 + (_5487 * _5499)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8182 = tan(_8179.x);
                        _23143 = (float2(_8182 / cbFI_DeviceToViewDepth.z, (tan(_8179.y) * sqrt(1.0f + (_8182 * _8182))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23143 = _19750 + (_5487 * _5499);
                    }
                    bool _8215 = all(bool2(_23142.x > 0.0f.xx.x, _23142.y > 0.0f.xx.y));
                    bool _8221;
                    if (_8215)
                    {
                        _8221 = all(bool2(_23142.x < 1.0f.xx.x, _23142.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8221 = _8215;
                    }
                    float _23146;
                    if (_8221)
                    {
                        uint _8228_dummy_parameter;
                        _23146 = max((_5492 - (log(((r_depth_tm1.Load(int3(int2(floor(_23142 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8228_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23146 = 0.0f;
                    }
                    bool _8258 = all(bool2(_23143.x > 0.0f.xx.x, _23143.y > 0.0f.xx.y));
                    bool _8264;
                    if (_8258)
                    {
                        _8264 = all(bool2(_23143.x < 1.0f.xx.x, _23143.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8264 = _8258;
                    }
                    float _23147;
                    if (_8264)
                    {
                        uint _8271_dummy_parameter;
                        _23147 = _23146 + max((_5492 - (log(((r_depth_tp1.Load(int3(int2(floor(_23143 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8271_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23147 = _23146;
                    }
                    float _23199;
                    int2 _23203;
                    float2 _23214;
                    int2 _23225;
                    float2 _23258;
                    float _23643;
                    if (_23147 == 0.0f)
                    {
                        bool _5534 = _5492 > _19760;
                        bool2 _23651 = _5534.xx;
                        _23643 = _23155;
                        _23258 = float2(_23651.x ? _5487.x : _19770.x, _23651.y ? _5487.y : _19770.y);
                        _23225 = int2(_23651.x ? _5481.x : _19764.x, _23651.y ? _5481.y : _19764.y);
                        _23214 = _19762;
                        _23203 = _19761;
                        _23199 = _5534 ? _5492 : _19760;
                    }
                    else
                    {
                        bool _5543 = _23147 < _23155;
                        bool2 _23647 = _5543.xx;
                        _23643 = _5543 ? _23147 : _23155;
                        _23258 = _19770;
                        _23225 = _19764;
                        _23214 = float2(_23647.x ? _5487.x : _19762.x, _23647.y ? _5487.y : _19762.y);
                        _23203 = int2(_23647.x ? _5481.x : _19761.x, _23647.y ? _5481.y : _19761.y);
                        _23199 = _19760;
                    }
                    _23642 = _23643;
                    _23257 = _23258;
                    _23224 = _23225;
                    _23213 = _23214;
                    _23202 = _23203;
                    _23198 = _23199;
                }
                bool _5555 = _19760 < 0.0f;
                bool2 _23657 = _5555.xx;
                int2 _23660 = int2(_23657.x ? _19761.x : _19764.x, _23657.y ? _19761.y : _19764.y);
                _22276 = float3(1.0f, _5446, float(any(bool2(_23660.x != _5374.x, _23660.y != _5374.y))));
                _19995 = _23660;
                _19914 = _5555 ? false : true;
                _19772 = float2(_23657.x ? _19762.x : _19770.x, _23657.y ? _19762.y : _19770.y);
            }
            else
            {
                _22276 = _19317;
                _19995 = _5374;
                _19914 = false;
                _19772 = _7889;
            }
            _22275 = _22276;
            _19994 = _19995;
            _19913 = _19914;
            _19771 = _19772;
        }
        else
        {
            _22275 = 0.0f.xxx;
            _19994 = _5374;
            _19913 = false;
            _19771 = _7889;
        }
        float2 _19773;
        if (_7911)
        {
            float2 _8336 = clamp((((_19750 + (_19771 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8339 = tan(_8336.x);
            _19773 = (float2(_8339 / cbFI_DeviceToViewDepth.z, (tan(_8336.y) * sqrt(1.0f + (_8339 * _8339))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19773 = _19750 + (_19771 * cbFI_Timestep);
        }
        float _5578 = cbFI_Timestep - 1.0f;
        float2 _19775;
        if (_7911)
        {
            float2 _8407 = clamp((((_19750 + (_19771 * _5578)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8410 = tan(_8407.x);
            _19775 = (float2(_8410 / cbFI_DeviceToViewDepth.z, (tan(_8407.y) * sqrt(1.0f + (_8410 * _8410))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19775 = _19750 + (_19771 * _5578);
        }
        float _5583 = -cbFI_Timestep;
        float2 _19776;
        if (_7911)
        {
            float2 _8478 = clamp((((_19750 + (_7883 * _5583)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8481 = tan(_8478.x);
            _19776 = (float2(_8481 / cbFI_DeviceToViewDepth.z, (tan(_8478.y) * sqrt(1.0f + (_8481 * _8481))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19776 = _19750 + (_7883 * _5583);
        }
        float _5588 = 1.0f - cbFI_Timestep;
        float2 _19777;
        if (_7911)
        {
            float2 _8549 = clamp((((_19750 + (_7883 * _5588)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8552 = tan(_8549.x);
            _19777 = (float2(_8552 / cbFI_DeviceToViewDepth.z, (tan(_8549.y) * sqrt(1.0f + (_8552 * _8552))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19777 = _19750 + (_7883 * _5588);
        }
        float4 _8587 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19773, 0.0f);
        float3 _8588 = _8587.xyz;
        float4 _8595 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19775, 0.0f);
        float3 _8596 = _8595.xyz;
        float4 _8603 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19776, 0.0f);
        float3 _8604 = _8603.xyz;
        float4 _8611 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19777, 0.0f);
        float3 _8612 = _8611.xyz;
        float4 _8626 = exp(_7877 - max(max(max(_7877.x, _7877.y), _7877.z), _7877.w).xxxx);
        float4 _8633 = _8626 / (dot(_8626, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5604 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19984;
        float _21292;
        if (_5604)
        {
            float2 _5610 = 0.5f.xx / _5365;
            float _5613 = _5610.x;
            float _5614 = -_5613;
            float _5616 = _5610.y;
            float _5617 = -_5616;
            float2 _5619 = _5363 + float2(_5614, _5617);
            float2 _5621 = float2(cbFI_DisplaySize);
            bool _19794;
            do
            {
                bool _8713 = all(bool2(_5619.x > 0.0f.xx.x, _5619.y > 0.0f.xx.y));
                bool _8719;
                if (_8713)
                {
                    _8719 = all(bool2(_5619.x < 1.0f.xx.x, _5619.y < 1.0f.xx.y));
                }
                else
                {
                    _8719 = _8713;
                }
                if (!_8719)
                {
                    _19794 = false;
                    break;
                }
                uint _8726_dummy_parameter;
                float4x4 _19792;
                do
                {
                    float4x4 _8740;
                    bool _19791;
                    do
                    {
                        _8740 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19791 = false;
                            break;
                        }
                        uint _8774 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8774 + 32u) * 4 + 0) != 1u)
                        {
                            _19791 = false;
                            break;
                        }
                        uint _19788;
                        _19788 = 0u;
                        for (; _19788 < 4u; _19788++)
                        {
                            for (uint _19789 = 0u; _19789 < 4u; )
                            {
                                _8740[_19788][_19789] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8774 + (_19788 * 4u)) + _19789) * 4 + 0));
                                _19789++;
                                continue;
                            }
                        }
                        _19791 = true;
                        break;
                    } while(false);
                    if (_19791)
                    {
                        _19792 = _8740;
                        break;
                    }
                    _19792 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19793;
                do
                {
                    float _8851 = _5619.x;
                    float _8854 = 1.0f - _5619.y;
                    float4 _8865 = mul(float4((float2(_8851, _8854) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5619 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8726_dummy_parameter))))), 0)).x, 1.0f), _19792);
                    float _8867 = _8865.w;
                    if (!(_8867 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19793 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8880 = ((_8865.xy / _8867.xx) + 1.0f.xx) * 0.5f;
                    _19793 = float2(_8880.x - _8851, _8854 - _8880.y);
                    break;
                } while(false);
                float2 _8677 = abs(_19793);
                if (any(bool2(_8677.x > 100000.0f.xx.x, _8677.y > 100000.0f.xx.y)))
                {
                    _19794 = false;
                    break;
                }
                float _8685 = length(_19793 * _5621);
                uint _8900_dummy_parameter;
                bool _8699 = _8685 > ((8.0f * _5621.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8706;
                if (_8699)
                {
                    _8706 = length((r_motion_tp1.Load(int3(int2(floor(_5619 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8900_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621) < (0.20000000298023223876953125f * _8685);
                }
                else
                {
                    _8706 = _8699;
                }
                _19794 = _8706;
                break;
            } while(false);
            float2 _5631 = _5363 + float2(_5613, _5617);
            bool _19801;
            do
            {
                bool _8986 = all(bool2(_5631.x > 0.0f.xx.x, _5631.y > 0.0f.xx.y));
                bool _8992;
                if (_8986)
                {
                    _8992 = all(bool2(_5631.x < 1.0f.xx.x, _5631.y < 1.0f.xx.y));
                }
                else
                {
                    _8992 = _8986;
                }
                if (!_8992)
                {
                    _19801 = false;
                    break;
                }
                uint _8999_dummy_parameter;
                float4x4 _19799;
                do
                {
                    float4x4 _9013;
                    bool _19798;
                    do
                    {
                        _9013 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19798 = false;
                            break;
                        }
                        uint _9047 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9047 + 32u) * 4 + 0) != 1u)
                        {
                            _19798 = false;
                            break;
                        }
                        uint _19795;
                        _19795 = 0u;
                        for (; _19795 < 4u; _19795++)
                        {
                            for (uint _19796 = 0u; _19796 < 4u; )
                            {
                                _9013[_19795][_19796] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9047 + (_19795 * 4u)) + _19796) * 4 + 0));
                                _19796++;
                                continue;
                            }
                        }
                        _19798 = true;
                        break;
                    } while(false);
                    if (_19798)
                    {
                        _19799 = _9013;
                        break;
                    }
                    _19799 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19800;
                do
                {
                    float _9124 = _5631.x;
                    float _9127 = 1.0f - _5631.y;
                    float4 _9138 = mul(float4((float2(_9124, _9127) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5631 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8999_dummy_parameter))))), 0)).x, 1.0f), _19799);
                    float _9140 = _9138.w;
                    if (!(_9140 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19800 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9153 = ((_9138.xy / _9140.xx) + 1.0f.xx) * 0.5f;
                    _19800 = float2(_9153.x - _9124, _9127 - _9153.y);
                    break;
                } while(false);
                float2 _8950 = abs(_19800);
                if (any(bool2(_8950.x > 100000.0f.xx.x, _8950.y > 100000.0f.xx.y)))
                {
                    _19801 = false;
                    break;
                }
                float _8958 = length(_19800 * _5621);
                uint _9173_dummy_parameter;
                bool _8972 = _8958 > ((8.0f * _5621.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8979;
                if (_8972)
                {
                    _8979 = length((r_motion_tp1.Load(int3(int2(floor(_5631 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9173_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621) < (0.20000000298023223876953125f * _8958);
                }
                else
                {
                    _8979 = _8972;
                }
                _19801 = _8979;
                break;
            } while(false);
            float2 _5644 = _5363 + float2(_5614, _5616);
            bool _19808;
            do
            {
                bool _9259 = all(bool2(_5644.x > 0.0f.xx.x, _5644.y > 0.0f.xx.y));
                bool _9265;
                if (_9259)
                {
                    _9265 = all(bool2(_5644.x < 1.0f.xx.x, _5644.y < 1.0f.xx.y));
                }
                else
                {
                    _9265 = _9259;
                }
                if (!_9265)
                {
                    _19808 = false;
                    break;
                }
                uint _9272_dummy_parameter;
                float4x4 _19806;
                do
                {
                    float4x4 _9286;
                    bool _19805;
                    do
                    {
                        _9286 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19805 = false;
                            break;
                        }
                        uint _9320 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9320 + 32u) * 4 + 0) != 1u)
                        {
                            _19805 = false;
                            break;
                        }
                        uint _19802;
                        _19802 = 0u;
                        for (; _19802 < 4u; _19802++)
                        {
                            for (uint _19803 = 0u; _19803 < 4u; )
                            {
                                _9286[_19802][_19803] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9320 + (_19802 * 4u)) + _19803) * 4 + 0));
                                _19803++;
                                continue;
                            }
                        }
                        _19805 = true;
                        break;
                    } while(false);
                    if (_19805)
                    {
                        _19806 = _9286;
                        break;
                    }
                    _19806 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19807;
                do
                {
                    float _9397 = _5644.x;
                    float _9400 = 1.0f - _5644.y;
                    float4 _9411 = mul(float4((float2(_9397, _9400) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5644 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9272_dummy_parameter))))), 0)).x, 1.0f), _19806);
                    float _9413 = _9411.w;
                    if (!(_9413 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19807 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9426 = ((_9411.xy / _9413.xx) + 1.0f.xx) * 0.5f;
                    _19807 = float2(_9426.x - _9397, _9400 - _9426.y);
                    break;
                } while(false);
                float2 _9223 = abs(_19807);
                if (any(bool2(_9223.x > 100000.0f.xx.x, _9223.y > 100000.0f.xx.y)))
                {
                    _19808 = false;
                    break;
                }
                float _9231 = length(_19807 * _5621);
                uint _9446_dummy_parameter;
                bool _9245 = _9231 > ((8.0f * _5621.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9252;
                if (_9245)
                {
                    _9252 = length((r_motion_tp1.Load(int3(int2(floor(_5644 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9446_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621) < (0.20000000298023223876953125f * _9231);
                }
                else
                {
                    _9252 = _9245;
                }
                _19808 = _9252;
                break;
            } while(false);
            float2 _5656 = _5363 + _5610;
            bool _19815;
            do
            {
                bool _9532 = all(bool2(_5656.x > 0.0f.xx.x, _5656.y > 0.0f.xx.y));
                bool _9538;
                if (_9532)
                {
                    _9538 = all(bool2(_5656.x < 1.0f.xx.x, _5656.y < 1.0f.xx.y));
                }
                else
                {
                    _9538 = _9532;
                }
                if (!_9538)
                {
                    _19815 = false;
                    break;
                }
                uint _9545_dummy_parameter;
                float4x4 _19813;
                do
                {
                    float4x4 _9559;
                    bool _19812;
                    do
                    {
                        _9559 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19812 = false;
                            break;
                        }
                        uint _9593 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9593 + 32u) * 4 + 0) != 1u)
                        {
                            _19812 = false;
                            break;
                        }
                        uint _19809;
                        _19809 = 0u;
                        for (; _19809 < 4u; _19809++)
                        {
                            for (uint _19810 = 0u; _19810 < 4u; )
                            {
                                _9559[_19809][_19810] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9593 + (_19809 * 4u)) + _19810) * 4 + 0));
                                _19810++;
                                continue;
                            }
                        }
                        _19812 = true;
                        break;
                    } while(false);
                    if (_19812)
                    {
                        _19813 = _9559;
                        break;
                    }
                    _19813 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19814;
                do
                {
                    float _9670 = _5656.x;
                    float _9673 = 1.0f - _5656.y;
                    float4 _9684 = mul(float4((float2(_9670, _9673) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5656 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9545_dummy_parameter))))), 0)).x, 1.0f), _19813);
                    float _9686 = _9684.w;
                    if (!(_9686 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19814 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9699 = ((_9684.xy / _9686.xx) + 1.0f.xx) * 0.5f;
                    _19814 = float2(_9699.x - _9670, _9673 - _9699.y);
                    break;
                } while(false);
                float2 _9496 = abs(_19814);
                if (any(bool2(_9496.x > 100000.0f.xx.x, _9496.y > 100000.0f.xx.y)))
                {
                    _19815 = false;
                    break;
                }
                float _9504 = length(_19814 * _5621);
                uint _9719_dummy_parameter;
                bool _9518 = _9504 > ((8.0f * _5621.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9525;
                if (_9518)
                {
                    _9525 = length((r_motion_tp1.Load(int3(int2(floor(_5656 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9719_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621) < (0.20000000298023223876953125f * _9504);
                }
                else
                {
                    _9525 = _9518;
                }
                _19815 = _9525;
                break;
            } while(false);
            float _5662 = 0.25f * (((float(_19794) + float(_19801)) + float(_19808)) + float(_19815));
            float4 _19985;
            if (_5662 < 1.0f)
            {
                bool _19822;
                do
                {
                    bool _9805 = all(bool2(_19773.x > 0.0f.xx.x, _19773.y > 0.0f.xx.y));
                    bool _9811;
                    if (_9805)
                    {
                        _9811 = all(bool2(_19773.x < 1.0f.xx.x, _19773.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9811 = _9805;
                    }
                    if (!_9811)
                    {
                        _19822 = false;
                        break;
                    }
                    uint _9818_dummy_parameter;
                    float4x4 _19820;
                    do
                    {
                        float4x4 _9832;
                        bool _19819;
                        do
                        {
                            _9832 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19819 = false;
                                break;
                            }
                            uint _9866 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9866 + 32u) * 4 + 0) != 1u)
                            {
                                _19819 = false;
                                break;
                            }
                            uint _19816;
                            _19816 = 0u;
                            for (; _19816 < 4u; _19816++)
                            {
                                for (uint _19817 = 0u; _19817 < 4u; )
                                {
                                    _9832[_19816][_19817] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9866 + (_19816 * 4u)) + _19817) * 4 + 0));
                                    _19817++;
                                    continue;
                                }
                            }
                            _19819 = true;
                            break;
                        } while(false);
                        if (_19819)
                        {
                            _19820 = _9832;
                            break;
                        }
                        _19820 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19821;
                    do
                    {
                        float _9946 = 1.0f - _19773.y;
                        float4 _9957 = mul(float4((float2(_19773.x, _9946) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19773 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9818_dummy_parameter))))), 0)).x, 1.0f), _19820);
                        float _9959 = _9957.w;
                        if (!(_9959 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19821 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9972 = ((_9957.xy / _9959.xx) + 1.0f.xx) * 0.5f;
                        _19821 = float2(_9972.x - _19773.x, _9946 - _9972.y);
                        break;
                    } while(false);
                    float2 _9769 = abs(_19821);
                    if (any(bool2(_9769.x > 100000.0f.xx.x, _9769.y > 100000.0f.xx.y)))
                    {
                        _19822 = false;
                        break;
                    }
                    float _9777 = length(_19821 * _5621);
                    uint _9992_dummy_parameter;
                    bool _9791 = _9777 > ((8.0f * _5621.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9798;
                    if (_9791)
                    {
                        _9798 = length((r_motion_tp1.Load(int3(int2(floor(_19773 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9992_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621) < (0.20000000298023223876953125f * _9777);
                    }
                    else
                    {
                        _9798 = _9791;
                    }
                    _19822 = _9798;
                    break;
                } while(false);
                bool _19829;
                do
                {
                    bool _10078 = all(bool2(_19775.x > 0.0f.xx.x, _19775.y > 0.0f.xx.y));
                    bool _10084;
                    if (_10078)
                    {
                        _10084 = all(bool2(_19775.x < 1.0f.xx.x, _19775.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10084 = _10078;
                    }
                    if (!_10084)
                    {
                        _19829 = false;
                        break;
                    }
                    uint _10091_dummy_parameter;
                    float4x4 _19827;
                    do
                    {
                        float4x4 _10105;
                        bool _19826;
                        do
                        {
                            _10105 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19826 = false;
                                break;
                            }
                            uint _10139 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10139 + 32u) * 4 + 0) != 1u)
                            {
                                _19826 = false;
                                break;
                            }
                            uint _19823;
                            _19823 = 0u;
                            for (; _19823 < 4u; _19823++)
                            {
                                for (uint _19824 = 0u; _19824 < 4u; )
                                {
                                    _10105[_19823][_19824] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10139 + (_19823 * 4u)) + _19824) * 4 + 0));
                                    _19824++;
                                    continue;
                                }
                            }
                            _19826 = true;
                            break;
                        } while(false);
                        if (_19826)
                        {
                            _19827 = _10105;
                            break;
                        }
                        _19827 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19828;
                    do
                    {
                        float _10219 = 1.0f - _19775.y;
                        float4 _10230 = mul(float4((float2(_19775.x, _10219) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19775 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10091_dummy_parameter))))), 0)).x, 1.0f), _19827);
                        float _10232 = _10230.w;
                        if (!(_10232 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19828 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10245 = ((_10230.xy / _10232.xx) + 1.0f.xx) * 0.5f;
                        _19828 = float2(_10245.x - _19775.x, _10219 - _10245.y);
                        break;
                    } while(false);
                    float2 _10042 = abs(_19828);
                    if (any(bool2(_10042.x > 100000.0f.xx.x, _10042.y > 100000.0f.xx.y)))
                    {
                        _19829 = false;
                        break;
                    }
                    float _10050 = length(_19828 * _5621);
                    uint _10265_dummy_parameter;
                    bool _10064 = _10050 > ((8.0f * _5621.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10071;
                    if (_10064)
                    {
                        _10071 = length((r_motion_tp1.Load(int3(int2(floor(_19775 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10265_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621) < (0.20000000298023223876953125f * _10050);
                    }
                    else
                    {
                        _10071 = _10064;
                    }
                    _19829 = _10071;
                    break;
                } while(false);
                bool _19836;
                do
                {
                    bool _10351 = all(bool2(_19776.x > 0.0f.xx.x, _19776.y > 0.0f.xx.y));
                    bool _10357;
                    if (_10351)
                    {
                        _10357 = all(bool2(_19776.x < 1.0f.xx.x, _19776.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10357 = _10351;
                    }
                    if (!_10357)
                    {
                        _19836 = false;
                        break;
                    }
                    uint _10364_dummy_parameter;
                    float4x4 _19834;
                    do
                    {
                        float4x4 _10378;
                        bool _19833;
                        do
                        {
                            _10378 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19833 = false;
                                break;
                            }
                            uint _10412 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10412 + 32u) * 4 + 0) != 1u)
                            {
                                _19833 = false;
                                break;
                            }
                            uint _19830;
                            _19830 = 0u;
                            for (; _19830 < 4u; _19830++)
                            {
                                for (uint _19831 = 0u; _19831 < 4u; )
                                {
                                    _10378[_19830][_19831] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10412 + (_19830 * 4u)) + _19831) * 4 + 0));
                                    _19831++;
                                    continue;
                                }
                            }
                            _19833 = true;
                            break;
                        } while(false);
                        if (_19833)
                        {
                            _19834 = _10378;
                            break;
                        }
                        _19834 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19835;
                    do
                    {
                        float _10492 = 1.0f - _19776.y;
                        float4 _10503 = mul(float4((float2(_19776.x, _10492) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19776 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10364_dummy_parameter))))), 0)).x, 1.0f), _19834);
                        float _10505 = _10503.w;
                        if (!(_10505 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19835 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10518 = ((_10503.xy / _10505.xx) + 1.0f.xx) * 0.5f;
                        _19835 = float2(_10518.x - _19776.x, _10492 - _10518.y);
                        break;
                    } while(false);
                    float2 _10315 = abs(_19835);
                    if (any(bool2(_10315.x > 100000.0f.xx.x, _10315.y > 100000.0f.xx.y)))
                    {
                        _19836 = false;
                        break;
                    }
                    float _10323 = length(_19835 * _5621);
                    uint _10538_dummy_parameter;
                    bool _10337 = _10323 > ((8.0f * _5621.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10344;
                    if (_10337)
                    {
                        _10344 = length((r_motion_tp1.Load(int3(int2(floor(_19776 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10538_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621) < (0.20000000298023223876953125f * _10323);
                    }
                    else
                    {
                        _10344 = _10337;
                    }
                    _19836 = _10344;
                    break;
                } while(false);
                bool _19843;
                do
                {
                    bool _10624 = all(bool2(_19777.x > 0.0f.xx.x, _19777.y > 0.0f.xx.y));
                    bool _10630;
                    if (_10624)
                    {
                        _10630 = all(bool2(_19777.x < 1.0f.xx.x, _19777.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10630 = _10624;
                    }
                    if (!_10630)
                    {
                        _19843 = false;
                        break;
                    }
                    uint _10637_dummy_parameter;
                    float4x4 _19841;
                    do
                    {
                        float4x4 _10651;
                        bool _19840;
                        do
                        {
                            _10651 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19840 = false;
                                break;
                            }
                            uint _10685 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10685 + 32u) * 4 + 0) != 1u)
                            {
                                _19840 = false;
                                break;
                            }
                            uint _19837;
                            _19837 = 0u;
                            for (; _19837 < 4u; _19837++)
                            {
                                for (uint _19838 = 0u; _19838 < 4u; )
                                {
                                    _10651[_19837][_19838] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10685 + (_19837 * 4u)) + _19838) * 4 + 0));
                                    _19838++;
                                    continue;
                                }
                            }
                            _19840 = true;
                            break;
                        } while(false);
                        if (_19840)
                        {
                            _19841 = _10651;
                            break;
                        }
                        _19841 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19842;
                    do
                    {
                        float _10765 = 1.0f - _19777.y;
                        float4 _10776 = mul(float4((float2(_19777.x, _10765) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19777 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10637_dummy_parameter))))), 0)).x, 1.0f), _19841);
                        float _10778 = _10776.w;
                        if (!(_10778 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19842 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10791 = ((_10776.xy / _10778.xx) + 1.0f.xx) * 0.5f;
                        _19842 = float2(_10791.x - _19777.x, _10765 - _10791.y);
                        break;
                    } while(false);
                    float2 _10588 = abs(_19842);
                    if (any(bool2(_10588.x > 100000.0f.xx.x, _10588.y > 100000.0f.xx.y)))
                    {
                        _19843 = false;
                        break;
                    }
                    float _10596 = length(_19842 * _5621);
                    uint _10811_dummy_parameter;
                    bool _10610 = _10596 > ((8.0f * _5621.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10617;
                    if (_10610)
                    {
                        _10617 = length((r_motion_tp1.Load(int3(int2(floor(_19777 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10811_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5621) < (0.20000000298023223876953125f * _10596);
                    }
                    else
                    {
                        _10617 = _10610;
                    }
                    _19843 = _10617;
                    break;
                } while(false);
                float4 _5689 = _8633 * float4(_19822 ? 0.0f : 1.0f, _19829 ? 0.0f : 1.0f, _19836 ? 0.0f : 1.0f, _19843 ? 0.0f : 1.0f);
                float _5691 = dot(_5689, 1.0f.xxxx);
                float4 _19986;
                if (_5691 > 0.001000000047497451305389404296875f)
                {
                    _19986 = _5689 / _5691.xxxx;
                }
                else
                {
                    _19986 = _8633;
                }
                _19985 = _19986;
            }
            else
            {
                _19985 = _8633;
            }
            _21292 = _5662;
            _19984 = _19985;
        }
        else
        {
            _21292 = 0.0f;
            _19984 = _8633;
        }
        bool _5708 = _5400 && (!_19913);
        bool _5717;
        if (_5708)
        {
            _5717 = (_19984.z + _19984.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5717 = _5708;
        }
        bool _5728;
        if (_5717)
        {
            _5728 = length((_19776 - _19773) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5728 = _5717;
        }
        bool _20073;
        if (_5728)
        {
            uint4 _10840 = r_warped_motion_qdata_tp1.Load(int3(_19994, 0));
            uint _10841 = _10840.x;
            bool _20076;
            if (_10841 != 0u)
            {
                float _20062;
                if (_10841 == 0u)
                {
                    _20062 = -1.0f;
                }
                else
                {
                    _20062 = float((_10841 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5738 = _20062 - 0.12000000476837158203125f;
                bool _10860 = all(bool2(_19776.x > 0.0f.xx.x, _19776.y > 0.0f.xx.y));
                bool _10866;
                if (_10860)
                {
                    _10866 = all(bool2(_19776.x < 1.0f.xx.x, _19776.y < 1.0f.xx.y));
                }
                else
                {
                    _10866 = _10860;
                }
                bool _5748;
                if (_10866)
                {
                    uint _10873_dummy_parameter;
                    _5748 = (log(((r_depth_tm1.Load(int3(int2(floor(_19776 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10873_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5738;
                }
                else
                {
                    _5748 = _10866;
                }
                bool _5762;
                if (!_5748)
                {
                    bool _10903 = all(bool2(_19777.x > 0.0f.xx.x, _19777.y > 0.0f.xx.y));
                    bool _10909;
                    if (_10903)
                    {
                        _10909 = all(bool2(_19777.x < 1.0f.xx.x, _19777.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10909 = _10903;
                    }
                    bool _5760;
                    if (_10909)
                    {
                        uint _10916_dummy_parameter;
                        _5760 = (log(((r_depth_tp1.Load(int3(int2(floor(_19777 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10916_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5738;
                    }
                    else
                    {
                        _5760 = _10909;
                    }
                    _5762 = _5760;
                }
                else
                {
                    _5762 = _5748;
                }
                _20076 = _5762;
            }
            else
            {
                _20076 = false;
            }
            _20073 = _20076;
        }
        else
        {
            _20073 = false;
        }
        bool _5767 = _19913 || _20073;
        bool _5772;
        if (_5767)
        {
            bool _10946 = all(bool2(_19773.x > 0.0f.xx.x, _19773.y > 0.0f.xx.y));
            bool _10952;
            if (_10946)
            {
                _10952 = all(bool2(_19773.x < 1.0f.xx.x, _19773.y < 1.0f.xx.y));
            }
            else
            {
                _10952 = _10946;
            }
            _5772 = _10952;
        }
        else
        {
            _5772 = _5767;
        }
        bool _5777;
        if (_5772)
        {
            bool _10957 = all(bool2(_19775.x > 0.0f.xx.x, _19775.y > 0.0f.xx.y));
            bool _10963;
            if (_10957)
            {
                _10963 = all(bool2(_19775.x < 1.0f.xx.x, _19775.y < 1.0f.xx.y));
            }
            else
            {
                _10963 = _10957;
            }
            _5777 = _10963;
        }
        else
        {
            _5777 = _5772;
        }
        float4 _20196;
        if (_5777)
        {
            float _5783 = _19984.x + _19984.y;
            float _5788 = _19984.z + _19984.w;
            float _20091;
            if (_5783 > 0.001000000047497451305389404296875f)
            {
                _20091 = _19984.x / _5783;
            }
            else
            {
                _20091 = _5588;
            }
            _20196 = float4(_19984.x + (_5788 * _20091), _19984.y + (_5788 * (1.0f - _20091)), 0.0f, 0.0f);
        }
        else
        {
            _20196 = _19984;
        }
        bool _10991 = (cbFI_pad0 & 1024u) != 0u;
        bool _10967 = !_10991;
        bool _10968 = !_10967;
        bool _10985;
        if (_10968)
        {
            _10985 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19994.y * cbFI_MvDepthLaneSize.x) + _19994.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _10985 = _10967;
        }
        bool _11017;
        if (_10968)
        {
            _11017 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5379.y * cbFI_FlowLaneSize.x) + _5379.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11017 = _10967;
        }
        float _5823 = float(_11017);
        bool _20217;
        float4 _20256;
        float3 _22010;
        if (_10991)
        {
            bool _5833;
            if (_10985)
            {
                _5833 = all(bool2(_19773.x > 0.0f.xx.x, _19773.y > 0.0f.xx.y));
            }
            else
            {
                _5833 = _10985;
            }
            bool _5839;
            if (_5833)
            {
                _5839 = all(bool2(_19773.x < 1.0f.xx.x, _19773.y < 1.0f.xx.y));
            }
            else
            {
                _5839 = _5833;
            }
            bool _5846;
            if (_10985)
            {
                _5846 = all(bool2(_19775.x > 0.0f.xx.x, _19775.y > 0.0f.xx.y));
            }
            else
            {
                _5846 = _10985;
            }
            bool _5852;
            if (_5846)
            {
                _5852 = all(bool2(_19775.x < 1.0f.xx.x, _19775.y < 1.0f.xx.y));
            }
            else
            {
                _5852 = _5846;
            }
            bool _5859;
            if (_11017)
            {
                _5859 = all(bool2(_19776.x > 0.0f.xx.x, _19776.y > 0.0f.xx.y));
            }
            else
            {
                _5859 = _11017;
            }
            bool _5865;
            if (_5859)
            {
                _5865 = all(bool2(_19776.x < 1.0f.xx.x, _19776.y < 1.0f.xx.y));
            }
            else
            {
                _5865 = _5859;
            }
            bool _5872;
            if (_11017)
            {
                _5872 = all(bool2(_19777.x > 0.0f.xx.x, _19777.y > 0.0f.xx.y));
            }
            else
            {
                _5872 = _11017;
            }
            bool _5878;
            if (_5872)
            {
                _5878 = all(bool2(_19777.x < 1.0f.xx.x, _19777.y < 1.0f.xx.y));
            }
            else
            {
                _5878 = _5872;
            }
            bool _5880 = !_10985;
            if (_5880)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11059;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11059);
                }
            }
            bool _5885 = !_11017;
            if (_5885)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11069;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11069);
                }
            }
            if (_10985 && _5885)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11079;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11079);
                }
            }
            if (_5880 && _11017)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11089;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11089);
                }
            }
            float _5904 = float(_5839);
            float _5906 = float(_5852);
            bool _5909 = _5865 && _5878;
            float _20125;
            if (_5909)
            {
                _20125 = 1.0f;
            }
            else
            {
                _20125 = (_5865 || _5878) ? 0.5f : 0.0f;
            }
            bool _20140;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5839)) && (!_5852))
            {
                bool _5939;
                if (_5909)
                {
                    float _20133;
                    do
                    {
                        bool _11173 = all(bool2(_19776.x > 0.0f.xx.x, _19776.y > 0.0f.xx.y));
                        bool _11179;
                        if (_11173)
                        {
                            _11179 = all(bool2(_19776.x < 1.0f.xx.x, _19776.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11179 = _11173;
                        }
                        bool _11110 = !_11179;
                        bool _11117;
                        if (!_11110)
                        {
                            bool _11184 = all(bool2(_19777.x > 0.0f.xx.x, _19777.y > 0.0f.xx.y));
                            bool _11190;
                            if (_11184)
                            {
                                _11190 = all(bool2(_19777.x < 1.0f.xx.x, _19777.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11190 = _11184;
                            }
                            _11117 = !_11190;
                        }
                        else
                        {
                            _11117 = _11110;
                        }
                        if (_11117)
                        {
                            _20133 = 0.0f;
                            break;
                        }
                        uint _11197_dummy_parameter;
                        uint _11213_dummy_parameter;
                        float4x4 _20132;
                        do
                        {
                            float4x4 _11227;
                            bool _20131;
                            do
                            {
                                _11227 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20131 = false;
                                    break;
                                }
                                uint _11261 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11261 + 32u) * 4 + 0) != 1u)
                                {
                                    _20131 = false;
                                    break;
                                }
                                uint _20128;
                                _20128 = 0u;
                                for (; _20128 < 4u; _20128++)
                                {
                                    for (uint _20129 = 0u; _20129 < 4u; )
                                    {
                                        _11227[_20128][_20129] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11261 + 16u) + (_20128 * 4u)) + _20129) * 4 + 0));
                                        _20129++;
                                        continue;
                                    }
                                }
                                _20131 = true;
                                break;
                            } while(false);
                            if (_20131)
                            {
                                _20132 = _11227;
                                break;
                            }
                            _20132 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11138 = mul(float4((float2(_19776.x, 1.0f - _19776.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19776 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11197_dummy_parameter))))), 0)).x, 1.0f), _20132);
                        float _11140 = _11138.w;
                        if (abs(_11140) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20133 = 0.0f;
                            break;
                        }
                        float _11151 = abs(cbFI_DeviceToViewDepth.y / ((_11138.z / _11140) - cbFI_DeviceToViewDepth.x));
                        float _11154 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19777 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11213_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20133 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11151 - _11154) / max(max(_11151, _11154), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5939 = _20133 >= 0.5f;
                }
                else
                {
                    _5939 = _5909;
                }
                bool _5947;
                if (_5939)
                {
                    _5947 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5947 = _5939;
                }
                bool _20141;
                if (_5947)
                {
                    uint _11365_dummy_parameter;
                    float4x4 _20138;
                    do
                    {
                        float4x4 _11379;
                        bool _20137;
                        do
                        {
                            _11379 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20137 = false;
                                break;
                            }
                            uint _11413 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11413 + 32u) * 4 + 0) != 1u)
                            {
                                _20137 = false;
                                break;
                            }
                            uint _20134;
                            _20134 = 0u;
                            for (; _20134 < 4u; _20134++)
                            {
                                for (uint _20135 = 0u; _20135 < 4u; )
                                {
                                    _11379[_20134][_20135] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11413 + 16u) + (_20134 * 4u)) + _20135) * 4 + 0));
                                    _20135++;
                                    continue;
                                }
                            }
                            _20137 = true;
                            break;
                        } while(false);
                        if (_20137)
                        {
                            _20138 = _11379;
                            break;
                        }
                        _20138 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20139;
                    do
                    {
                        float _11493 = 1.0f - _19776.y;
                        float4 _11504 = mul(float4((float2(_19776.x, _11493) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19776 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11365_dummy_parameter))))), 0)).x, 1.0f), _20138);
                        float _11506 = _11504.w;
                        if (!(_11506 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20139 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11519 = ((_11504.xy / _11506.xx) + 1.0f.xx) * 0.5f;
                        _20139 = float2(_11519.x - _19776.x, _11493 - _11519.y);
                        break;
                    } while(false);
                    float2 _5960 = float2(cbFI_DisplaySize);
                    _20141 = length(((_19776 + _20139) - _19777) * _5960) <= ((0.100000001490116119384765625f * length(_20139 * _5960)) + 8.0f);
                }
                else
                {
                    _20141 = _5939;
                }
                _20140 = _20141;
            }
            else
            {
                _20140 = true;
            }
            bool _5974 = !_20140;
            bool _23661 = _5974 ? false : _5878;
            bool _23662 = _5974 ? false : _5865;
            bool _20218;
            float4 _20257;
            if (!(((_5839 && _5852) && _23662) && _23661))
            {
                float4 _5996 = _20196 * float4(_5904, _5906, float(_23662), float(_23661));
                float _5998 = dot(_5996, 1.0f.xxxx);
                bool _6001 = !(_5998 > 0.0f);
                float4 _20258;
                if (!_6001)
                {
                    _20258 = _5996 / _5998.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11541;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11541);
                    }
                    _20258 = 0.0f.xxxx;
                }
                _20257 = _20258;
                _20218 = _6001;
            }
            else
            {
                _20257 = _20196;
                _20218 = false;
            }
            _22010 = float3(_5904, _5906, _20125);
            _20256 = _20257;
            _20217 = _20218;
        }
        else
        {
            _22010 = float3(float(_10985), _5823, 0.0f);
            _20256 = _20196;
            _20217 = false;
        }
        bool _6019 = !_20217;
        float4 _20349;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6019)
        {
            float _6026 = _20256.x + _20256.y;
            float4 _20350;
            if (_6026 > 0.001000000047497451305389404296875f)
            {
                _20350 = float4(_20256.x / _6026, _20256.y / _6026, 0.0f, 0.0f);
            }
            else
            {
                _20350 = float4(_5588, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20349 = _20350;
        }
        else
        {
            _20349 = _20256;
        }
        float4 _20526;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6019) && _10985)
        {
            float _20323;
            do
            {
                uint4 _11681 = r_warped_motion_qdata_tp1.Load(int3(_19994, 0));
                uint _11682 = _11681.x;
                if (_11682 != 0u)
                {
                    float _20322;
                    if (_11682 == 0u)
                    {
                        _20322 = -1.0f;
                    }
                    else
                    {
                        _20322 = float((_11682 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20323 = _20322;
                    break;
                }
                int _20305;
                uint _20306;
                _20306 = _11682;
                _20305 = -1;
                uint _20321;
                for (; _20305 <= 1; _20306 = _20321, _20305++)
                {
                    _20321 = _20306;
                    for (int _20319 = -1; _20319 <= 1; )
                    {
                        _20321 = max(_20321, r_warped_motion_qdata_tp1.Load(int3(clamp(_19994 + int2(_20319, _20305), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20319++;
                        continue;
                    }
                }
                if (_20306 != 0u)
                {
                    float _20318;
                    if (_20306 == 0u)
                    {
                        _20318 = -1.0f;
                    }
                    else
                    {
                        _20318 = float((_20306 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20323 = _20318;
                    break;
                }
                uint _20308;
                _20308 = 4294967295u;
                uint _23294;
                for (int _20307 = 0; _20307 < 8; _20308 = _23294, _20307++)
                {
                    int _20311 = 0;
                    for (;;)
                    {
                        if (_20311 < 5)
                        {
                            int2 _11632 = _19994 + (_1247[_20307] * _1256[_20311].xx);
                            bool _11635 = any(bool2(_11632.x < int2(0, 0).x, _11632.y < int2(0, 0).y));
                            bool _11643;
                            if (!_11635)
                            {
                                _11643 = any(bool2(_11632.x >= cbFI_MvDepthLaneSize.x, _11632.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11643 = _11635;
                            }
                            if (_11643)
                            {
                                _23294 = _20308;
                                break;
                            }
                            uint4 _11721 = r_warped_motion_qdata_tp1.Load(int3(_11632, 0));
                            uint _11722 = _11721.x;
                            if (_11722 != 0u)
                            {
                                _23294 = min(_20308, _11722);
                                break;
                            }
                            _20311++;
                            continue;
                        }
                        else
                        {
                            _23294 = _20308;
                            break;
                        }
                    }
                }
                float _20310;
                if (_20308 == 4294967295u)
                {
                    _20310 = -1.0f;
                }
                else
                {
                    float _20309;
                    if (_20308 == 0u)
                    {
                        _20309 = -1.0f;
                    }
                    else
                    {
                        _20309 = float((_20308 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20310 = _20309;
                }
                _20323 = _20310;
                break;
            } while(false);
            float _6062 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6065 = r_warped_motion_qdata_tp1.Load(int3(_19994, 0)).x == 0u;
            bool _6071;
            if (_6065)
            {
                bool _11747 = all(bool2(_19773.x > 0.0f.xx.x, _19773.y > 0.0f.xx.y));
                bool _11753;
                if (_11747)
                {
                    _11753 = all(bool2(_19773.x < 1.0f.xx.x, _19773.y < 1.0f.xx.y));
                }
                else
                {
                    _11753 = _11747;
                }
                _6071 = _11753;
            }
            else
            {
                _6071 = _6065;
            }
            bool _6076;
            if (_6071)
            {
                bool _11758 = all(bool2(_19775.x > 0.0f.xx.x, _19775.y > 0.0f.xx.y));
                bool _11764;
                if (_11758)
                {
                    _11764 = all(bool2(_19775.x < 1.0f.xx.x, _19775.y < 1.0f.xx.y));
                }
                else
                {
                    _11764 = _11758;
                }
                _6076 = _11764;
            }
            else
            {
                _6076 = _6071;
            }
            bool _20335;
            float4 _20344;
            if (_6076)
            {
                uint _11771_dummy_parameter;
                float _11795 = log(((r_depth_tm1.Load(int3(int2(floor(_19773 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11771_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _11803_dummy_parameter;
                float _11827 = log(((r_depth_tp1.Load(int3(int2(floor(_19775 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11803_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _6087 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6094;
                if (_6087)
                {
                    _6094 = _11827 > (_11795 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6094 = _6087;
                }
                bool _20340;
                float4 _20362;
                if (_6094)
                {
                    _20362 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20340 = true;
                }
                else
                {
                    bool _6100 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6107;
                    if (_6100)
                    {
                        _6107 = _11795 > (_11827 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6107 = _6100;
                    }
                    bool4 _23663 = _6107.xxxx;
                    _20362 = float4(_23663.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20349.x, _23663.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20349.y, _23663.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20349.z, _23663.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20349.w);
                    _20340 = _6107 ? true : false;
                }
                _20344 = _20362;
                _20335 = _20340;
            }
            else
            {
                _20344 = _20349;
                _20335 = false;
            }
            float4 _20417;
            if (_20335)
            {
                _20417 = 1.0f.xxxx;
            }
            else
            {
                bool _6118 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6124;
                if (_6118)
                {
                    _6124 = _20344.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6124 = _6118;
                }
                bool _6129;
                if (_6124)
                {
                    bool _11833 = all(bool2(_19775.x > 0.0f.xx.x, _19775.y > 0.0f.xx.y));
                    bool _11839;
                    if (_11833)
                    {
                        _11839 = all(bool2(_19775.x < 1.0f.xx.x, _19775.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11839 = _11833;
                    }
                    _6129 = _11839;
                }
                else
                {
                    _6129 = _6124;
                }
                float4 _20418;
                if (_6129)
                {
                    float _20371;
                    if (_20323 >= 0.0f)
                    {
                        _20371 = _20323 - _6062;
                    }
                    else
                    {
                        float _20367;
                        _20367 = 2.0f;
                        float _11896;
                        for (int _20366 = 0; _20366 < 24; _20367 = _11896, _20366++)
                        {
                            float _11860 = float(_20366 & 7) * 0.785398185253143310546875f;
                            int _11862 = _20366 >> 3;
                            int _20368;
                            if (_11862 == 0)
                            {
                                _20368 = 16;
                            }
                            else
                            {
                                _20368 = (_11862 == 1) ? 48 : 96;
                            }
                            uint _11928_dummy_parameter;
                            _11896 = min(_20367, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19775 + ((cbFI_MvDepthLaneSizeRcp * float(_20368)) * float2(cos(_11860), sin(_11860))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11928_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20371 = _20367;
                    }
                    uint _11960_dummy_parameter;
                    float4 _20419;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_19775 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11960_dummy_parameter))))), 0)).x) > ((exp((_20371 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20419 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20419 = 1.0f.xxxx;
                    }
                    _20418 = _20419;
                }
                else
                {
                    _20418 = 1.0f.xxxx;
                }
                _20417 = _20418;
            }
            bool _6157 = _20323 >= 0.0f;
            bool _6158 = (!_20335) && _6157;
            bool _6165;
            if (_6158)
            {
                _6165 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6165 = _6158;
            }
            bool _6171;
            if (_6165)
            {
                _6171 = _20344.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6171 = _6165;
            }
            bool _6176;
            if (_6171)
            {
                bool _11985 = all(bool2(_19773.x > 0.0f.xx.x, _19773.y > 0.0f.xx.y));
                bool _11991;
                if (_11985)
                {
                    _11991 = all(bool2(_19773.x < 1.0f.xx.x, _19773.y < 1.0f.xx.y));
                }
                else
                {
                    _11991 = _11985;
                }
                _6176 = _11991;
            }
            else
            {
                _6176 = _6171;
            }
            float4 _20442;
            if (_6176)
            {
                float _20411;
                if (_6157)
                {
                    _20411 = _20323 - _6062;
                }
                else
                {
                    float _20407;
                    _20407 = 2.0f;
                    float _12048;
                    for (int _20406 = 0; _20406 < 24; _20407 = _12048, _20406++)
                    {
                        float _12012 = float(_20406 & 7) * 0.785398185253143310546875f;
                        int _12014 = _20406 >> 3;
                        int _20408;
                        if (_12014 == 0)
                        {
                            _20408 = 16;
                        }
                        else
                        {
                            _20408 = (_12014 == 1) ? 48 : 96;
                        }
                        uint _12064_dummy_parameter;
                        _12048 = min(_20407, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19773 + ((cbFI_MvDepthLaneSizeRcp * float(_20408)) * float2(cos(_12012), sin(_12012))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12064_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20411 = _20407;
                }
                uint _12112_dummy_parameter;
                float4 _20443;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_19773 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12112_dummy_parameter))))), 0)).x) > ((exp((_20411 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19469 = _20417;
                    _19469.x = 0.0f;
                    _20443 = _19469;
                }
                else
                {
                    _20443 = _20417;
                }
                _20442 = _20443;
            }
            else
            {
                _20442 = _20417;
            }
            float4 _20455;
            if (_6158)
            {
                float _12139 = (exp(((_20323 - _6062) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6214 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6220;
                if (_6214)
                {
                    _6220 = _20344.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6220 = _6214;
                }
                bool _6225;
                if (_6220)
                {
                    bool _12144 = all(bool2(_19777.x > 0.0f.xx.x, _19777.y > 0.0f.xx.y));
                    bool _12150;
                    if (_12144)
                    {
                        _12150 = all(bool2(_19777.x < 1.0f.xx.x, _19777.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12150 = _12144;
                    }
                    _6225 = _12150;
                }
                else
                {
                    _6225 = _6220;
                }
                bool _6233;
                if (_6225)
                {
                    uint _12157_dummy_parameter;
                    _6233 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19777 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12157_dummy_parameter))))), 0)).x) > _12139;
                }
                else
                {
                    _6233 = _6225;
                }
                float4 _20453;
                if (_6233)
                {
                    float4 _19472 = _20442;
                    _19472.w = 0.0f;
                    _20453 = _19472;
                }
                else
                {
                    _20453 = _20442;
                }
                bool _6240 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6246;
                if (_6240)
                {
                    _6246 = _20344.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6246 = _6240;
                }
                bool _6251;
                if (_6246)
                {
                    bool _12175 = all(bool2(_19776.x > 0.0f.xx.x, _19776.y > 0.0f.xx.y));
                    bool _12181;
                    if (_12175)
                    {
                        _12181 = all(bool2(_19776.x < 1.0f.xx.x, _19776.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12181 = _12175;
                    }
                    _6251 = _12181;
                }
                else
                {
                    _6251 = _6246;
                }
                bool _6259;
                if (_6251)
                {
                    uint _12188_dummy_parameter;
                    _6259 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19776 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12188_dummy_parameter))))), 0)).x) > _12139;
                }
                else
                {
                    _6259 = _6251;
                }
                float4 _20456;
                if (_6259)
                {
                    float4 _19475 = _20453;
                    _19475.z = 0.0f;
                    _20456 = _19475;
                }
                else
                {
                    _20456 = _20453;
                }
                _20455 = _20456;
            }
            else
            {
                _20455 = _20442;
            }
            float4 _20527;
            if (any(bool4(_20455.x < 1.0f.xxxx.x, _20455.y < 1.0f.xxxx.y, _20455.z < 1.0f.xxxx.z, _20455.w < 1.0f.xxxx.w)))
            {
                float4 _6270 = _20344 * _20455;
                float _6272 = dot(_6270, 1.0f.xxxx);
                float4 _20528;
                if (_6272 > 0.0f)
                {
                    _20528 = _6270 / _6272.xxxx;
                }
                else
                {
                    bool _6283 = _20455.y == 0.0f;
                    bool _6289;
                    if (_6283)
                    {
                        _6289 = _20455.x > 0.0f;
                    }
                    else
                    {
                        _6289 = _6283;
                    }
                    bool _6294;
                    if (_6289)
                    {
                        bool _12206 = all(bool2(_19773.x > 0.0f.xx.x, _19773.y > 0.0f.xx.y));
                        bool _12212;
                        if (_12206)
                        {
                            _12212 = all(bool2(_19773.x < 1.0f.xx.x, _19773.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12212 = _12206;
                        }
                        _6294 = _12212;
                    }
                    else
                    {
                        _6294 = _6289;
                    }
                    float4 _20529;
                    if (_6294)
                    {
                        _20529 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6299 = _20455.x == 0.0f;
                        bool _6305;
                        if (_6299)
                        {
                            _6305 = _20455.y > 0.0f;
                        }
                        else
                        {
                            _6305 = _6299;
                        }
                        bool _6310;
                        if (_6305)
                        {
                            bool _12217 = all(bool2(_19775.x > 0.0f.xx.x, _19775.y > 0.0f.xx.y));
                            bool _12223;
                            if (_12217)
                            {
                                _12223 = all(bool2(_19775.x < 1.0f.xx.x, _19775.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12223 = _12217;
                            }
                            _6310 = _12223;
                        }
                        else
                        {
                            _6310 = _6305;
                        }
                        bool4 _23666 = _6310.xxxx;
                        _20529 = float4(_23666.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20344.x, _23666.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20344.y, _23666.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20344.z, _23666.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20344.w);
                    }
                    _20528 = _20529;
                }
                _20527 = _20528;
            }
            else
            {
                _20527 = _20344;
            }
            _20526 = _20527;
        }
        else
        {
            _20526 = _20349;
        }
        float4 _21256;
        bool _21562;
        float3 _21751;
        if (((cbFI_pad0 & 32768u) != 0u) && _6019)
        {
            bool _6327 = _20526.x > 0.00999999977648258209228515625f;
            bool _6330 = _20526.y > 0.00999999977648258209228515625f;
            bool _6339 = (_20526.z + _20526.w) > 0.0199999995529651641845703125f;
            bool _6345;
            if (_6339)
            {
                bool _12228 = all(bool2(_19776.x > 0.0f.xx.x, _19776.y > 0.0f.xx.y));
                bool _12234;
                if (_12228)
                {
                    _12234 = all(bool2(_19776.x < 1.0f.xx.x, _19776.y < 1.0f.xx.y));
                }
                else
                {
                    _12234 = _12228;
                }
                _6345 = _12234;
            }
            else
            {
                _6345 = _6339;
            }
            bool _6350;
            if (_6345)
            {
                bool _12239 = all(bool2(_19777.x > 0.0f.xx.x, _19777.y > 0.0f.xx.y));
                bool _12245;
                if (_12239)
                {
                    _12245 = all(bool2(_19777.x < 1.0f.xx.x, _19777.y < 1.0f.xx.y));
                }
                else
                {
                    _12245 = _12239;
                }
                _6350 = _12245;
            }
            else
            {
                _6350 = _6345;
            }
            bool _6357;
            if (_6350)
            {
                float _20542;
                do
                {
                    bool _12328 = all(bool2(_19776.x > 0.0f.xx.x, _19776.y > 0.0f.xx.y));
                    bool _12334;
                    if (_12328)
                    {
                        _12334 = all(bool2(_19776.x < 1.0f.xx.x, _19776.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12334 = _12328;
                    }
                    bool _12265 = !_12334;
                    bool _12272;
                    if (!_12265)
                    {
                        bool _12339 = all(bool2(_19777.x > 0.0f.xx.x, _19777.y > 0.0f.xx.y));
                        bool _12345;
                        if (_12339)
                        {
                            _12345 = all(bool2(_19777.x < 1.0f.xx.x, _19777.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12345 = _12339;
                        }
                        _12272 = !_12345;
                    }
                    else
                    {
                        _12272 = _12265;
                    }
                    if (_12272)
                    {
                        _20542 = 0.0f;
                        break;
                    }
                    uint _12352_dummy_parameter;
                    uint _12368_dummy_parameter;
                    float4x4 _20541;
                    do
                    {
                        float4x4 _12382;
                        bool _20540;
                        do
                        {
                            _12382 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20540 = false;
                                break;
                            }
                            uint _12416 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12416 + 32u) * 4 + 0) != 1u)
                            {
                                _20540 = false;
                                break;
                            }
                            uint _20537;
                            _20537 = 0u;
                            for (; _20537 < 4u; _20537++)
                            {
                                for (uint _20538 = 0u; _20538 < 4u; )
                                {
                                    _12382[_20537][_20538] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12416 + 16u) + (_20537 * 4u)) + _20538) * 4 + 0));
                                    _20538++;
                                    continue;
                                }
                            }
                            _20540 = true;
                            break;
                        } while(false);
                        if (_20540)
                        {
                            _20541 = _12382;
                            break;
                        }
                        _20541 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12293 = mul(float4((float2(_19776.x, 1.0f - _19776.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19776 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12352_dummy_parameter))))), 0)).x, 1.0f), _20541);
                    float _12295 = _12293.w;
                    if (abs(_12295) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20542 = 0.0f;
                        break;
                    }
                    float _12306 = abs(cbFI_DeviceToViewDepth.y / ((_12293.z / _12295) - cbFI_DeviceToViewDepth.x));
                    float _12309 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19777 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12368_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20542 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12306 - _12309) / max(max(_12306, _12309), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6357 = _20542 < 0.5f;
            }
            else
            {
                _6357 = _6350;
            }
            float4 _20561;
            if (_6357)
            {
                uint _12520_dummy_parameter;
                uint _12551_dummy_parameter;
                float4 _20562;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19776 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12520_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19777 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12551_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20562 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20562 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20561 = _20562;
            }
            else
            {
                _20561 = 1.0f.xxxx;
            }
            bool _6381;
            if (_10985)
            {
                bool _12580 = all(bool2(_19773.x > 0.0f.xx.x, _19773.y > 0.0f.xx.y));
                bool _12586;
                if (_12580)
                {
                    _12586 = all(bool2(_19773.x < 1.0f.xx.x, _19773.y < 1.0f.xx.y));
                }
                else
                {
                    _12586 = _12580;
                }
                _6381 = _12586;
            }
            else
            {
                _6381 = _10985;
            }
            bool _6387;
            if (_10985)
            {
                bool _12591 = all(bool2(_19775.x > 0.0f.xx.x, _19775.y > 0.0f.xx.y));
                bool _12597;
                if (_12591)
                {
                    _12597 = all(bool2(_19775.x < 1.0f.xx.x, _19775.y < 1.0f.xx.y));
                }
                else
                {
                    _12597 = _12591;
                }
                _6387 = _12597;
            }
            else
            {
                _6387 = _10985;
            }
            bool _6393;
            if (_11017)
            {
                bool _12602 = all(bool2(_19776.x > 0.0f.xx.x, _19776.y > 0.0f.xx.y));
                bool _12608;
                if (_12602)
                {
                    _12608 = all(bool2(_19776.x < 1.0f.xx.x, _19776.y < 1.0f.xx.y));
                }
                else
                {
                    _12608 = _12602;
                }
                _6393 = _12608;
            }
            else
            {
                _6393 = _11017;
            }
            bool _6399;
            if (_11017)
            {
                bool _12613 = all(bool2(_19777.x > 0.0f.xx.x, _19777.y > 0.0f.xx.y));
                bool _12619;
                if (_12613)
                {
                    _12619 = all(bool2(_19777.x < 1.0f.xx.x, _19777.y < 1.0f.xx.y));
                }
                else
                {
                    _12619 = _12613;
                }
                _6399 = _12619;
            }
            else
            {
                _6399 = _11017;
            }
            bool _6402 = _6393 != _6399;
            bool _6408;
            if (_6402)
            {
                _6408 = _6381 || _6387;
            }
            else
            {
                _6408 = _6402;
            }
            float4 _20664;
            if (_6408)
            {
                float4 _19502 = _20561;
                _19502.z = 0.0f;
                _19502.w = 0.0f;
                _20664 = _19502;
            }
            else
            {
                _20664 = _20561;
            }
            bool _6415 = _6381 && _6327;
            bool _6418 = _6387 && _6330;
            float4 _20769;
            float3 _21860;
            if (_6415 || _6418)
            {
                float _20659;
                do
                {
                    uint4 _12758 = r_warped_motion_qdata_tp1.Load(int3(_19994, 0));
                    uint _12759 = _12758.x;
                    if (_12759 != 0u)
                    {
                        float _20658;
                        if (_12759 == 0u)
                        {
                            _20658 = -1.0f;
                        }
                        else
                        {
                            _20658 = float((_12759 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20659 = _20658;
                        break;
                    }
                    int _20641;
                    uint _20642;
                    _20642 = _12759;
                    _20641 = -1;
                    uint _20657;
                    for (; _20641 <= 1; _20642 = _20657, _20641++)
                    {
                        _20657 = _20642;
                        for (int _20655 = -1; _20655 <= 1; )
                        {
                            _20657 = max(_20657, r_warped_motion_qdata_tp1.Load(int3(clamp(_19994 + int2(_20655, _20641), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20655++;
                            continue;
                        }
                    }
                    if (_20642 != 0u)
                    {
                        float _20654;
                        if (_20642 == 0u)
                        {
                            _20654 = -1.0f;
                        }
                        else
                        {
                            _20654 = float((_20642 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20659 = _20654;
                        break;
                    }
                    uint _20644;
                    _20644 = 4294967295u;
                    uint _23295;
                    for (int _20643 = 0; _20643 < 8; _20644 = _23295, _20643++)
                    {
                        int _20647 = 0;
                        for (;;)
                        {
                            if (_20647 < 5)
                            {
                                int2 _12709 = _19994 + (_1247[_20643] * _1256[_20647].xx);
                                bool _12712 = any(bool2(_12709.x < int2(0, 0).x, _12709.y < int2(0, 0).y));
                                bool _12720;
                                if (!_12712)
                                {
                                    _12720 = any(bool2(_12709.x >= cbFI_MvDepthLaneSize.x, _12709.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12720 = _12712;
                                }
                                if (_12720)
                                {
                                    _23295 = _20644;
                                    break;
                                }
                                uint4 _12798 = r_warped_motion_qdata_tp1.Load(int3(_12709, 0));
                                uint _12799 = _12798.x;
                                if (_12799 != 0u)
                                {
                                    _23295 = min(_20644, _12799);
                                    break;
                                }
                                _20647++;
                                continue;
                            }
                            else
                            {
                                _23295 = _20644;
                                break;
                            }
                        }
                    }
                    float _20646;
                    if (_20644 == 4294967295u)
                    {
                        _20646 = -1.0f;
                    }
                    else
                    {
                        float _20645;
                        if (_20644 == 0u)
                        {
                            _20645 = -1.0f;
                        }
                        else
                        {
                            _20645 = float((_20644 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20646 = _20645;
                    }
                    _20659 = _20646;
                    break;
                } while(false);
                bool _6426 = _20659 < 0.0f;
                float _20660;
                if (_6426)
                {
                    _20660 = 0.0f;
                }
                else
                {
                    _20660 = _20659 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12820_dummy_parameter;
                uint _12852_dummy_parameter;
                float4 _20697;
                if ((_6426 && _6415) && _6418)
                {
                    uint _12884_dummy_parameter;
                    float _12908 = log(((r_depth_tm1.Load(int3(int2(floor(_19773 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12884_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12916_dummy_parameter;
                    float _12940 = log(((r_depth_tp1.Load(int3(int2(floor(_19775 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12916_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20698;
                    if (_12908 > (_12940 + 0.07999999821186065673828125f))
                    {
                        float4 _19506 = _20664;
                        _19506.x = 0.0f;
                        _20698 = _19506;
                    }
                    else
                    {
                        float4 _20699;
                        if (_12940 > (_12908 + 0.07999999821186065673828125f))
                        {
                            float4 _19508 = _20664;
                            _19508.y = 0.0f;
                            _20699 = _19508;
                        }
                        else
                        {
                            _20699 = _20664;
                        }
                        _20698 = _20699;
                    }
                    _20697 = _20698;
                }
                else
                {
                    _20697 = _20664;
                }
                float _6478 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6480 = _20659 >= 0.0f;
                float _20680;
                if (_6480)
                {
                    _20680 = _20659 - _6478;
                }
                else
                {
                    float _20676;
                    if (_6415)
                    {
                        float _20675;
                        _20675 = 2.0f;
                        float _12998;
                        for (int _20674 = 0; _20674 < 24; _20675 = _12998, _20674++)
                        {
                            float _12962 = float(_20674 & 7) * 0.785398185253143310546875f;
                            int _12964 = _20674 >> 3;
                            int _20677;
                            if (_12964 == 0)
                            {
                                _20677 = 16;
                            }
                            else
                            {
                                _20677 = (_12964 == 1) ? 48 : 96;
                            }
                            uint _13014_dummy_parameter;
                            _12998 = min(_20675, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19773 + ((cbFI_MvDepthLaneSizeRcp * float(_20677)) * float2(cos(_12962), sin(_12962))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13014_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20676 = _20675;
                    }
                    else
                    {
                        _20676 = 0.0f;
                    }
                    _20680 = _20676;
                }
                float _20687;
                if (_6480)
                {
                    _20687 = _20659 - _6478;
                }
                else
                {
                    float _20683;
                    if (_6418)
                    {
                        float _20682;
                        _20682 = 2.0f;
                        float _13112;
                        for (int _20681 = 0; _20681 < 24; _20682 = _13112, _20681++)
                        {
                            float _13076 = float(_20681 & 7) * 0.785398185253143310546875f;
                            int _13078 = _20681 >> 3;
                            int _20684;
                            if (_13078 == 0)
                            {
                                _20684 = 16;
                            }
                            else
                            {
                                _20684 = (_13078 == 1) ? 48 : 96;
                            }
                            uint _13144_dummy_parameter;
                            _13112 = min(_20682, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19775 + ((cbFI_MvDepthLaneSizeRcp * float(_20684)) * float2(cos(_13076), sin(_13076))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13144_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20683 = _20682;
                    }
                    else
                    {
                        _20683 = 0.0f;
                    }
                    _20687 = _20683;
                }
                float _20688;
                if (_6415)
                {
                    uint _13176_dummy_parameter;
                    _20688 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_19773 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13176_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20688 = 0.0f;
                }
                float _20689;
                if (_6418)
                {
                    uint _13196_dummy_parameter;
                    _20689 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_19775 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13196_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20689 = 0.0f;
                }
                bool _6535;
                if (_6415)
                {
                    _6535 = _20688 > ((exp((_20680 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6535 = _6415;
                }
                float4 _20705;
                if (_6535)
                {
                    float4 _19510 = _20697;
                    _19510.x = 0.0f;
                    _20705 = _19510;
                }
                else
                {
                    _20705 = _20697;
                }
                bool _6547;
                if (_6418)
                {
                    _6547 = _20689 > ((exp((_20687 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6547 = _6418;
                }
                float4 _20707;
                if (_6547)
                {
                    float4 _19512 = _20705;
                    _19512.y = 0.0f;
                    _20707 = _19512;
                }
                else
                {
                    _20707 = _20705;
                }
                float4 _20770;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6480)
                {
                    bool _6567;
                    if (_6415)
                    {
                        _6567 = _20688 < ((exp((_20680 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6567 = _6415;
                    }
                    float4 _20709;
                    if (_6567)
                    {
                        float4 _19514 = _20707;
                        _19514.x = 0.0f;
                        _20709 = _19514;
                    }
                    else
                    {
                        _20709 = _20707;
                    }
                    bool _6579;
                    if (_6418)
                    {
                        _6579 = _20689 < ((exp((_20687 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6579 = _6418;
                    }
                    float4 _20771;
                    if (_6579)
                    {
                        float4 _19516 = _20709;
                        _19516.y = 0.0f;
                        _20771 = _19516;
                    }
                    else
                    {
                        _20771 = _20709;
                    }
                    _20770 = _20771;
                }
                else
                {
                    _20770 = _20707;
                }
                _21860 = float3(_20660, log(((r_depth_tm1.Load(int3(int2(floor(_19773 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12820_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_19775 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12852_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _20769 = _20770;
            }
            else
            {
                _21860 = float3(0.0f, 0.0f, 0.5f);
                _20769 = _20664;
            }
            bool _6590 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6339;
            bool _6596;
            if (_6590)
            {
                _6596 = _6393 || _6399;
            }
            else
            {
                _6596 = _6590;
            }
            float4 _20812;
            if (_6596)
            {
                float _20764;
                do
                {
                    uint4 _13376 = r_warped_motion_qdata_tp1.Load(int3(_19994, 0));
                    uint _13377 = _13376.x;
                    if (_13377 != 0u)
                    {
                        float _20763;
                        if (_13377 == 0u)
                        {
                            _20763 = -1.0f;
                        }
                        else
                        {
                            _20763 = float((_13377 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20764 = _20763;
                        break;
                    }
                    int _20746;
                    uint _20747;
                    _20747 = _13377;
                    _20746 = -1;
                    uint _20762;
                    for (; _20746 <= 1; _20747 = _20762, _20746++)
                    {
                        _20762 = _20747;
                        for (int _20760 = -1; _20760 <= 1; )
                        {
                            _20762 = max(_20762, r_warped_motion_qdata_tp1.Load(int3(clamp(_19994 + int2(_20760, _20746), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20760++;
                            continue;
                        }
                    }
                    if (_20747 != 0u)
                    {
                        float _20759;
                        if (_20747 == 0u)
                        {
                            _20759 = -1.0f;
                        }
                        else
                        {
                            _20759 = float((_20747 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20764 = _20759;
                        break;
                    }
                    uint _20749;
                    _20749 = 4294967295u;
                    uint _23296;
                    for (int _20748 = 0; _20748 < 8; _20749 = _23296, _20748++)
                    {
                        int _20752 = 0;
                        for (;;)
                        {
                            if (_20752 < 5)
                            {
                                int2 _13327 = _19994 + (_1247[_20748] * _1256[_20752].xx);
                                bool _13330 = any(bool2(_13327.x < int2(0, 0).x, _13327.y < int2(0, 0).y));
                                bool _13338;
                                if (!_13330)
                                {
                                    _13338 = any(bool2(_13327.x >= cbFI_MvDepthLaneSize.x, _13327.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13338 = _13330;
                                }
                                if (_13338)
                                {
                                    _23296 = _20749;
                                    break;
                                }
                                uint4 _13416 = r_warped_motion_qdata_tp1.Load(int3(_13327, 0));
                                uint _13417 = _13416.x;
                                if (_13417 != 0u)
                                {
                                    _23296 = min(_20749, _13417);
                                    break;
                                }
                                _20752++;
                                continue;
                            }
                            else
                            {
                                _23296 = _20749;
                                break;
                            }
                        }
                    }
                    float _20751;
                    if (_20749 == 4294967295u)
                    {
                        _20751 = -1.0f;
                    }
                    else
                    {
                        float _20750;
                        if (_20749 == 0u)
                        {
                            _20750 = -1.0f;
                        }
                        else
                        {
                            _20750 = float((_20749 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20751 = _20750;
                    }
                    _20764 = _20751;
                    break;
                } while(false);
                float4 _20813;
                if (_20764 >= 0.0f)
                {
                    float _13438 = (exp((_20764 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6615;
                    if (_6393)
                    {
                        uint _13445_dummy_parameter;
                        _6615 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19776 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13445_dummy_parameter))))), 0)).x) > _13438;
                    }
                    else
                    {
                        _6615 = _6393;
                    }
                    float4 _20782;
                    if (_6615)
                    {
                        float4 _19518 = _20769;
                        _19518.z = 0.0f;
                        _20782 = _19518;
                    }
                    else
                    {
                        _20782 = _20769;
                    }
                    bool _6627;
                    if (_6399)
                    {
                        uint _13465_dummy_parameter;
                        _6627 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19777 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13465_dummy_parameter))))), 0)).x) > _13438;
                    }
                    else
                    {
                        _6627 = _6399;
                    }
                    float4 _20814;
                    if (_6627)
                    {
                        float4 _19520 = _20782;
                        _19520.w = 0.0f;
                        _20814 = _19520;
                    }
                    else
                    {
                        _20814 = _20782;
                    }
                    _20813 = _20814;
                }
                else
                {
                    _20813 = _20769;
                }
                _20812 = _20813;
            }
            else
            {
                _20812 = _20769;
            }
            bool _6635 = _6381 != _6387;
            bool _6642;
            if (_6635)
            {
                _6642 = _6381 ? _6327 : _6330;
            }
            else
            {
                _6642 = _6635;
            }
            bool _6649;
            if (_6642)
            {
                _6649 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6649 = _6642;
            }
            float4 _20915;
            if (_6649)
            {
                bool2 _6654 = _6381.xx;
                float2 _6655 = float2(_6654.x ? _19773.x : _19775.x, _6654.y ? _19773.y : _19775.y);
                float _20796;
                if (_6381)
                {
                    uint _13485_dummy_parameter;
                    _20796 = r_depth_tm1.Load(int3(int2(floor(_6655 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13485_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13501_dummy_parameter;
                    _20796 = r_depth_tp1.Load(int3(int2(floor(_6655 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13501_dummy_parameter))))), 0)).x;
                }
                float4x4 _20803;
                if (_6381)
                {
                    float4x4 _20792;
                    do
                    {
                        float4x4 _13515;
                        bool _20791;
                        do
                        {
                            _13515 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20791 = false;
                                break;
                            }
                            uint _13549 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13549 + 32u) * 4 + 0) != 1u)
                            {
                                _20791 = false;
                                break;
                            }
                            uint _20788;
                            _20788 = 0u;
                            for (; _20788 < 4u; _20788++)
                            {
                                for (uint _20789 = 0u; _20789 < 4u; )
                                {
                                    _13515[_20788][_20789] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13549 + 16u) + (_20788 * 4u)) + _20789) * 4 + 0));
                                    _20789++;
                                    continue;
                                }
                            }
                            _20791 = true;
                            break;
                        } while(false);
                        if (_20791)
                        {
                            _20792 = _13515;
                            break;
                        }
                        _20792 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20803 = _20792;
                }
                else
                {
                    float4x4 _20787;
                    do
                    {
                        float4x4 _13621;
                        bool _20786;
                        do
                        {
                            _13621 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20786 = false;
                                break;
                            }
                            uint _13655 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13655 + 32u) * 4 + 0) != 1u)
                            {
                                _20786 = false;
                                break;
                            }
                            uint _20783;
                            _20783 = 0u;
                            for (; _20783 < 4u; _20783++)
                            {
                                for (uint _20784 = 0u; _20784 < 4u; )
                                {
                                    _13621[_20783][_20784] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13655 + (_20783 * 4u)) + _20784) * 4 + 0));
                                    _20784++;
                                    continue;
                                }
                            }
                            _20786 = true;
                            break;
                        } while(false);
                        if (_20786)
                        {
                            _20787 = _13621;
                            break;
                        }
                        _20787 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20803 = _20787;
                }
                float2 _20804;
                do
                {
                    float _13732 = _6655.x;
                    float _13735 = 1.0f - _6655.y;
                    float4 _13746 = mul(float4((float2(_13732, _13735) * 2.0f) - 1.0f.xx, _20796, 1.0f), _20803);
                    float _13748 = _13746.w;
                    if (!(_13748 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20804 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13761 = ((_13746.xy / _13748.xx) + 1.0f.xx) * 0.5f;
                    _20804 = float2(_13761.x - _13732, _13735 - _13761.y);
                    break;
                } while(false);
                float2 _6685 = float2(cbFI_DisplaySize);
                float4 _20916;
                if (!(length(((_6655 + _20804) - float2(_6654.x ? _19775.x : _19773.x, _6654.y ? _19775.y : _19773.y)) * _6685) <= ((0.100000001490116119384765625f * length(_20804 * _6685)) + 8.0f)))
                {
                    float4 _20917;
                    if (_6381)
                    {
                        float4 _19530 = _20812;
                        _19530.x = 0.0f;
                        _20917 = _19530;
                    }
                    else
                    {
                        float4 _19532 = _20812;
                        _19532.y = 0.0f;
                        _20917 = _19532;
                    }
                    _20916 = _20917;
                }
                else
                {
                    _20916 = _20812;
                }
                _20915 = _20916;
            }
            else
            {
                _20915 = _20812;
            }
            float4 _6710 = _20526 * _20915;
            float _6712 = dot(_6710, 1.0f.xxxx);
            float4 _21257;
            bool _21563;
            if (_6712 > 0.0f)
            {
                _21563 = _20217;
                _21257 = _6710 / _6712.xxxx;
            }
            else
            {
                bool _6723 = any(bool4(_20915.x < 1.0f.xxxx.x, _20915.y < 1.0f.xxxx.y, _20915.z < 1.0f.xxxx.z, _20915.w < 1.0f.xxxx.w));
                if (_6723)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13783;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13783);
                    }
                }
                bool4 _23669 = _6723.xxxx;
                _21563 = _6723 ? true : _20217;
                _21257 = float4(_23669.x ? 0.0f.xxxx.x : _20526.x, _23669.y ? 0.0f.xxxx.y : _20526.y, _23669.z ? 0.0f.xxxx.z : _20526.z, _23669.w ? 0.0f.xxxx.w : _20526.w);
            }
            _21751 = _21860;
            _21562 = _21563;
            _21256 = _21257;
        }
        else
        {
            _21751 = float3(0.0f, 0.0f, 0.5f);
            _21562 = _20217;
            _21256 = _20526;
        }
        uint _6732 = (cbFI_pad0 >> 24u) & 31u;
        uint _6736 = (cbFI_pad0 >> 16u) & 255u;
        bool _6738 = _6732 != 0u;
        bool _6740 = _6736 == 12u;
        bool _6743 = _6736 == 13u;
        float4 _21277;
        if ((_6738 || _6740) || _6743)
        {
            float _20923;
            do
            {
                bool _13867 = all(bool2(_19776.x > 0.0f.xx.x, _19776.y > 0.0f.xx.y));
                bool _13873;
                if (_13867)
                {
                    _13873 = all(bool2(_19776.x < 1.0f.xx.x, _19776.y < 1.0f.xx.y));
                }
                else
                {
                    _13873 = _13867;
                }
                bool _13804 = !_13873;
                bool _13811;
                if (!_13804)
                {
                    bool _13878 = all(bool2(_19777.x > 0.0f.xx.x, _19777.y > 0.0f.xx.y));
                    bool _13884;
                    if (_13878)
                    {
                        _13884 = all(bool2(_19777.x < 1.0f.xx.x, _19777.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13884 = _13878;
                    }
                    _13811 = !_13884;
                }
                else
                {
                    _13811 = _13804;
                }
                if (_13811)
                {
                    _20923 = 0.0f;
                    break;
                }
                uint _13891_dummy_parameter;
                uint _13907_dummy_parameter;
                float4x4 _20922;
                do
                {
                    float4x4 _13921;
                    bool _20921;
                    do
                    {
                        _13921 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20921 = false;
                            break;
                        }
                        uint _13955 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13955 + 32u) * 4 + 0) != 1u)
                        {
                            _20921 = false;
                            break;
                        }
                        uint _20918;
                        _20918 = 0u;
                        for (; _20918 < 4u; _20918++)
                        {
                            for (uint _20919 = 0u; _20919 < 4u; )
                            {
                                _13921[_20918][_20919] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13955 + 16u) + (_20918 * 4u)) + _20919) * 4 + 0));
                                _20919++;
                                continue;
                            }
                        }
                        _20921 = true;
                        break;
                    } while(false);
                    if (_20921)
                    {
                        _20922 = _13921;
                        break;
                    }
                    _20922 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13832 = mul(float4((float2(_19776.x, 1.0f - _19776.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19776 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13891_dummy_parameter))))), 0)).x, 1.0f), _20922);
                float _13834 = _13832.w;
                if (abs(_13834) < 9.9999999747524270787835121154785e-07f)
                {
                    _20923 = 0.0f;
                    break;
                }
                float _13845 = abs(cbFI_DeviceToViewDepth.y / ((_13832.z / _13834) - cbFI_DeviceToViewDepth.x));
                float _13848 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19777 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13907_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20923 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13845 - _13848) / max(max(_13845, _13848), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14057 = all(bool2(_19777.x > 0.0f.xx.x, _19777.y > 0.0f.xx.y));
            bool _14063;
            if (_14057)
            {
                _14063 = all(bool2(_19777.x < 1.0f.xx.x, _19777.y < 1.0f.xx.y));
            }
            else
            {
                _14063 = _14057;
            }
            float _20924;
            if (_14063)
            {
                uint _14070_dummy_parameter;
                _20924 = length((_7883 + (r_motion_tp1.Load(int3(int2(floor(_19777 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14070_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20924 = 1000000.0f;
            }
            float _20939;
            if ((_6732 & 1u) != 0u)
            {
                _20939 = _20923;
            }
            else
            {
                _20939 = 1.0f;
            }
            float _20940;
            if ((_6732 & 2u) != 0u)
            {
                _20940 = _20939 * (1.0f - smoothstep(2.0f, 8.0f, _20924));
            }
            else
            {
                _20940 = _20939;
            }
            float _20941;
            if ((_6732 & 4u) != 0u)
            {
                _20941 = _20940 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8604 - _8612) - length(_8588 - _8596))));
            }
            else
            {
                _20941 = _20940;
            }
            float _21271;
            if ((_6732 & 8u) != 0u)
            {
                _21271 = lerp(1.0f, _20941, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8588 - _8596)));
            }
            else
            {
                _21271 = _20941;
            }
            bool _6818 = (_6732 & 16u) != 0u;
            bool _6827;
            if (_6818)
            {
                _6827 = length(_19771 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6827 = _6818;
            }
            float _23671 = _6827 ? 1.0f : _21271;
            bool _6833 = _6738 && _10985;
            bool _6838;
            if (_6833)
            {
                bool _14095 = all(bool2(_19773.x > 0.0f.xx.x, _19773.y > 0.0f.xx.y));
                bool _14101;
                if (_14095)
                {
                    _14101 = all(bool2(_19773.x < 1.0f.xx.x, _19773.y < 1.0f.xx.y));
                }
                else
                {
                    _14101 = _14095;
                }
                _6838 = _14101;
            }
            else
            {
                _6838 = _6833;
            }
            bool _6843;
            if (_6838)
            {
                bool _14106 = all(bool2(_19775.x > 0.0f.xx.x, _19775.y > 0.0f.xx.y));
                bool _14112;
                if (_14106)
                {
                    _14112 = all(bool2(_19775.x < 1.0f.xx.x, _19775.y < 1.0f.xx.y));
                }
                else
                {
                    _14112 = _14106;
                }
                _6843 = _14112;
            }
            else
            {
                _6843 = _6838;
            }
            float4 _21278;
            if (_6843)
            {
                float _6849 = _21256.x + _21256.y;
                float _6858 = (_21256.z + _21256.w) * (1.0f - _23671);
                float _21274;
                if (_6849 > 9.9999997473787516355514526367188e-06f)
                {
                    _21274 = _21256.x / _6849;
                }
                else
                {
                    _21274 = _5588;
                }
                _21278 = float4(_21256.x + (_6858 * _21274), _21256.y + (_6858 * (1.0f - _21274)), _21256.zw * _23671);
            }
            else
            {
                _21278 = _21256;
            }
            _21277 = _21278;
        }
        else
        {
            _21277 = _21256;
        }
        float3 _6919 = (((_8588 * _21277.x) + (_8596 * _21277.y)) + (_8604 * _21277.z)) + (_8612 * _21277.w);
        float3 _22870;
        if (_5604 && (_21292 > 0.0f))
        {
            uint _14119_dummy_parameter;
            float2 _14134 = r_motion_tp1.Load(int3(int2(floor(_5363 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14119_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21554;
            if (_7911)
            {
                float2 _14179 = clamp((((_19750 + (_14134 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14182 = tan(_14179.x);
                _21554 = (float2(_14182 / cbFI_DeviceToViewDepth.z, (tan(_14179.y) * sqrt(1.0f + (_14182 * _14182))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21554 = _19750 + (_14134 * cbFI_Timestep);
            }
            float2 _21555;
            if (_7911)
            {
                float2 _14258 = clamp((((_19750 + (_14134 * _5578)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14261 = tan(_14258.x);
                _21555 = (float2(_14261 / cbFI_DeviceToViewDepth.z, (tan(_14258.y) * sqrt(1.0f + (_14261 * _14261))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21555 = _19750 + (_14134 * _5578);
            }
            _22870 = lerp(_6919, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21554, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21555, 0.0f).xyz, cbFI_Timestep.xxx), _21292.xxx);
        }
        else
        {
            _22870 = _6919;
        }
        float3 _22869;
        if (_21562)
        {
            float3 _14303 = r_current_interpolation_source.Load(int3(_4857, 0)).xyz;
            float3 _22871;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _10985)
            {
                uint _14310_dummy_parameter;
                float _21685;
                _21685 = r_depth_tm1.Load(int3(int2(floor(_19773 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14310_dummy_parameter))))), 0)).x;
                float _7000;
                for (int _21684 = 0; _21684 < 24; _21685 = _7000, _21684++)
                {
                    float _6972 = float(_21684 & 7) * 0.785398185253143310546875f;
                    int _6974 = _21684 >> 3;
                    int _23138;
                    if (_6974 == 0)
                    {
                        _23138 = 16;
                    }
                    else
                    {
                        _23138 = (_6974 == 1) ? 48 : 96;
                    }
                    uint _14330_dummy_parameter;
                    _7000 = max(_21685, r_depth_tm1.Load(int3(int2(floor(clamp(_19773 + ((cbFI_MvDepthLaneSizeRcp * float(_23138)) * float2(cos(_6972), sin(_6972))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14330_dummy_parameter))))), 0)).x);
                }
                float2 _21686;
                do
                {
                    float _14352 = 1.0f - _19773.y;
                    float4 _14363 = mul(float4((float2(_19773.x, _14352) * 2.0f) - 1.0f.xx, _21685, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14365 = _14363.w;
                    if (!(_14365 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21686 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14378 = ((_14363.xy / _14365.xx) + 1.0f.xx) * 0.5f;
                    _21686 = float2(_14378.x - _19773.x, _14352 - _14378.y);
                    break;
                } while(false);
                float2 _7011 = _19773 + _21686;
                bool _14396 = all(bool2(_7011.x > 0.0f.xx.x, _7011.y > 0.0f.xx.y));
                bool _14402;
                if (_14396)
                {
                    _14402 = all(bool2(_7011.x < 1.0f.xx.x, _7011.y < 1.0f.xx.y));
                }
                else
                {
                    _14402 = _14396;
                }
                float3 _22872;
                if (_14402)
                {
                    float _7017 = abs(cbFI_DeviceToViewDepth.y / (_21685 - cbFI_DeviceToViewDepth.x));
                    uint _14422_dummy_parameter;
                    int2 _14422 = int2(spvTextureSize(r_depth_m2, uint(0), _14422_dummy_parameter));
                    float _7021 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7011 * float2(_14422))), int2(0, 0), _14422 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22877;
                    if (abs(_7021 - _7017) <= (0.20000000298023223876953125f * max(_7021, _7017)))
                    {
                        uint _14456_dummy_parameter;
                        int2 _14456 = int2(spvTextureSize(r_colour_m2, uint(0), _14456_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14479;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14479);
                        }
                        _22877 = r_colour_m2.Load(int3(clamp(int2(floor(_7011 * float2(_14456))), int2(0, 0), _14456 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14489;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14489);
                        }
                        _22877 = _14303;
                    }
                    _22872 = _22877;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14499;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14499);
                    }
                    _22872 = _14303;
                }
                _22871 = _22872;
            }
            else
            {
                _22871 = _14303;
            }
            _22869 = _22871;
        }
        else
        {
            _22869 = _22870;
        }
        bool _7046 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22868;
        float _22944;
        if (_7046)
        {
            bool _14714;
            float2 _7050 = float2(cbFI_DisplaySize);
            float4x4 _21693;
            do
            {
                float4x4 _14690;
                bool _21692;
                do
                {
                    _14690 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                    _14714 = (cbFI_NfruT2Flags & 524288u) == 0u;
                    if (_14714)
                    {
                        _21692 = false;
                        break;
                    }
                    uint _14724 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                    if (rw_nfru_diagnostics.Load<uint>((_14724 + 32u) * 4 + 0) != 1u)
                    {
                        _21692 = false;
                        break;
                    }
                    uint _21689;
                    _21689 = 0u;
                    for (; _21689 < 4u; _21689++)
                    {
                        for (uint _21690 = 0u; _21690 < 4u; )
                        {
                            _14690[_21689][_21690] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14724 + (_21689 * 4u)) + _21690) * 4 + 0));
                            _21690++;
                            continue;
                        }
                    }
                    _21692 = true;
                    break;
                } while(false);
                if (_21692)
                {
                    _21693 = _14690;
                    break;
                }
                _21693 = cbFI_MotionTP1ToTM1;
                break;
            } while(false);
            float _14801;
            float _14804;
            float4 _14814;
            float2 _21694;
            do
            {
                _14801 = _5363.x;
                _14804 = 1.0f - _5363.y;
                _14814 = float4((float2(_14801, _14804) * 2.0f) - 1.0f.xx, 0.99999988079071044921875f, 1.0f);
                float4 _14815 = mul(_14814, _21693);
                float _14817 = _14815.w;
                if (!(_14817 > 9.9999999747524270787835121154785e-07f))
                {
                    _21694 = 1000000.0f.xx;
                    break;
                }
                float2 _14830 = ((_14815.xy / _14817.xx) + 1.0f.xx) * 0.5f;
                _21694 = float2(_14830.x - _14801, _14804 - _14830.y);
                break;
            } while(false);
            float4x4 _21699;
            do
            {
                float4x4 _14848;
                bool _21698;
                do
                {
                    _14848 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                    if (_14714)
                    {
                        _21698 = false;
                        break;
                    }
                    uint _14882 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                    if (rw_nfru_diagnostics.Load<uint>((_14882 + 32u) * 4 + 0) != 1u)
                    {
                        _21698 = false;
                        break;
                    }
                    uint _21695;
                    _21695 = 0u;
                    for (; _21695 < 4u; _21695++)
                    {
                        for (uint _21696 = 0u; _21696 < 4u; )
                        {
                            _14848[_21695][_21696] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14882 + 16u) + (_21695 * 4u)) + _21696) * 4 + 0));
                            _21696++;
                            continue;
                        }
                    }
                    _21698 = true;
                    break;
                } while(false);
                if (_21698)
                {
                    _21699 = _14848;
                    break;
                }
                _21699 = cbFI_MotionTM1ToTP1;
                break;
            } while(false);
            float2 _21700;
            do
            {
                float4 _14973 = mul(_14814, _21699);
                float _14975 = _14973.w;
                if (!(_14975 > 9.9999999747524270787835121154785e-07f))
                {
                    _21700 = 1000000.0f.xx;
                    break;
                }
                float2 _14988 = ((_14973.xy / _14975.xx) + 1.0f.xx) * 0.5f;
                _21700 = float2(_14988.x - _14801, _14804 - _14988.y);
                break;
            } while(false);
            float2 _14551 = abs(_21694);
            bool2 _23672 = any(bool2(_14551.x > 4.0f.xx.x, _14551.y > 4.0f.xx.y)).xx;
            float2 _14557 = abs(_21700);
            bool2 _23674 = any(bool2(_14557.x > 4.0f.xx.x, _14557.y > 4.0f.xx.y)).xx;
            float2 _15002[3];
            _15002[0] = _5363;
            float2 _15118 = clamp(_5363, 0.0f.xx, 1.0f.xx);
            uint _15126_dummy_parameter;
            _15002[1] = _5363 - ((r_motion_tp1.Load(int3(int2(floor(_15118 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15126_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5588);
            _15002[2] = _5363 - (float2(_23672.x ? 0.0f.xx.x : _21694.x, _23672.y ? 0.0f.xx.y : _21694.y) * _5588);
            float _21710;
            float2 _21711;
            _21711 = _5363;
            _21710 = 1000000000.0f;
            float _23676;
            float2 _23678;
            float _23679;
            int _21709 = 0;
            float _23130 = -1.0f;
            for (; _21709 < 3; _23130 = _23676, _21711 = _23678, _21710 = _23679, _21709++)
            {
                float2 _23120;
                _23120 = _15002[_21709];
                for (int _23119 = 0; _23119 < 30; )
                {
                    uint _15742_dummy_parameter;
                    _23120 += (((_5363 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_23120, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15742_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5588)) - _23120) * 0.699999988079071044921875f);
                    _23119++;
                    continue;
                }
                float2 _16278 = clamp(_23120, 0.0f.xx, 1.0f.xx);
                uint _16286_dummy_parameter;
                bool _16822 = all(bool2(_23120.x > 0.0f.xx.x, _23120.y > 0.0f.xx.y));
                bool _16828;
                if (_16822)
                {
                    _16828 = all(bool2(_23120.x < 1.0f.xx.x, _23120.y < 1.0f.xx.y));
                }
                else
                {
                    _16828 = _16822;
                }
                float _23122;
                if (_16828)
                {
                    _23122 = length(((_23120 + ((r_motion_tp1.Load(int3(int2(floor(_16278 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16286_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5588)) - _5363) * float2(cbFI_RenderSize));
                }
                else
                {
                    _23122 = 1000000000.0f;
                }
                uint _16839_dummy_parameter;
                float _16879 = log(((r_depth_tp1.Load(int3(int2(floor(_16278 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16839_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _15078 = _23122 < 0.3499999940395355224609375f;
                bool _15080 = _21710 < 0.3499999940395355224609375f;
                bool _15090;
                if (_15078)
                {
                    _15090 = (!_15080) || (_16879 > _23130);
                }
                else
                {
                    _15090 = _15078;
                }
                bool _15103;
                if (!_15090)
                {
                    _15103 = ((!_15078) && (!_15080)) && (_23122 < _21710);
                }
                else
                {
                    _15103 = _15090;
                }
                _23676 = _15103 ? _16879 : _23130;
                bool2 _23677 = _15103.xx;
                _23678 = float2(_23677.x ? _23120.x : _21711.x, _23677.y ? _23120.y : _21711.y);
                _23679 = _15103 ? _23122 : _21710;
            }
            float2 _16881[3];
            _16881[0] = _5363;
            float2 _21739;
            do
            {
                bool _21720;
                do
                {
                    bool _17124 = all(bool2(_15118.x > 0.0f.xx.x, _15118.y > 0.0f.xx.y));
                    bool _17130;
                    if (_17124)
                    {
                        _17130 = all(bool2(_15118.x < 1.0f.xx.x, _15118.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17130 = _17124;
                    }
                    if (!_17130)
                    {
                        _21720 = false;
                        break;
                    }
                    uint _17137_dummy_parameter;
                    float4x4 _21718;
                    do
                    {
                        float4x4 _17151;
                        bool _21717;
                        do
                        {
                            _17151 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14714)
                            {
                                _21717 = false;
                                break;
                            }
                            uint _17185 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_17185 + 32u) * 4 + 0) != 1u)
                            {
                                _21717 = false;
                                break;
                            }
                            uint _21714;
                            _21714 = 0u;
                            for (; _21714 < 4u; _21714++)
                            {
                                for (uint _21715 = 0u; _21715 < 4u; )
                                {
                                    _17151[_21714][_21715] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17185 + (_21714 * 4u)) + _21715) * 4 + 0));
                                    _21715++;
                                    continue;
                                }
                            }
                            _21717 = true;
                            break;
                        } while(false);
                        if (_21717)
                        {
                            _21718 = _17151;
                            break;
                        }
                        _21718 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _21719;
                    do
                    {
                        float _17262 = _15118.x;
                        float _17265 = 1.0f - _15118.y;
                        float4 _17276 = mul(float4((float2(_17262, _17265) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15118 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17137_dummy_parameter))))), 0)).x, 1.0f), _21718);
                        float _17278 = _17276.w;
                        if (!(_17278 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21719 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17291 = ((_17276.xy / _17278.xx) + 1.0f.xx) * 0.5f;
                        _21719 = float2(_17291.x - _17262, _17265 - _17291.y);
                        break;
                    } while(false);
                    float2 _17088 = abs(_21719);
                    if (any(bool2(_17088.x > 100000.0f.xx.x, _17088.y > 100000.0f.xx.y)))
                    {
                        _21720 = false;
                        break;
                    }
                    float _17096 = length(_21719 * _7050);
                    uint _17311_dummy_parameter;
                    bool _17110 = _17096 > ((8.0f * _7050.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _17117;
                    if (_17110)
                    {
                        _17117 = length((r_motion_tp1.Load(int3(int2(floor(_15118 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17311_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7050) < (0.20000000298023223876953125f * _17096);
                    }
                    else
                    {
                        _17117 = _17110;
                    }
                    _21720 = _17117;
                    break;
                } while(false);
                if (_21720)
                {
                    uint _17342_dummy_parameter;
                    _21739 = -(r_motion_tp1.Load(int3(int2(floor(_15118 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17342_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                    break;
                }
                uint _17369_dummy_parameter;
                float4x4 _21733;
                do
                {
                    float4x4 _17383;
                    bool _21732;
                    do
                    {
                        _17383 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_14714)
                        {
                            _21732 = false;
                            break;
                        }
                        uint _17417 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_17417 + 32u) * 4 + 0) != 1u)
                        {
                            _21732 = false;
                            break;
                        }
                        uint _21729;
                        _21729 = 0u;
                        for (; _21729 < 4u; _21729++)
                        {
                            for (uint _21730 = 0u; _21730 < 4u; )
                            {
                                _17383[_21729][_21730] = asfloat(rw_nfru_diagnostics.Load<uint>((((_17417 + 16u) + (_21729 * 4u)) + _21730) * 4 + 0));
                                _21730++;
                                continue;
                            }
                        }
                        _21732 = true;
                        break;
                    } while(false);
                    if (_21732)
                    {
                        _21733 = _17383;
                        break;
                    }
                    _21733 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float2 _21738;
                do
                {
                    float _17494 = _15118.x;
                    float _17497 = 1.0f - _15118.y;
                    float4 _17508 = mul(float4((float2(_17494, _17497) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15118 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17369_dummy_parameter))))), 0)).x, 1.0f), _21733);
                    float _17510 = _17508.w;
                    if (!(_17510 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21738 = 1000000.0f.xx;
                        break;
                    }
                    float2 _17523 = ((_17508.xy / _17510.xx) + 1.0f.xx) * 0.5f;
                    _21738 = float2(_17523.x - _17494, _17497 - _17523.y);
                    break;
                } while(false);
                float2 _17055 = abs(_21738);
                bool2 _17059 = any(bool2(_17055.x > 4.0f.xx.x, _17055.y > 4.0f.xx.y)).xx;
                _21739 = float2(_17059.x ? 0.0f.xx.x : _21738.x, _17059.y ? 0.0f.xx.y : _21738.y);
                break;
            } while(false);
            _16881[1] = _5363 - (_21739 * cbFI_Timestep);
            _16881[2] = _5363 - (float2(_23674.x ? 0.0f.xx.x : _21700.x, _23674.y ? 0.0f.xx.y : _21700.y) * cbFI_Timestep);
            float _21741;
            float2 _21742;
            _21742 = _5363;
            _21741 = 1000000000.0f;
            float _23680;
            float2 _23682;
            float _23683;
            float4x4 _17767;
            float4x4 _17999;
            float4x4 _18311;
            float4x4 _18543;
            int _21740 = 0;
            float _23032 = -1.0f;
            for (; _21740 < 3; _23032 = _23680, _21742 = _23682, _21741 = _23683, _21740++)
            {
                float2 _22965;
                _22965 = _16881[_21740];
                float2 _17577;
                for (int _22964 = 0; _22964 < 30; _22965 = _17577, _22964++)
                {
                    float2 _23090;
                    do
                    {
                        float2 _17656 = clamp(_22965, 0.0f.xx, 1.0f.xx);
                        bool _23071;
                        do
                        {
                            bool _17740 = all(bool2(_17656.x > 0.0f.xx.x, _17656.y > 0.0f.xx.y));
                            bool _17746;
                            if (_17740)
                            {
                                _17746 = all(bool2(_17656.x < 1.0f.xx.x, _17656.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _17746 = _17740;
                            }
                            if (!_17746)
                            {
                                _23071 = false;
                                break;
                            }
                            uint _17753_dummy_parameter;
                            float4x4 _23069;
                            do
                            {
                                bool _23068;
                                do
                                {
                                    _17767 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14714)
                                    {
                                        _23068 = false;
                                        break;
                                    }
                                    uint _17801 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_17801 + 32u) * 4 + 0) != 1u)
                                    {
                                        _23068 = false;
                                        break;
                                    }
                                    uint _23065;
                                    _23065 = 0u;
                                    for (; _23065 < 4u; _23065++)
                                    {
                                        for (uint _23066 = 0u; _23066 < 4u; )
                                        {
                                            _17767[_23065][_23066] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17801 + (_23065 * 4u)) + _23066) * 4 + 0));
                                            _23066++;
                                            continue;
                                        }
                                    }
                                    _23068 = true;
                                    break;
                                } while(false);
                                if (_23068)
                                {
                                    _23069 = _17767;
                                    break;
                                }
                                _23069 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _23070;
                            do
                            {
                                float _17878 = _17656.x;
                                float _17881 = 1.0f - _17656.y;
                                float4 _17892 = mul(float4((float2(_17878, _17881) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17656 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17753_dummy_parameter))))), 0)).x, 1.0f), _23069);
                                float _17894 = _17892.w;
                                if (!(_17894 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _23070 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17907 = ((_17892.xy / _17894.xx) + 1.0f.xx) * 0.5f;
                                _23070 = float2(_17907.x - _17878, _17881 - _17907.y);
                                break;
                            } while(false);
                            float2 _17704 = abs(_23070);
                            if (any(bool2(_17704.x > 100000.0f.xx.x, _17704.y > 100000.0f.xx.y)))
                            {
                                _23071 = false;
                                break;
                            }
                            float _17712 = length(_23070 * _7050);
                            uint _17927_dummy_parameter;
                            bool _17726 = _17712 > ((8.0f * _7050.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _17733;
                            if (_17726)
                            {
                                _17733 = length((r_motion_tp1.Load(int3(int2(floor(_17656 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17927_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7050) < (0.20000000298023223876953125f * _17712);
                            }
                            else
                            {
                                _17733 = _17726;
                            }
                            _23071 = _17733;
                            break;
                        } while(false);
                        if (_23071)
                        {
                            uint _17958_dummy_parameter;
                            _23090 = -(r_motion_tp1.Load(int3(int2(floor(_17656 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17958_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _17985_dummy_parameter;
                        float4x4 _23084;
                        do
                        {
                            bool _23083;
                            do
                            {
                                _17999 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14714)
                                {
                                    _23083 = false;
                                    break;
                                }
                                uint _18033 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_18033 + 32u) * 4 + 0) != 1u)
                                {
                                    _23083 = false;
                                    break;
                                }
                                uint _23080;
                                _23080 = 0u;
                                for (; _23080 < 4u; _23080++)
                                {
                                    for (uint _23081 = 0u; _23081 < 4u; )
                                    {
                                        _17999[_23080][_23081] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18033 + 16u) + (_23080 * 4u)) + _23081) * 4 + 0));
                                        _23081++;
                                        continue;
                                    }
                                }
                                _23083 = true;
                                break;
                            } while(false);
                            if (_23083)
                            {
                                _23084 = _17999;
                                break;
                            }
                            _23084 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float2 _23089;
                        do
                        {
                            float _18110 = _17656.x;
                            float _18113 = 1.0f - _17656.y;
                            float4 _18124 = mul(float4((float2(_18110, _18113) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17656 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17985_dummy_parameter))))), 0)).x, 1.0f), _23084);
                            float _18126 = _18124.w;
                            if (!(_18126 > 9.9999999747524270787835121154785e-07f))
                            {
                                _23089 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18139 = ((_18124.xy / _18126.xx) + 1.0f.xx) * 0.5f;
                            _23089 = float2(_18139.x - _18110, _18113 - _18139.y);
                            break;
                        } while(false);
                        float2 _17671 = abs(_23089);
                        bool2 _17675 = any(bool2(_17671.x > 4.0f.xx.x, _17671.y > 4.0f.xx.y)).xx;
                        _23090 = float2(_17675.x ? 0.0f.xx.x : _23089.x, _17675.y ? 0.0f.xx.y : _23089.y);
                        break;
                    } while(false);
                    _17577 = _22965 + (((_5363 - (_23090 * cbFI_Timestep)) - _22965) * 0.699999988079071044921875f);
                }
                float2 _18200;
                float2 _22991;
                do
                {
                    _18200 = clamp(_22965, 0.0f.xx, 1.0f.xx);
                    bool _22972;
                    do
                    {
                        bool _18284 = all(bool2(_18200.x > 0.0f.xx.x, _18200.y > 0.0f.xx.y));
                        bool _18290;
                        if (_18284)
                        {
                            _18290 = all(bool2(_18200.x < 1.0f.xx.x, _18200.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _18290 = _18284;
                        }
                        if (!_18290)
                        {
                            _22972 = false;
                            break;
                        }
                        uint _18297_dummy_parameter;
                        float4x4 _22970;
                        do
                        {
                            bool _22969;
                            do
                            {
                                _18311 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14714)
                                {
                                    _22969 = false;
                                    break;
                                }
                                uint _18345 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_18345 + 32u) * 4 + 0) != 1u)
                                {
                                    _22969 = false;
                                    break;
                                }
                                uint _22966;
                                _22966 = 0u;
                                for (; _22966 < 4u; _22966++)
                                {
                                    for (uint _22967 = 0u; _22967 < 4u; )
                                    {
                                        _18311[_22966][_22967] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18345 + (_22966 * 4u)) + _22967) * 4 + 0));
                                        _22967++;
                                        continue;
                                    }
                                }
                                _22969 = true;
                                break;
                            } while(false);
                            if (_22969)
                            {
                                _22970 = _18311;
                                break;
                            }
                            _22970 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _22971;
                        do
                        {
                            float _18425 = 1.0f - _18200.y;
                            float4 _18436 = mul(float4((float2(_18200.x, _18425) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18200 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18297_dummy_parameter))))), 0)).x, 1.0f), _22970);
                            float _18438 = _18436.w;
                            if (!(_18438 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22971 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18451 = ((_18436.xy / _18438.xx) + 1.0f.xx) * 0.5f;
                            _22971 = float2(_18451.x - _18200.x, _18425 - _18451.y);
                            break;
                        } while(false);
                        float2 _18248 = abs(_22971);
                        if (any(bool2(_18248.x > 100000.0f.xx.x, _18248.y > 100000.0f.xx.y)))
                        {
                            _22972 = false;
                            break;
                        }
                        float _18256 = length(_22971 * _7050);
                        uint _18471_dummy_parameter;
                        bool _18270 = _18256 > ((8.0f * _7050.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _18277;
                        if (_18270)
                        {
                            _18277 = length((r_motion_tp1.Load(int3(int2(floor(_18200 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18471_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7050) < (0.20000000298023223876953125f * _18256);
                        }
                        else
                        {
                            _18277 = _18270;
                        }
                        _22972 = _18277;
                        break;
                    } while(false);
                    if (_22972)
                    {
                        uint _18502_dummy_parameter;
                        _22991 = -(r_motion_tp1.Load(int3(int2(floor(_18200 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18502_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _18529_dummy_parameter;
                    float4x4 _22985;
                    do
                    {
                        bool _22984;
                        do
                        {
                            _18543 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14714)
                            {
                                _22984 = false;
                                break;
                            }
                            uint _18577 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_18577 + 32u) * 4 + 0) != 1u)
                            {
                                _22984 = false;
                                break;
                            }
                            uint _22981;
                            _22981 = 0u;
                            for (; _22981 < 4u; _22981++)
                            {
                                for (uint _22982 = 0u; _22982 < 4u; )
                                {
                                    _18543[_22981][_22982] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18577 + 16u) + (_22981 * 4u)) + _22982) * 4 + 0));
                                    _22982++;
                                    continue;
                                }
                            }
                            _22984 = true;
                            break;
                        } while(false);
                        if (_22984)
                        {
                            _22985 = _18543;
                            break;
                        }
                        _22985 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _22990;
                    do
                    {
                        float _18657 = 1.0f - _18200.y;
                        float4 _18668 = mul(float4((float2(_18200.x, _18657) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18200 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18529_dummy_parameter))))), 0)).x, 1.0f), _22985);
                        float _18670 = _18668.w;
                        if (!(_18670 > 9.9999999747524270787835121154785e-07f))
                        {
                            _22990 = 1000000.0f.xx;
                            break;
                        }
                        float2 _18683 = ((_18668.xy / _18670.xx) + 1.0f.xx) * 0.5f;
                        _22990 = float2(_18683.x - _18200.x, _18657 - _18683.y);
                        break;
                    } while(false);
                    float2 _18215 = abs(_22990);
                    bool2 _18219 = any(bool2(_18215.x > 4.0f.xx.x, _18215.y > 4.0f.xx.y)).xx;
                    _22991 = float2(_18219.x ? 0.0f.xx.x : _22990.x, _18219.y ? 0.0f.xx.y : _22990.y);
                    break;
                } while(false);
                bool _18701 = all(bool2(_22965.x > 0.0f.xx.x, _22965.y > 0.0f.xx.y));
                bool _18707;
                if (_18701)
                {
                    _18707 = all(bool2(_22965.x < 1.0f.xx.x, _22965.y < 1.0f.xx.y));
                }
                else
                {
                    _18707 = _18701;
                }
                float _23007;
                if (_18707)
                {
                    _23007 = length(((_22965 + (_22991 * cbFI_Timestep)) - _5363) * float2(cbFI_RenderSize));
                }
                else
                {
                    _23007 = 1000000000.0f;
                }
                uint _18734_dummy_parameter;
                float _18758 = log(((r_depth_tm1.Load(int3(int2(floor(_18200 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18734_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _16957 = _23007 < 0.3499999940395355224609375f;
                bool _16959 = _21741 < 0.3499999940395355224609375f;
                bool _16969;
                if (_16957)
                {
                    _16969 = (!_16959) || (_18758 > _23032);
                }
                else
                {
                    _16969 = _16957;
                }
                bool _16982;
                if (!_16969)
                {
                    _16982 = ((!_16957) && (!_16959)) && (_23007 < _21741);
                }
                else
                {
                    _16982 = _16969;
                }
                _23680 = _16982 ? _18758 : _23032;
                bool2 _23681 = _16982.xx;
                _23682 = float2(_23681.x ? _22965.x : _21742.x, _23681.y ? _22965.y : _21742.y);
                _23683 = _16982 ? _23007 : _21741;
            }
            float3 _18767 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21711, 0.0f).xyz;
            float3 _18775 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21742, 0.0f).xyz;
            uint _18782_dummy_parameter;
            uint _18813_dummy_parameter;
            float _14595 = exp((_21710 * (-2.0f)) * (_21710 * 2.0f));
            float _14602 = exp((_21741 * (-2.0f)) * (_21741 * 2.0f));
            float _14615 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21742, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18813_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21711, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18782_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
            float _14629 = ((_14595 * cbFI_Timestep) * ((1.0f - _14602) + ((_14602 * 2.0f) * _14615))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
            float _14639 = 1.0f - _14615;
            float _14646 = ((_14602 * _5588) * ((1.0f - _14595) + ((_14595 * 2.0f) * _14639))) + (9.9999997473787516355514526367188e-05f * _5588);
            float _14655 = (((_14595 * _14602) * 4.0f) * _14615) * _14639;
            _22944 = (_14655 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18775 - _18767, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14655)) * max(_14595, _14602));
            _22868 = ((_18767 * _14629) + (_18775 * _14646)) / (_14629 + _14646).xxx;
        }
        else
        {
            _22944 = 1.0f;
            _22868 = _22869;
        }
        uint _7062 = cbFI_pad0 & 255u;
        bool _22713;
        float3 _22867;
        if (_7062 != 0u)
        {
            float3 _7067 = r_present_backbuffer.Load(int3(_4857, 0)).xyz;
            float3 _7071 = r_current_interpolation_source.Load(int3(_4857, 0)).xyz;
            float3 _7075 = abs(_7067 - _7071);
            float3 _21743;
            if (_7062 == 2u)
            {
                _21743 = (abs(_7071) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21743 = 0.000244140625f.xxx;
            }
            bool _7091 = any(bool3(_7075.x > _21743.x, _7075.y > _21743.y, _7075.z > _21743.z));
            bool3 _23684 = _7091.xxx;
            _22867 = float3(_23684.x ? _7067.x : _22868.x, _23684.y ? _7067.y : _22868.y, _23684.z ? _7067.z : _22868.z);
            _22713 = _7091;
        }
        else
        {
            _22867 = _22868;
            _22713 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18851;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18851);
        }
        float3 _22849;
        if (_6736 == 1u)
        {
            _22849 = lerp(_8588, _8596, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22850;
            if (_6736 == 2u)
            {
                _22850 = lerp(_8604, _8612, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22851;
                if (_6736 == 3u)
                {
                    _22851 = float(_22713).xxx;
                }
                else
                {
                    float3 _22852;
                    if (_6736 == 4u)
                    {
                        _22852 = float3(((_19771 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22853;
                        if (_6736 == 5u)
                        {
                            _22853 = float3(((_7883 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22854;
                            if (_6736 == 6u)
                            {
                                _22854 = float3(_21277.xy, _21277.z + _21277.w);
                            }
                            else
                            {
                                float3 _22855;
                                if (_6736 == 7u)
                                {
                                    _22855 = r_current_interpolation_source.Load(int3(_4857, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22856;
                                    if (_6736 == 8u)
                                    {
                                        _22856 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5363, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22857;
                                        if (_6740)
                                        {
                                            uint _18873_dummy_parameter;
                                            uint _18905_dummy_parameter;
                                            _22857 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_5363 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18873_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_5363 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18905_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22858;
                                            if (_6743)
                                            {
                                                _22858 = _8604;
                                            }
                                            else
                                            {
                                                float3 _22859;
                                                if (_6736 == 20u)
                                                {
                                                    _22859 = _8588;
                                                }
                                                else
                                                {
                                                    float3 _22860;
                                                    if (_6736 == 21u)
                                                    {
                                                        _22860 = _8596;
                                                    }
                                                    else
                                                    {
                                                        float3 _22861;
                                                        if (_6736 == 22u)
                                                        {
                                                            _22861 = _8612;
                                                        }
                                                        else
                                                        {
                                                            float3 _22862;
                                                            if (_6736 == 18u)
                                                            {
                                                                _22862 = _22275;
                                                            }
                                                            else
                                                            {
                                                                float3 _22863;
                                                                if (_6736 == 19u)
                                                                {
                                                                    _22863 = _22010;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22864;
                                                                    if (_6736 == 23u)
                                                                    {
                                                                        _22864 = _21751;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22865;
                                                                        if (_6736 == 24u)
                                                                        {
                                                                            uint _7235 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7240 = float(rw_nfru_diagnostics.Load<uint>((_7235 + 35u) * 4 + 0));
                                                                            float _21744;
                                                                            if (_7240 > 0.0f)
                                                                            {
                                                                                _21744 = float(rw_nfru_diagnostics.Load<uint>((_7235 + 34u) * 4 + 0)) / _7240;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21744 = 0.0f;
                                                                            }
                                                                            _22865 = float3(float(rw_nfru_diagnostics.Load<uint>((_7235 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7235 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21744);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22865 = _22867;
                                                                        }
                                                                        _22864 = _22865;
                                                                    }
                                                                    _22863 = _22864;
                                                                }
                                                                _22862 = _22863;
                                                            }
                                                            _22861 = _22862;
                                                        }
                                                        _22860 = _22861;
                                                    }
                                                    _22859 = _22860;
                                                }
                                                _22858 = _22859;
                                            }
                                            _22857 = _22858;
                                        }
                                        _22856 = _22857;
                                    }
                                    _22855 = _22856;
                                }
                                _22854 = _22855;
                            }
                            _22853 = _22854;
                        }
                        _22852 = _22853;
                    }
                    _22851 = _22852;
                }
                _22850 = _22851;
            }
            _22849 = _22850;
        }
        float3 _22848;
        if ((_6736 >= 9u) && (_6736 <= 11u))
        {
            uint _7300 = 64u + uint((_19994.y * cbFI_MvDepthLaneSize.x) + _19994.x);
            uint _7304 = rw_nfru_diagnostics.Load<uint>(_7300 * 4 + 0) & 15u;
            float3 _22882;
            if (_6736 == 10u)
            {
                float3 _22847;
                if ((rw_nfru_diagnostics.Load<uint>(_7300 * 4 + 0) & 32u) != 0u)
                {
                    _22847 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22846;
                    if ((rw_nfru_diagnostics.Load<uint>(_7300 * 4 + 0) & 16u) != 0u)
                    {
                        _22846 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7325 = ((rw_nfru_diagnostics.Load<uint>(_7300 * 4 + 0) & 64u) != 0u).xxx;
                        _22846 = float3(_7325.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7325.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7325.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22847 = _22846;
                }
                _22882 = _22847;
            }
            else
            {
                float3 _22883;
                if (_6736 == 11u)
                {
                    uint _7338 = (rw_nfru_diagnostics.Load<uint>(_7300 * 4 + 0) >> 8u) & 15u;
                    uint _7341 = (rw_nfru_diagnostics.Load<uint>(_7300 * 4 + 0) >> 12u) & 15u;
                    float3 _22839;
                    if ((_7304 == 2u) || (_7304 == 3u))
                    {
                        _22839 = _4539[_7304];
                    }
                    else
                    {
                        bool _7353 = _7338 == 3u;
                        bool _7355 = _7341 == 3u;
                        float3 _22840;
                        if (_7353 && _7355)
                        {
                            _22840 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22841;
                            if (_7353)
                            {
                                _22841 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22842;
                                if (_7355)
                                {
                                    _22842 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22843;
                                    if ((_7338 == 4u) || (_7341 == 4u))
                                    {
                                        _22843 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22844;
                                        if ((_7338 == 1u) || (_7341 == 1u))
                                        {
                                            _22844 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23686 = (_7304 == 1u).xxx;
                                            _22844 = float3(_23686.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23686.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23686.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22843 = _22844;
                                    }
                                    _22842 = _22843;
                                }
                                _22841 = _22842;
                            }
                            _22840 = _22841;
                        }
                        _22839 = _22840;
                    }
                    _22883 = _22839;
                }
                else
                {
                    _22883 = _4539[min(_7304, 7u)];
                }
                _22882 = _22883;
            }
            _22848 = _22882;
        }
        else
        {
            _22848 = _22849;
        }
        float4 _22886;
        if ((_6736 >= 14u) && (_6736 <= 16u))
        {
            float2 _22884;
            if (_6736 == 14u)
            {
                uint _7411_dummy_parameter;
                uint _7417_dummy_parameter;
                _22884 = r_flow_tm1.Load(int3(clamp(int2(floor(_5363 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7411_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7417_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22885;
                if (_6736 == 16u)
                {
                    uint _18981 = r_warped_flow_qdata_tm1.Load(int3(_5379, 0)).x & 2147483647u;
                    uint _19013 = uint(max((int((_18981 >> 16u) & 15u) - 6), 0));
                    _22885 = ((float2(float((1 - (2 * int((_18981 >> 15u) & 1u))) * int(((_18981 >> uint(7)) & 127u) << _19013)), float((1 - (2 * int((_18981 >> 14u) & 1u))) * int((_18981 & 127u) << _19013))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22885 = _7883 * float2(cbFI_DisplaySize);
                }
                _22884 = _22885;
            }
            uint2 _7450 = uint2(clamp(round(_22884 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7452 = _7450.x;
            uint _7459 = _7450.y;
            _22886 = float4(float(_7452 & 255u), float((_7452 >> 8u) | ((_7459 & 15u) << 4u)), float(_7459 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22887;
            if (_6736 == 17u)
            {
                _22887 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5379, 0)).x != 0u), _5823, 0.0f, 1.0f);
            }
            else
            {
                _22887 = float4(_22848, 1.0f);
            }
            _22886 = _22887;
        }
        rw_output[_4857] = _22886.xyz;
        if (_7046)
        {
            uint _19058 = uint((_4857.y * cbFI_DisplaySize.x) + _4857.x) * 2u;
            rw_nfru_select.Store<uint>(_19058 * 4 + 0, spvPackHalf2x16(_22886.xy));
            rw_nfru_select.Store<uint>((_19058 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22886.z, (_22713 || (_6736 != 0u)) ? 2.0f : _22944)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7517 = ((uint(_4857.y) * uint(cbFI_DisplaySize.x)) + uint(_4857.x)) * 6u;
            uint _19084 = spvPackHalf2x16(clamp(_8587.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7517 * 4 + 0, (((_19084 & 32767u) >> 4u) | ((((_19084 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8587.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19119 = spvPackHalf2x16(clamp(_8595.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7517 + 1u) * 4 + 0, (((_19119 & 32767u) >> 4u) | ((((_19119 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8595.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19154 = spvPackHalf2x16(clamp(_8603.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7517 + 2u) * 4 + 0, (((_19154 & 32767u) >> 4u) | ((((_19154 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8603.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19189 = spvPackHalf2x16(clamp(_8611.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7517 + 3u) * 4 + 0, (((_19189 & 32767u) >> 4u) | ((((_19189 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8611.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19216 = r_current_interpolation_source.Load(int3(_4857, 0));
            uint _19230 = spvPackHalf2x16(clamp(_19216.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7517 + 4u) * 4 + 0, (((_19230 & 32767u) >> 4u) | ((((_19230 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19216.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _22963;
            if (_22713 || (_6736 != 0u))
            {
                _22963 = 4294967295u;
            }
            else
            {
                uint _19265 = spvPackHalf2x16(clamp(_22886.xy, 0.0f.xx, 65000.0f.xx));
                _22963 = (((_19265 & 32767u) >> 4u) | ((((_19265 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22886.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7517 + 5u) * 4 + 0, _22963);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4857] = float4(r_current_interpolation_source.Load(int3(_4857, 0)).xyz, 1.0f).xyz;
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
