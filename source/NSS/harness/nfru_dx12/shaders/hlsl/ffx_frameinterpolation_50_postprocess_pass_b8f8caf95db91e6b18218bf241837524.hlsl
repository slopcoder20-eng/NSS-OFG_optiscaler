static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19810;

static const int2 _1248[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1257[5] = { 2, 4, 7, 11, 16 };
static const float3 _4567[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4885 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4885.x >= cbFI_DisplaySize.x, _4885.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4885] = float4(r_present_backbuffer.Load(int3(_4885, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4885] = float4(r_current_interpolation_source.Load(int3(_4885, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7775 = cbFI_DisplaySize - int2(1, 1);
                int2 _7776 = clamp(_4885, int2(0, 0), _7775);
                uint _7786 = uint((_7776.y * cbFI_DisplaySize.x) + _7776.x) * 2u;
                uint _7789 = rw_nfru_select.Load<uint>(_7786 * 4 + 0);
                float2 _7790 = spvUnpackHalf2x16(_7789);
                uint _7794 = rw_nfru_select.Load<uint>((_7786 + 1u) * 4 + 0);
                float2 _7795 = spvUnpackHalf2x16(_7794);
                float _7796 = _7790.x;
                float _7798 = _7795.x;
                if (_7795.y > 1.5f)
                {
                    rw_output[_4885] = float4(_7796, _7790.y, _7798, 1.0f).xyz;
                    break;
                }
                int _23247;
                float _23248;
                float3 _23249;
                float _23250;
                float _23251;
                _23251 = 0.0f;
                _23250 = 0.0f;
                _23249 = 0.0f.xxx;
                _23248 = 0.0f;
                _23247 = -2;
                float3 _23254;
                float _23255;
                float _23256;
                float _23257;
                for (; _23247 <= 2; _23251 = _23257, _23250 = _23256, _23249 = _23254, _23248 = _23255, _23247++)
                {
                    _23257 = _23251;
                    _23256 = _23250;
                    _23255 = _23248;
                    _23254 = _23249;
                    for (int _23252 = -2; _23252 <= 2; )
                    {
                        float _7692 = float((_23252 * _23252) + (_23247 * _23247));
                        float _7697 = exp(_7692 * (-0.319999992847442626953125f));
                        int2 _7702 = int2(_23252, _23247);
                        int2 _7812 = clamp(_4885 + (_7702 * int2(2, 2)), int2(0, 0), _7775);
                        uint _7822 = uint((_7812.y * cbFI_DisplaySize.x) + _7812.x) * 2u;
                        float _7719 = exp(_7692 * (-0.5f));
                        int2 _7844 = clamp(_4885 + (_7702 * int2(6, 6)), int2(0, 0), _7775);
                        _23257 += _7719;
                        _23256 += (_7719 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7844.y * cbFI_DisplaySize.x) + _7844.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23255 += _7697;
                        _23254 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7822 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7822 + 1u) * 4 + 0)).x, _19810).xyz * _7697);
                        _23252++;
                        continue;
                    }
                }
                float3 _7749 = _23249 / _23248.xxx;
                rw_output[_4885] = float4(_7749 + ((float4(_7796, _7790.y, _7798, _7795.y).xyz - _7749) * clamp(_23250 / _23251, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5397 = (float2(_4885) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5399 = float2(cbFI_MvDepthLaneSize);
        int2 _5408 = int2(floor(_5397 * _5399));
        int2 _5413 = int2(floor(_5397 * float2(cbFI_FlowLaneSize)));
        float4 _7915 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5397 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7921 = r_warped_filled_flow_tm1.Load(int3(_5413, 0)).xy;
        float2 _7927 = r_warped_filled_motion_tp1.Load(int3(_5408, 0)).xy;
        bool _7949 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19811;
        if (_7949)
        {
            float _7962 = ((2.0f * _5397.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19811 = float2(atan(_7962) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5397.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7962 * _7962))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19811 = _5397;
        }
        bool _5434 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19832;
        bool _19974;
        int2 _20055;
        float3 _22339;
        if (_5434)
        {
            float _19813;
            float _19815;
            _19815 = 2.0f;
            _19813 = -1.0f;
            uint _4984[9];
            float _23258;
            float _23261;
            for (int _19812 = 0; _19812 < 9; _19815 = _23261, _19813 = _23258, _19812++)
            {
                _4984[_19812] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5408 + int2((_19812 % 3) - 1, (_19812 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4984[_19812] != 0u)
                {
                    float _23242;
                    if (_4984[_19812] == 0u)
                    {
                        _23242 = -1.0f;
                    }
                    else
                    {
                        _23242 = float((_4984[_19812] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23261 = min(_19815, _23242);
                    _23258 = max(_19813, _23242);
                }
                else
                {
                    _23261 = _19815;
                    _23258 = _19813;
                }
            }
            float _5480 = float(_19813 >= 0.0f);
            float3 _19378 = 0.0f.xxx;
            _19378.y = _5480;
            float2 _19833;
            bool _19975;
            int2 _20056;
            float3 _22340;
            if ((_19813 - _19815) > 0.0199999995529651641845703125f)
            {
                float _19821;
                int2 _19822;
                float2 _19823;
                int2 _19825;
                float2 _19831;
                _19831 = _7927;
                _19825 = _5408;
                _19823 = _7927;
                _19822 = _5408;
                _19821 = -1.0f;
                float _23266;
                int2 _23270;
                float2 _23281;
                int2 _23292;
                float2 _23325;
                float _23710;
                int _19820 = 0;
                float _23223 = 1000000000.0f;
                for (; _19820 < 9; _23223 = _23710, _19831 = _23325, _19825 = _23292, _19823 = _23281, _19822 = _23270, _19821 = _23266, _19820++)
                {
                    if (_4984[_19820] == 0u)
                    {
                        _23710 = _23223;
                        _23325 = _19831;
                        _23292 = _19825;
                        _23281 = _19823;
                        _23270 = _19822;
                        _23266 = _19821;
                        continue;
                    }
                    int2 _5515 = clamp(_5408 + int2((_19820 % 3) - 1, (_19820 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8037 = _4984[_19820] & 2147483647u;
                    uint _8069 = uint(max((int((_8037 >> 16u) & 15u) - 6), 0));
                    float2 _5521 = (float2(float((1 - (2 * int((_8037 >> 15u) & 1u))) * int(((_8037 >> uint(7)) & 127u) << _8069)), float((1 - (2 * int((_8037 >> 14u) & 1u))) * int((_8037 & 127u) << _8069))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23209;
                    if (_4984[_19820] == 0u)
                    {
                        _23209 = -1.0f;
                    }
                    else
                    {
                        _23209 = float((_4984[_19820] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5526 = _23209 - 0.100000001490116119384765625f;
                    float2 _23210;
                    if (_7949)
                    {
                        float2 _8146 = clamp((((_19811 + (_5521 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8149 = tan(_8146.x);
                        _23210 = (float2(_8149 / cbFI_DeviceToViewDepth.z, (tan(_8146.y) * sqrt(1.0f + (_8149 * _8149))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23210 = _19811 + (_5521 * cbFI_Timestep);
                    }
                    float _5533 = cbFI_Timestep - 1.0f;
                    float2 _23211;
                    if (_7949)
                    {
                        float2 _8217 = clamp((((_19811 + (_5521 * _5533)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8220 = tan(_8217.x);
                        _23211 = (float2(_8220 / cbFI_DeviceToViewDepth.z, (tan(_8217.y) * sqrt(1.0f + (_8220 * _8220))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23211 = _19811 + (_5521 * _5533);
                    }
                    bool _8253 = all(bool2(_23210.x > 0.0f.xx.x, _23210.y > 0.0f.xx.y));
                    bool _8259;
                    if (_8253)
                    {
                        _8259 = all(bool2(_23210.x < 1.0f.xx.x, _23210.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8259 = _8253;
                    }
                    float _23214;
                    if (_8259)
                    {
                        uint _8266_dummy_parameter;
                        _23214 = max((_5526 - (log(((r_depth_tm1.Load(int3(int2(floor(_23210 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8266_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23214 = 0.0f;
                    }
                    bool _8296 = all(bool2(_23211.x > 0.0f.xx.x, _23211.y > 0.0f.xx.y));
                    bool _8302;
                    if (_8296)
                    {
                        _8302 = all(bool2(_23211.x < 1.0f.xx.x, _23211.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8302 = _8296;
                    }
                    float _23215;
                    if (_8302)
                    {
                        uint _8309_dummy_parameter;
                        _23215 = _23214 + max((_5526 - (log(((r_depth_tp1.Load(int3(int2(floor(_23211 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8309_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23215 = _23214;
                    }
                    float _23267;
                    int2 _23271;
                    float2 _23282;
                    int2 _23293;
                    float2 _23326;
                    float _23711;
                    if (_23215 == 0.0f)
                    {
                        bool _5568 = _5526 > _19821;
                        bool2 _23719 = _5568.xx;
                        _23711 = _23223;
                        _23326 = float2(_23719.x ? _5521.x : _19831.x, _23719.y ? _5521.y : _19831.y);
                        _23293 = int2(_23719.x ? _5515.x : _19825.x, _23719.y ? _5515.y : _19825.y);
                        _23282 = _19823;
                        _23271 = _19822;
                        _23267 = _5568 ? _5526 : _19821;
                    }
                    else
                    {
                        bool _5577 = _23215 < _23223;
                        bool2 _23715 = _5577.xx;
                        _23711 = _5577 ? _23215 : _23223;
                        _23326 = _19831;
                        _23293 = _19825;
                        _23282 = float2(_23715.x ? _5521.x : _19823.x, _23715.y ? _5521.y : _19823.y);
                        _23271 = int2(_23715.x ? _5515.x : _19822.x, _23715.y ? _5515.y : _19822.y);
                        _23267 = _19821;
                    }
                    _23710 = _23711;
                    _23325 = _23326;
                    _23292 = _23293;
                    _23281 = _23282;
                    _23270 = _23271;
                    _23266 = _23267;
                }
                bool _5589 = _19821 < 0.0f;
                bool2 _23725 = _5589.xx;
                int2 _23728 = int2(_23725.x ? _19822.x : _19825.x, _23725.y ? _19822.y : _19825.y);
                _22340 = float3(1.0f, _5480, float(any(bool2(_23728.x != _5408.x, _23728.y != _5408.y))));
                _20056 = _23728;
                _19975 = _5589 ? false : true;
                _19833 = float2(_23725.x ? _19823.x : _19831.x, _23725.y ? _19823.y : _19831.y);
            }
            else
            {
                _22340 = _19378;
                _20056 = _5408;
                _19975 = false;
                _19833 = _7927;
            }
            _22339 = _22340;
            _20055 = _20056;
            _19974 = _19975;
            _19832 = _19833;
        }
        else
        {
            _22339 = 0.0f.xxx;
            _20055 = _5408;
            _19974 = false;
            _19832 = _7927;
        }
        float2 _19834;
        if (_7949)
        {
            float2 _8374 = clamp((((_19811 + (_19832 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8377 = tan(_8374.x);
            _19834 = (float2(_8377 / cbFI_DeviceToViewDepth.z, (tan(_8374.y) * sqrt(1.0f + (_8377 * _8377))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19834 = _19811 + (_19832 * cbFI_Timestep);
        }
        float _5612 = cbFI_Timestep - 1.0f;
        float2 _19836;
        if (_7949)
        {
            float2 _8445 = clamp((((_19811 + (_19832 * _5612)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8448 = tan(_8445.x);
            _19836 = (float2(_8448 / cbFI_DeviceToViewDepth.z, (tan(_8445.y) * sqrt(1.0f + (_8448 * _8448))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19836 = _19811 + (_19832 * _5612);
        }
        float _5617 = -cbFI_Timestep;
        float2 _19837;
        if (_7949)
        {
            float2 _8516 = clamp((((_19811 + (_7921 * _5617)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8519 = tan(_8516.x);
            _19837 = (float2(_8519 / cbFI_DeviceToViewDepth.z, (tan(_8516.y) * sqrt(1.0f + (_8519 * _8519))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19837 = _19811 + (_7921 * _5617);
        }
        float _5622 = 1.0f - cbFI_Timestep;
        float2 _19838;
        if (_7949)
        {
            float2 _8587 = clamp((((_19811 + (_7921 * _5622)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8590 = tan(_8587.x);
            _19838 = (float2(_8590 / cbFI_DeviceToViewDepth.z, (tan(_8587.y) * sqrt(1.0f + (_8590 * _8590))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19838 = _19811 + (_7921 * _5622);
        }
        float4 _8625 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19834, 0.0f);
        float3 _8626 = _8625.xyz;
        float4 _8633 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19836, 0.0f);
        float3 _8634 = _8633.xyz;
        float4 _8641 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19837, 0.0f);
        float3 _8642 = _8641.xyz;
        float4 _8649 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19838, 0.0f);
        float3 _8650 = _8649.xyz;
        float4 _8664 = exp(_7915 - max(max(max(_7915.x, _7915.y), _7915.z), _7915.w).xxxx);
        float4 _8671 = _8664 / (dot(_8664, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5638 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _20045;
        float _21353;
        if (_5638)
        {
            float2 _5644 = 0.5f.xx / _5399;
            float _5647 = _5644.x;
            float _5648 = -_5647;
            float _5650 = _5644.y;
            float _5651 = -_5650;
            float2 _5653 = _5397 + float2(_5648, _5651);
            float2 _5655 = float2(cbFI_DisplaySize);
            bool _19855;
            do
            {
                bool _8751 = all(bool2(_5653.x > 0.0f.xx.x, _5653.y > 0.0f.xx.y));
                bool _8757;
                if (_8751)
                {
                    _8757 = all(bool2(_5653.x < 1.0f.xx.x, _5653.y < 1.0f.xx.y));
                }
                else
                {
                    _8757 = _8751;
                }
                if (!_8757)
                {
                    _19855 = false;
                    break;
                }
                uint _8764_dummy_parameter;
                float4x4 _19853;
                do
                {
                    float4x4 _8778;
                    bool _19852;
                    do
                    {
                        _8778 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19852 = false;
                            break;
                        }
                        uint _8812 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8812 + 32u) * 4 + 0) != 1u)
                        {
                            _19852 = false;
                            break;
                        }
                        uint _19849;
                        _19849 = 0u;
                        for (; _19849 < 4u; _19849++)
                        {
                            for (uint _19850 = 0u; _19850 < 4u; )
                            {
                                _8778[_19849][_19850] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8812 + (_19849 * 4u)) + _19850) * 4 + 0));
                                _19850++;
                                continue;
                            }
                        }
                        _19852 = true;
                        break;
                    } while(false);
                    if (_19852)
                    {
                        _19853 = _8778;
                        break;
                    }
                    _19853 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19854;
                do
                {
                    float _8889 = _5653.x;
                    float _8892 = 1.0f - _5653.y;
                    float4 _8903 = mul(float4((float2(_8889, _8892) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5653 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8764_dummy_parameter))))), 0)).x, 1.0f), _19853);
                    float _8905 = _8903.w;
                    if (!(_8905 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19854 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8918 = ((_8903.xy / _8905.xx) + 1.0f.xx) * 0.5f;
                    _19854 = float2(_8918.x - _8889, _8892 - _8918.y);
                    break;
                } while(false);
                float2 _8715 = abs(_19854);
                if (any(bool2(_8715.x > 100000.0f.xx.x, _8715.y > 100000.0f.xx.y)))
                {
                    _19855 = false;
                    break;
                }
                float _8723 = length(_19854 * _5655);
                uint _8938_dummy_parameter;
                bool _8737 = _8723 > ((8.0f * _5655.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8744;
                if (_8737)
                {
                    _8744 = length((r_motion_tp1.Load(int3(int2(floor(_5653 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8938_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5655) < (0.20000000298023223876953125f * _8723);
                }
                else
                {
                    _8744 = _8737;
                }
                _19855 = _8744;
                break;
            } while(false);
            float2 _5665 = _5397 + float2(_5647, _5651);
            bool _19862;
            do
            {
                bool _9024 = all(bool2(_5665.x > 0.0f.xx.x, _5665.y > 0.0f.xx.y));
                bool _9030;
                if (_9024)
                {
                    _9030 = all(bool2(_5665.x < 1.0f.xx.x, _5665.y < 1.0f.xx.y));
                }
                else
                {
                    _9030 = _9024;
                }
                if (!_9030)
                {
                    _19862 = false;
                    break;
                }
                uint _9037_dummy_parameter;
                float4x4 _19860;
                do
                {
                    float4x4 _9051;
                    bool _19859;
                    do
                    {
                        _9051 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19859 = false;
                            break;
                        }
                        uint _9085 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9085 + 32u) * 4 + 0) != 1u)
                        {
                            _19859 = false;
                            break;
                        }
                        uint _19856;
                        _19856 = 0u;
                        for (; _19856 < 4u; _19856++)
                        {
                            for (uint _19857 = 0u; _19857 < 4u; )
                            {
                                _9051[_19856][_19857] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9085 + (_19856 * 4u)) + _19857) * 4 + 0));
                                _19857++;
                                continue;
                            }
                        }
                        _19859 = true;
                        break;
                    } while(false);
                    if (_19859)
                    {
                        _19860 = _9051;
                        break;
                    }
                    _19860 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19861;
                do
                {
                    float _9162 = _5665.x;
                    float _9165 = 1.0f - _5665.y;
                    float4 _9176 = mul(float4((float2(_9162, _9165) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5665 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9037_dummy_parameter))))), 0)).x, 1.0f), _19860);
                    float _9178 = _9176.w;
                    if (!(_9178 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19861 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9191 = ((_9176.xy / _9178.xx) + 1.0f.xx) * 0.5f;
                    _19861 = float2(_9191.x - _9162, _9165 - _9191.y);
                    break;
                } while(false);
                float2 _8988 = abs(_19861);
                if (any(bool2(_8988.x > 100000.0f.xx.x, _8988.y > 100000.0f.xx.y)))
                {
                    _19862 = false;
                    break;
                }
                float _8996 = length(_19861 * _5655);
                uint _9211_dummy_parameter;
                bool _9010 = _8996 > ((8.0f * _5655.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9017;
                if (_9010)
                {
                    _9017 = length((r_motion_tp1.Load(int3(int2(floor(_5665 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9211_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5655) < (0.20000000298023223876953125f * _8996);
                }
                else
                {
                    _9017 = _9010;
                }
                _19862 = _9017;
                break;
            } while(false);
            float2 _5678 = _5397 + float2(_5648, _5650);
            bool _19869;
            do
            {
                bool _9297 = all(bool2(_5678.x > 0.0f.xx.x, _5678.y > 0.0f.xx.y));
                bool _9303;
                if (_9297)
                {
                    _9303 = all(bool2(_5678.x < 1.0f.xx.x, _5678.y < 1.0f.xx.y));
                }
                else
                {
                    _9303 = _9297;
                }
                if (!_9303)
                {
                    _19869 = false;
                    break;
                }
                uint _9310_dummy_parameter;
                float4x4 _19867;
                do
                {
                    float4x4 _9324;
                    bool _19866;
                    do
                    {
                        _9324 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19866 = false;
                            break;
                        }
                        uint _9358 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9358 + 32u) * 4 + 0) != 1u)
                        {
                            _19866 = false;
                            break;
                        }
                        uint _19863;
                        _19863 = 0u;
                        for (; _19863 < 4u; _19863++)
                        {
                            for (uint _19864 = 0u; _19864 < 4u; )
                            {
                                _9324[_19863][_19864] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9358 + (_19863 * 4u)) + _19864) * 4 + 0));
                                _19864++;
                                continue;
                            }
                        }
                        _19866 = true;
                        break;
                    } while(false);
                    if (_19866)
                    {
                        _19867 = _9324;
                        break;
                    }
                    _19867 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19868;
                do
                {
                    float _9435 = _5678.x;
                    float _9438 = 1.0f - _5678.y;
                    float4 _9449 = mul(float4((float2(_9435, _9438) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5678 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9310_dummy_parameter))))), 0)).x, 1.0f), _19867);
                    float _9451 = _9449.w;
                    if (!(_9451 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19868 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9464 = ((_9449.xy / _9451.xx) + 1.0f.xx) * 0.5f;
                    _19868 = float2(_9464.x - _9435, _9438 - _9464.y);
                    break;
                } while(false);
                float2 _9261 = abs(_19868);
                if (any(bool2(_9261.x > 100000.0f.xx.x, _9261.y > 100000.0f.xx.y)))
                {
                    _19869 = false;
                    break;
                }
                float _9269 = length(_19868 * _5655);
                uint _9484_dummy_parameter;
                bool _9283 = _9269 > ((8.0f * _5655.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9290;
                if (_9283)
                {
                    _9290 = length((r_motion_tp1.Load(int3(int2(floor(_5678 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9484_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5655) < (0.20000000298023223876953125f * _9269);
                }
                else
                {
                    _9290 = _9283;
                }
                _19869 = _9290;
                break;
            } while(false);
            float2 _5690 = _5397 + _5644;
            bool _19876;
            do
            {
                bool _9570 = all(bool2(_5690.x > 0.0f.xx.x, _5690.y > 0.0f.xx.y));
                bool _9576;
                if (_9570)
                {
                    _9576 = all(bool2(_5690.x < 1.0f.xx.x, _5690.y < 1.0f.xx.y));
                }
                else
                {
                    _9576 = _9570;
                }
                if (!_9576)
                {
                    _19876 = false;
                    break;
                }
                uint _9583_dummy_parameter;
                float4x4 _19874;
                do
                {
                    float4x4 _9597;
                    bool _19873;
                    do
                    {
                        _9597 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19873 = false;
                            break;
                        }
                        uint _9631 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9631 + 32u) * 4 + 0) != 1u)
                        {
                            _19873 = false;
                            break;
                        }
                        uint _19870;
                        _19870 = 0u;
                        for (; _19870 < 4u; _19870++)
                        {
                            for (uint _19871 = 0u; _19871 < 4u; )
                            {
                                _9597[_19870][_19871] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9631 + (_19870 * 4u)) + _19871) * 4 + 0));
                                _19871++;
                                continue;
                            }
                        }
                        _19873 = true;
                        break;
                    } while(false);
                    if (_19873)
                    {
                        _19874 = _9597;
                        break;
                    }
                    _19874 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19875;
                do
                {
                    float _9708 = _5690.x;
                    float _9711 = 1.0f - _5690.y;
                    float4 _9722 = mul(float4((float2(_9708, _9711) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5690 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9583_dummy_parameter))))), 0)).x, 1.0f), _19874);
                    float _9724 = _9722.w;
                    if (!(_9724 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19875 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9737 = ((_9722.xy / _9724.xx) + 1.0f.xx) * 0.5f;
                    _19875 = float2(_9737.x - _9708, _9711 - _9737.y);
                    break;
                } while(false);
                float2 _9534 = abs(_19875);
                if (any(bool2(_9534.x > 100000.0f.xx.x, _9534.y > 100000.0f.xx.y)))
                {
                    _19876 = false;
                    break;
                }
                float _9542 = length(_19875 * _5655);
                uint _9757_dummy_parameter;
                bool _9556 = _9542 > ((8.0f * _5655.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9563;
                if (_9556)
                {
                    _9563 = length((r_motion_tp1.Load(int3(int2(floor(_5690 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9757_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5655) < (0.20000000298023223876953125f * _9542);
                }
                else
                {
                    _9563 = _9556;
                }
                _19876 = _9563;
                break;
            } while(false);
            float _5696 = 0.25f * (((float(_19855) + float(_19862)) + float(_19869)) + float(_19876));
            float4 _20046;
            if (_5696 < 1.0f)
            {
                bool _19883;
                do
                {
                    bool _9843 = all(bool2(_19834.x > 0.0f.xx.x, _19834.y > 0.0f.xx.y));
                    bool _9849;
                    if (_9843)
                    {
                        _9849 = all(bool2(_19834.x < 1.0f.xx.x, _19834.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9849 = _9843;
                    }
                    if (!_9849)
                    {
                        _19883 = false;
                        break;
                    }
                    uint _9856_dummy_parameter;
                    float4x4 _19881;
                    do
                    {
                        float4x4 _9870;
                        bool _19880;
                        do
                        {
                            _9870 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19880 = false;
                                break;
                            }
                            uint _9904 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9904 + 32u) * 4 + 0) != 1u)
                            {
                                _19880 = false;
                                break;
                            }
                            uint _19877;
                            _19877 = 0u;
                            for (; _19877 < 4u; _19877++)
                            {
                                for (uint _19878 = 0u; _19878 < 4u; )
                                {
                                    _9870[_19877][_19878] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9904 + (_19877 * 4u)) + _19878) * 4 + 0));
                                    _19878++;
                                    continue;
                                }
                            }
                            _19880 = true;
                            break;
                        } while(false);
                        if (_19880)
                        {
                            _19881 = _9870;
                            break;
                        }
                        _19881 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19882;
                    do
                    {
                        float _9984 = 1.0f - _19834.y;
                        float4 _9995 = mul(float4((float2(_19834.x, _9984) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19834 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9856_dummy_parameter))))), 0)).x, 1.0f), _19881);
                        float _9997 = _9995.w;
                        if (!(_9997 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19882 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10010 = ((_9995.xy / _9997.xx) + 1.0f.xx) * 0.5f;
                        _19882 = float2(_10010.x - _19834.x, _9984 - _10010.y);
                        break;
                    } while(false);
                    float2 _9807 = abs(_19882);
                    if (any(bool2(_9807.x > 100000.0f.xx.x, _9807.y > 100000.0f.xx.y)))
                    {
                        _19883 = false;
                        break;
                    }
                    float _9815 = length(_19882 * _5655);
                    uint _10030_dummy_parameter;
                    bool _9829 = _9815 > ((8.0f * _5655.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9836;
                    if (_9829)
                    {
                        _9836 = length((r_motion_tp1.Load(int3(int2(floor(_19834 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10030_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5655) < (0.20000000298023223876953125f * _9815);
                    }
                    else
                    {
                        _9836 = _9829;
                    }
                    _19883 = _9836;
                    break;
                } while(false);
                bool _19890;
                do
                {
                    bool _10116 = all(bool2(_19836.x > 0.0f.xx.x, _19836.y > 0.0f.xx.y));
                    bool _10122;
                    if (_10116)
                    {
                        _10122 = all(bool2(_19836.x < 1.0f.xx.x, _19836.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10122 = _10116;
                    }
                    if (!_10122)
                    {
                        _19890 = false;
                        break;
                    }
                    uint _10129_dummy_parameter;
                    float4x4 _19888;
                    do
                    {
                        float4x4 _10143;
                        bool _19887;
                        do
                        {
                            _10143 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19887 = false;
                                break;
                            }
                            uint _10177 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10177 + 32u) * 4 + 0) != 1u)
                            {
                                _19887 = false;
                                break;
                            }
                            uint _19884;
                            _19884 = 0u;
                            for (; _19884 < 4u; _19884++)
                            {
                                for (uint _19885 = 0u; _19885 < 4u; )
                                {
                                    _10143[_19884][_19885] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10177 + (_19884 * 4u)) + _19885) * 4 + 0));
                                    _19885++;
                                    continue;
                                }
                            }
                            _19887 = true;
                            break;
                        } while(false);
                        if (_19887)
                        {
                            _19888 = _10143;
                            break;
                        }
                        _19888 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19889;
                    do
                    {
                        float _10257 = 1.0f - _19836.y;
                        float4 _10268 = mul(float4((float2(_19836.x, _10257) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19836 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10129_dummy_parameter))))), 0)).x, 1.0f), _19888);
                        float _10270 = _10268.w;
                        if (!(_10270 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19889 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10283 = ((_10268.xy / _10270.xx) + 1.0f.xx) * 0.5f;
                        _19889 = float2(_10283.x - _19836.x, _10257 - _10283.y);
                        break;
                    } while(false);
                    float2 _10080 = abs(_19889);
                    if (any(bool2(_10080.x > 100000.0f.xx.x, _10080.y > 100000.0f.xx.y)))
                    {
                        _19890 = false;
                        break;
                    }
                    float _10088 = length(_19889 * _5655);
                    uint _10303_dummy_parameter;
                    bool _10102 = _10088 > ((8.0f * _5655.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10109;
                    if (_10102)
                    {
                        _10109 = length((r_motion_tp1.Load(int3(int2(floor(_19836 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10303_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5655) < (0.20000000298023223876953125f * _10088);
                    }
                    else
                    {
                        _10109 = _10102;
                    }
                    _19890 = _10109;
                    break;
                } while(false);
                bool _19897;
                do
                {
                    bool _10389 = all(bool2(_19837.x > 0.0f.xx.x, _19837.y > 0.0f.xx.y));
                    bool _10395;
                    if (_10389)
                    {
                        _10395 = all(bool2(_19837.x < 1.0f.xx.x, _19837.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10395 = _10389;
                    }
                    if (!_10395)
                    {
                        _19897 = false;
                        break;
                    }
                    uint _10402_dummy_parameter;
                    float4x4 _19895;
                    do
                    {
                        float4x4 _10416;
                        bool _19894;
                        do
                        {
                            _10416 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19894 = false;
                                break;
                            }
                            uint _10450 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10450 + 32u) * 4 + 0) != 1u)
                            {
                                _19894 = false;
                                break;
                            }
                            uint _19891;
                            _19891 = 0u;
                            for (; _19891 < 4u; _19891++)
                            {
                                for (uint _19892 = 0u; _19892 < 4u; )
                                {
                                    _10416[_19891][_19892] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10450 + (_19891 * 4u)) + _19892) * 4 + 0));
                                    _19892++;
                                    continue;
                                }
                            }
                            _19894 = true;
                            break;
                        } while(false);
                        if (_19894)
                        {
                            _19895 = _10416;
                            break;
                        }
                        _19895 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19896;
                    do
                    {
                        float _10530 = 1.0f - _19837.y;
                        float4 _10541 = mul(float4((float2(_19837.x, _10530) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19837 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10402_dummy_parameter))))), 0)).x, 1.0f), _19895);
                        float _10543 = _10541.w;
                        if (!(_10543 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19896 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10556 = ((_10541.xy / _10543.xx) + 1.0f.xx) * 0.5f;
                        _19896 = float2(_10556.x - _19837.x, _10530 - _10556.y);
                        break;
                    } while(false);
                    float2 _10353 = abs(_19896);
                    if (any(bool2(_10353.x > 100000.0f.xx.x, _10353.y > 100000.0f.xx.y)))
                    {
                        _19897 = false;
                        break;
                    }
                    float _10361 = length(_19896 * _5655);
                    uint _10576_dummy_parameter;
                    bool _10375 = _10361 > ((8.0f * _5655.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10382;
                    if (_10375)
                    {
                        _10382 = length((r_motion_tp1.Load(int3(int2(floor(_19837 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10576_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5655) < (0.20000000298023223876953125f * _10361);
                    }
                    else
                    {
                        _10382 = _10375;
                    }
                    _19897 = _10382;
                    break;
                } while(false);
                bool _19904;
                do
                {
                    bool _10662 = all(bool2(_19838.x > 0.0f.xx.x, _19838.y > 0.0f.xx.y));
                    bool _10668;
                    if (_10662)
                    {
                        _10668 = all(bool2(_19838.x < 1.0f.xx.x, _19838.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10668 = _10662;
                    }
                    if (!_10668)
                    {
                        _19904 = false;
                        break;
                    }
                    uint _10675_dummy_parameter;
                    float4x4 _19902;
                    do
                    {
                        float4x4 _10689;
                        bool _19901;
                        do
                        {
                            _10689 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19901 = false;
                                break;
                            }
                            uint _10723 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10723 + 32u) * 4 + 0) != 1u)
                            {
                                _19901 = false;
                                break;
                            }
                            uint _19898;
                            _19898 = 0u;
                            for (; _19898 < 4u; _19898++)
                            {
                                for (uint _19899 = 0u; _19899 < 4u; )
                                {
                                    _10689[_19898][_19899] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10723 + (_19898 * 4u)) + _19899) * 4 + 0));
                                    _19899++;
                                    continue;
                                }
                            }
                            _19901 = true;
                            break;
                        } while(false);
                        if (_19901)
                        {
                            _19902 = _10689;
                            break;
                        }
                        _19902 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19903;
                    do
                    {
                        float _10803 = 1.0f - _19838.y;
                        float4 _10814 = mul(float4((float2(_19838.x, _10803) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19838 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10675_dummy_parameter))))), 0)).x, 1.0f), _19902);
                        float _10816 = _10814.w;
                        if (!(_10816 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19903 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10829 = ((_10814.xy / _10816.xx) + 1.0f.xx) * 0.5f;
                        _19903 = float2(_10829.x - _19838.x, _10803 - _10829.y);
                        break;
                    } while(false);
                    float2 _10626 = abs(_19903);
                    if (any(bool2(_10626.x > 100000.0f.xx.x, _10626.y > 100000.0f.xx.y)))
                    {
                        _19904 = false;
                        break;
                    }
                    float _10634 = length(_19903 * _5655);
                    uint _10849_dummy_parameter;
                    bool _10648 = _10634 > ((8.0f * _5655.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10655;
                    if (_10648)
                    {
                        _10655 = length((r_motion_tp1.Load(int3(int2(floor(_19838 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10849_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5655) < (0.20000000298023223876953125f * _10634);
                    }
                    else
                    {
                        _10655 = _10648;
                    }
                    _19904 = _10655;
                    break;
                } while(false);
                float4 _5723 = _8671 * float4(_19883 ? 0.0f : 1.0f, _19890 ? 0.0f : 1.0f, _19897 ? 0.0f : 1.0f, _19904 ? 0.0f : 1.0f);
                float _5725 = dot(_5723, 1.0f.xxxx);
                float4 _20047;
                if (_5725 > 0.001000000047497451305389404296875f)
                {
                    _20047 = _5723 / _5725.xxxx;
                }
                else
                {
                    _20047 = _8671;
                }
                _20046 = _20047;
            }
            else
            {
                _20046 = _8671;
            }
            _21353 = _5696;
            _20045 = _20046;
        }
        else
        {
            _21353 = 0.0f;
            _20045 = _8671;
        }
        bool _5742 = _5434 && (!_19974);
        bool _5751;
        if (_5742)
        {
            _5751 = (_20045.z + _20045.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5751 = _5742;
        }
        bool _5762;
        if (_5751)
        {
            _5762 = length((_19837 - _19834) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5762 = _5751;
        }
        bool _20134;
        if (_5762)
        {
            uint4 _10878 = r_warped_motion_qdata_tp1.Load(int3(_20055, 0));
            uint _10879 = _10878.x;
            bool _20137;
            if (_10879 != 0u)
            {
                float _20123;
                if (_10879 == 0u)
                {
                    _20123 = -1.0f;
                }
                else
                {
                    _20123 = float((_10879 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5772 = _20123 - 0.12000000476837158203125f;
                bool _10898 = all(bool2(_19837.x > 0.0f.xx.x, _19837.y > 0.0f.xx.y));
                bool _10904;
                if (_10898)
                {
                    _10904 = all(bool2(_19837.x < 1.0f.xx.x, _19837.y < 1.0f.xx.y));
                }
                else
                {
                    _10904 = _10898;
                }
                bool _5782;
                if (_10904)
                {
                    uint _10911_dummy_parameter;
                    _5782 = (log(((r_depth_tm1.Load(int3(int2(floor(_19837 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10911_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5772;
                }
                else
                {
                    _5782 = _10904;
                }
                bool _5796;
                if (!_5782)
                {
                    bool _10941 = all(bool2(_19838.x > 0.0f.xx.x, _19838.y > 0.0f.xx.y));
                    bool _10947;
                    if (_10941)
                    {
                        _10947 = all(bool2(_19838.x < 1.0f.xx.x, _19838.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10947 = _10941;
                    }
                    bool _5794;
                    if (_10947)
                    {
                        uint _10954_dummy_parameter;
                        _5794 = (log(((r_depth_tp1.Load(int3(int2(floor(_19838 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10954_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5772;
                    }
                    else
                    {
                        _5794 = _10947;
                    }
                    _5796 = _5794;
                }
                else
                {
                    _5796 = _5782;
                }
                _20137 = _5796;
            }
            else
            {
                _20137 = false;
            }
            _20134 = _20137;
        }
        else
        {
            _20134 = false;
        }
        bool _5801 = _19974 || _20134;
        bool _5806;
        if (_5801)
        {
            bool _10984 = all(bool2(_19834.x > 0.0f.xx.x, _19834.y > 0.0f.xx.y));
            bool _10990;
            if (_10984)
            {
                _10990 = all(bool2(_19834.x < 1.0f.xx.x, _19834.y < 1.0f.xx.y));
            }
            else
            {
                _10990 = _10984;
            }
            _5806 = _10990;
        }
        else
        {
            _5806 = _5801;
        }
        bool _5811;
        if (_5806)
        {
            bool _10995 = all(bool2(_19836.x > 0.0f.xx.x, _19836.y > 0.0f.xx.y));
            bool _11001;
            if (_10995)
            {
                _11001 = all(bool2(_19836.x < 1.0f.xx.x, _19836.y < 1.0f.xx.y));
            }
            else
            {
                _11001 = _10995;
            }
            _5811 = _11001;
        }
        else
        {
            _5811 = _5806;
        }
        float4 _20257;
        if (_5811)
        {
            float _5817 = _20045.x + _20045.y;
            float _5822 = _20045.z + _20045.w;
            float _20152;
            if (_5817 > 0.001000000047497451305389404296875f)
            {
                _20152 = _20045.x / _5817;
            }
            else
            {
                _20152 = _5622;
            }
            _20257 = float4(_20045.x + (_5822 * _20152), _20045.y + (_5822 * (1.0f - _20152)), 0.0f, 0.0f);
        }
        else
        {
            _20257 = _20045;
        }
        bool _11029 = (cbFI_pad0 & 1024u) != 0u;
        bool _11005 = !_11029;
        bool _11006 = !_11005;
        bool _11023;
        if (_11006)
        {
            _11023 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_20055.y * cbFI_MvDepthLaneSize.x) + _20055.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11023 = _11005;
        }
        bool _11055;
        if (_11006)
        {
            _11055 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5413.y * cbFI_FlowLaneSize.x) + _5413.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11055 = _11005;
        }
        float _5857 = float(_11055);
        bool _20278;
        float4 _20317;
        float3 _22073;
        if (_11029)
        {
            bool _5867;
            if (_11023)
            {
                _5867 = all(bool2(_19834.x > 0.0f.xx.x, _19834.y > 0.0f.xx.y));
            }
            else
            {
                _5867 = _11023;
            }
            bool _5873;
            if (_5867)
            {
                _5873 = all(bool2(_19834.x < 1.0f.xx.x, _19834.y < 1.0f.xx.y));
            }
            else
            {
                _5873 = _5867;
            }
            bool _5880;
            if (_11023)
            {
                _5880 = all(bool2(_19836.x > 0.0f.xx.x, _19836.y > 0.0f.xx.y));
            }
            else
            {
                _5880 = _11023;
            }
            bool _5886;
            if (_5880)
            {
                _5886 = all(bool2(_19836.x < 1.0f.xx.x, _19836.y < 1.0f.xx.y));
            }
            else
            {
                _5886 = _5880;
            }
            bool _5893;
            if (_11055)
            {
                _5893 = all(bool2(_19837.x > 0.0f.xx.x, _19837.y > 0.0f.xx.y));
            }
            else
            {
                _5893 = _11055;
            }
            bool _5899;
            if (_5893)
            {
                _5899 = all(bool2(_19837.x < 1.0f.xx.x, _19837.y < 1.0f.xx.y));
            }
            else
            {
                _5899 = _5893;
            }
            bool _5906;
            if (_11055)
            {
                _5906 = all(bool2(_19838.x > 0.0f.xx.x, _19838.y > 0.0f.xx.y));
            }
            else
            {
                _5906 = _11055;
            }
            bool _5912;
            if (_5906)
            {
                _5912 = all(bool2(_19838.x < 1.0f.xx.x, _19838.y < 1.0f.xx.y));
            }
            else
            {
                _5912 = _5906;
            }
            bool _5914 = !_11023;
            if (_5914)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11097;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11097);
                }
            }
            bool _5919 = !_11055;
            if (_5919)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11107;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11107);
                }
            }
            if (_11023 && _5919)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11117;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11117);
                }
            }
            if (_5914 && _11055)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11127;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11127);
                }
            }
            float _5938 = float(_5873);
            float _5940 = float(_5886);
            bool _5943 = _5899 && _5912;
            float _20186;
            if (_5943)
            {
                _20186 = 1.0f;
            }
            else
            {
                _20186 = (_5899 || _5912) ? 0.5f : 0.0f;
            }
            bool _20201;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5873)) && (!_5886))
            {
                bool _5973;
                if (_5943)
                {
                    float _20194;
                    do
                    {
                        bool _11211 = all(bool2(_19837.x > 0.0f.xx.x, _19837.y > 0.0f.xx.y));
                        bool _11217;
                        if (_11211)
                        {
                            _11217 = all(bool2(_19837.x < 1.0f.xx.x, _19837.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11217 = _11211;
                        }
                        bool _11148 = !_11217;
                        bool _11155;
                        if (!_11148)
                        {
                            bool _11222 = all(bool2(_19838.x > 0.0f.xx.x, _19838.y > 0.0f.xx.y));
                            bool _11228;
                            if (_11222)
                            {
                                _11228 = all(bool2(_19838.x < 1.0f.xx.x, _19838.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11228 = _11222;
                            }
                            _11155 = !_11228;
                        }
                        else
                        {
                            _11155 = _11148;
                        }
                        if (_11155)
                        {
                            _20194 = 0.0f;
                            break;
                        }
                        uint _11235_dummy_parameter;
                        uint _11251_dummy_parameter;
                        float4x4 _20193;
                        do
                        {
                            float4x4 _11265;
                            bool _20192;
                            do
                            {
                                _11265 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20192 = false;
                                    break;
                                }
                                uint _11299 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11299 + 32u) * 4 + 0) != 1u)
                                {
                                    _20192 = false;
                                    break;
                                }
                                uint _20189;
                                _20189 = 0u;
                                for (; _20189 < 4u; _20189++)
                                {
                                    for (uint _20190 = 0u; _20190 < 4u; )
                                    {
                                        _11265[_20189][_20190] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11299 + 16u) + (_20189 * 4u)) + _20190) * 4 + 0));
                                        _20190++;
                                        continue;
                                    }
                                }
                                _20192 = true;
                                break;
                            } while(false);
                            if (_20192)
                            {
                                _20193 = _11265;
                                break;
                            }
                            _20193 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11176 = mul(float4((float2(_19837.x, 1.0f - _19837.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19837 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11235_dummy_parameter))))), 0)).x, 1.0f), _20193);
                        float _11178 = _11176.w;
                        if (abs(_11178) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20194 = 0.0f;
                            break;
                        }
                        float _11189 = abs(cbFI_DeviceToViewDepth.y / ((_11176.z / _11178) - cbFI_DeviceToViewDepth.x));
                        float _11192 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19838 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11251_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20194 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11189 - _11192) / max(max(_11189, _11192), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5973 = _20194 >= 0.5f;
                }
                else
                {
                    _5973 = _5943;
                }
                bool _5981;
                if (_5973)
                {
                    _5981 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5981 = _5973;
                }
                bool _20202;
                if (_5981)
                {
                    uint _11403_dummy_parameter;
                    float4x4 _20199;
                    do
                    {
                        float4x4 _11417;
                        bool _20198;
                        do
                        {
                            _11417 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20198 = false;
                                break;
                            }
                            uint _11451 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11451 + 32u) * 4 + 0) != 1u)
                            {
                                _20198 = false;
                                break;
                            }
                            uint _20195;
                            _20195 = 0u;
                            for (; _20195 < 4u; _20195++)
                            {
                                for (uint _20196 = 0u; _20196 < 4u; )
                                {
                                    _11417[_20195][_20196] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11451 + 16u) + (_20195 * 4u)) + _20196) * 4 + 0));
                                    _20196++;
                                    continue;
                                }
                            }
                            _20198 = true;
                            break;
                        } while(false);
                        if (_20198)
                        {
                            _20199 = _11417;
                            break;
                        }
                        _20199 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20200;
                    do
                    {
                        float _11531 = 1.0f - _19837.y;
                        float4 _11542 = mul(float4((float2(_19837.x, _11531) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19837 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11403_dummy_parameter))))), 0)).x, 1.0f), _20199);
                        float _11544 = _11542.w;
                        if (!(_11544 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20200 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11557 = ((_11542.xy / _11544.xx) + 1.0f.xx) * 0.5f;
                        _20200 = float2(_11557.x - _19837.x, _11531 - _11557.y);
                        break;
                    } while(false);
                    float2 _5994 = float2(cbFI_DisplaySize);
                    _20202 = length(((_19837 + _20200) - _19838) * _5994) <= ((0.100000001490116119384765625f * length(_20200 * _5994)) + 8.0f);
                }
                else
                {
                    _20202 = _5973;
                }
                _20201 = _20202;
            }
            else
            {
                _20201 = true;
            }
            bool _6008 = !_20201;
            bool _23729 = _6008 ? false : _5912;
            bool _23730 = _6008 ? false : _5899;
            bool _20279;
            float4 _20318;
            if (!(((_5873 && _5886) && _23730) && _23729))
            {
                float4 _6030 = _20257 * float4(_5938, _5940, float(_23730), float(_23729));
                float _6032 = dot(_6030, 1.0f.xxxx);
                bool _6035 = !(_6032 > 0.0f);
                float4 _20319;
                if (!_6035)
                {
                    _20319 = _6030 / _6032.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11579;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11579);
                    }
                    _20319 = 0.0f.xxxx;
                }
                _20318 = _20319;
                _20279 = _6035;
            }
            else
            {
                _20318 = _20257;
                _20279 = false;
            }
            _22073 = float3(_5938, _5940, _20186);
            _20317 = _20318;
            _20278 = _20279;
        }
        else
        {
            _22073 = float3(float(_11023), _5857, 0.0f);
            _20317 = _20257;
            _20278 = false;
        }
        bool _6053 = !_20278;
        float4 _20410;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6053)
        {
            float _6060 = _20317.x + _20317.y;
            float4 _20411;
            if (_6060 > 0.001000000047497451305389404296875f)
            {
                _20411 = float4(_20317.x / _6060, _20317.y / _6060, 0.0f, 0.0f);
            }
            else
            {
                _20411 = float4(_5622, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20410 = _20411;
        }
        else
        {
            _20410 = _20317;
        }
        float4 _20587;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6053) && _11023)
        {
            float _20384;
            do
            {
                uint4 _11719 = r_warped_motion_qdata_tp1.Load(int3(_20055, 0));
                uint _11720 = _11719.x;
                if (_11720 != 0u)
                {
                    float _20383;
                    if (_11720 == 0u)
                    {
                        _20383 = -1.0f;
                    }
                    else
                    {
                        _20383 = float((_11720 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20384 = _20383;
                    break;
                }
                int _20366;
                uint _20367;
                _20367 = _11720;
                _20366 = -1;
                uint _20382;
                for (; _20366 <= 1; _20367 = _20382, _20366++)
                {
                    _20382 = _20367;
                    for (int _20380 = -1; _20380 <= 1; )
                    {
                        _20382 = max(_20382, r_warped_motion_qdata_tp1.Load(int3(clamp(_20055 + int2(_20380, _20366), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20380++;
                        continue;
                    }
                }
                if (_20367 != 0u)
                {
                    float _20379;
                    if (_20367 == 0u)
                    {
                        _20379 = -1.0f;
                    }
                    else
                    {
                        _20379 = float((_20367 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20384 = _20379;
                    break;
                }
                uint _20369;
                _20369 = 4294967295u;
                uint _23362;
                for (int _20368 = 0; _20368 < 8; _20369 = _23362, _20368++)
                {
                    int _20372 = 0;
                    for (;;)
                    {
                        if (_20372 < 5)
                        {
                            int2 _11670 = _20055 + (_1248[_20368] * _1257[_20372].xx);
                            bool _11673 = any(bool2(_11670.x < int2(0, 0).x, _11670.y < int2(0, 0).y));
                            bool _11681;
                            if (!_11673)
                            {
                                _11681 = any(bool2(_11670.x >= cbFI_MvDepthLaneSize.x, _11670.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11681 = _11673;
                            }
                            if (_11681)
                            {
                                _23362 = _20369;
                                break;
                            }
                            uint4 _11759 = r_warped_motion_qdata_tp1.Load(int3(_11670, 0));
                            uint _11760 = _11759.x;
                            if (_11760 != 0u)
                            {
                                _23362 = min(_20369, _11760);
                                break;
                            }
                            _20372++;
                            continue;
                        }
                        else
                        {
                            _23362 = _20369;
                            break;
                        }
                    }
                }
                float _20371;
                if (_20369 == 4294967295u)
                {
                    _20371 = -1.0f;
                }
                else
                {
                    float _20370;
                    if (_20369 == 0u)
                    {
                        _20370 = -1.0f;
                    }
                    else
                    {
                        _20370 = float((_20369 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20371 = _20370;
                }
                _20384 = _20371;
                break;
            } while(false);
            float _6096 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6099 = r_warped_motion_qdata_tp1.Load(int3(_20055, 0)).x == 0u;
            bool _6105;
            if (_6099)
            {
                bool _11785 = all(bool2(_19834.x > 0.0f.xx.x, _19834.y > 0.0f.xx.y));
                bool _11791;
                if (_11785)
                {
                    _11791 = all(bool2(_19834.x < 1.0f.xx.x, _19834.y < 1.0f.xx.y));
                }
                else
                {
                    _11791 = _11785;
                }
                _6105 = _11791;
            }
            else
            {
                _6105 = _6099;
            }
            bool _6110;
            if (_6105)
            {
                bool _11796 = all(bool2(_19836.x > 0.0f.xx.x, _19836.y > 0.0f.xx.y));
                bool _11802;
                if (_11796)
                {
                    _11802 = all(bool2(_19836.x < 1.0f.xx.x, _19836.y < 1.0f.xx.y));
                }
                else
                {
                    _11802 = _11796;
                }
                _6110 = _11802;
            }
            else
            {
                _6110 = _6105;
            }
            bool _20396;
            float4 _20405;
            if (_6110)
            {
                uint _11809_dummy_parameter;
                float _11833 = log(((r_depth_tm1.Load(int3(int2(floor(_19834 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11809_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _11841_dummy_parameter;
                float _11865 = log(((r_depth_tp1.Load(int3(int2(floor(_19836 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11841_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _6121 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6128;
                if (_6121)
                {
                    _6128 = _11865 > (_11833 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6128 = _6121;
                }
                bool _20401;
                float4 _20423;
                if (_6128)
                {
                    _20423 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20401 = true;
                }
                else
                {
                    bool _6134 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6141;
                    if (_6134)
                    {
                        _6141 = _11833 > (_11865 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6141 = _6134;
                    }
                    bool4 _23731 = _6141.xxxx;
                    _20423 = float4(_23731.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20410.x, _23731.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20410.y, _23731.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20410.z, _23731.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20410.w);
                    _20401 = _6141 ? true : false;
                }
                _20405 = _20423;
                _20396 = _20401;
            }
            else
            {
                _20405 = _20410;
                _20396 = false;
            }
            float4 _20478;
            if (_20396)
            {
                _20478 = 1.0f.xxxx;
            }
            else
            {
                bool _6152 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6158;
                if (_6152)
                {
                    _6158 = _20405.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6158 = _6152;
                }
                bool _6163;
                if (_6158)
                {
                    bool _11871 = all(bool2(_19836.x > 0.0f.xx.x, _19836.y > 0.0f.xx.y));
                    bool _11877;
                    if (_11871)
                    {
                        _11877 = all(bool2(_19836.x < 1.0f.xx.x, _19836.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11877 = _11871;
                    }
                    _6163 = _11877;
                }
                else
                {
                    _6163 = _6158;
                }
                float4 _20479;
                if (_6163)
                {
                    float _20432;
                    if (_20384 >= 0.0f)
                    {
                        _20432 = _20384 - _6096;
                    }
                    else
                    {
                        float _20428;
                        _20428 = 2.0f;
                        float _11934;
                        for (int _20427 = 0; _20427 < 24; _20428 = _11934, _20427++)
                        {
                            float _11898 = float(_20427 & 7) * 0.785398185253143310546875f;
                            int _11900 = _20427 >> 3;
                            int _20429;
                            if (_11900 == 0)
                            {
                                _20429 = 16;
                            }
                            else
                            {
                                _20429 = (_11900 == 1) ? 48 : 96;
                            }
                            uint _11966_dummy_parameter;
                            _11934 = min(_20428, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19836 + ((cbFI_MvDepthLaneSizeRcp * float(_20429)) * float2(cos(_11898), sin(_11898))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11966_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20432 = _20428;
                    }
                    uint _11998_dummy_parameter;
                    float4 _20480;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_19836 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11998_dummy_parameter))))), 0)).x) > ((exp((_20432 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20480 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20480 = 1.0f.xxxx;
                    }
                    _20479 = _20480;
                }
                else
                {
                    _20479 = 1.0f.xxxx;
                }
                _20478 = _20479;
            }
            bool _6191 = _20384 >= 0.0f;
            bool _6192 = (!_20396) && _6191;
            bool _6199;
            if (_6192)
            {
                _6199 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6199 = _6192;
            }
            bool _6205;
            if (_6199)
            {
                _6205 = _20405.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6205 = _6199;
            }
            bool _6210;
            if (_6205)
            {
                bool _12023 = all(bool2(_19834.x > 0.0f.xx.x, _19834.y > 0.0f.xx.y));
                bool _12029;
                if (_12023)
                {
                    _12029 = all(bool2(_19834.x < 1.0f.xx.x, _19834.y < 1.0f.xx.y));
                }
                else
                {
                    _12029 = _12023;
                }
                _6210 = _12029;
            }
            else
            {
                _6210 = _6205;
            }
            float4 _20503;
            if (_6210)
            {
                float _20472;
                if (_6191)
                {
                    _20472 = _20384 - _6096;
                }
                else
                {
                    float _20468;
                    _20468 = 2.0f;
                    float _12086;
                    for (int _20467 = 0; _20467 < 24; _20468 = _12086, _20467++)
                    {
                        float _12050 = float(_20467 & 7) * 0.785398185253143310546875f;
                        int _12052 = _20467 >> 3;
                        int _20469;
                        if (_12052 == 0)
                        {
                            _20469 = 16;
                        }
                        else
                        {
                            _20469 = (_12052 == 1) ? 48 : 96;
                        }
                        uint _12102_dummy_parameter;
                        _12086 = min(_20468, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19834 + ((cbFI_MvDepthLaneSizeRcp * float(_20469)) * float2(cos(_12050), sin(_12050))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12102_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20472 = _20468;
                }
                uint _12150_dummy_parameter;
                float4 _20504;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_19834 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12150_dummy_parameter))))), 0)).x) > ((exp((_20472 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19530 = _20478;
                    _19530.x = 0.0f;
                    _20504 = _19530;
                }
                else
                {
                    _20504 = _20478;
                }
                _20503 = _20504;
            }
            else
            {
                _20503 = _20478;
            }
            float4 _20516;
            if (_6192)
            {
                float _12177 = (exp(((_20384 - _6096) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6248 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6254;
                if (_6248)
                {
                    _6254 = _20405.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6254 = _6248;
                }
                bool _6259;
                if (_6254)
                {
                    bool _12182 = all(bool2(_19838.x > 0.0f.xx.x, _19838.y > 0.0f.xx.y));
                    bool _12188;
                    if (_12182)
                    {
                        _12188 = all(bool2(_19838.x < 1.0f.xx.x, _19838.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12188 = _12182;
                    }
                    _6259 = _12188;
                }
                else
                {
                    _6259 = _6254;
                }
                bool _6267;
                if (_6259)
                {
                    uint _12195_dummy_parameter;
                    _6267 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19838 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12195_dummy_parameter))))), 0)).x) > _12177;
                }
                else
                {
                    _6267 = _6259;
                }
                float4 _20514;
                if (_6267)
                {
                    float4 _19533 = _20503;
                    _19533.w = 0.0f;
                    _20514 = _19533;
                }
                else
                {
                    _20514 = _20503;
                }
                bool _6274 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6280;
                if (_6274)
                {
                    _6280 = _20405.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6280 = _6274;
                }
                bool _6285;
                if (_6280)
                {
                    bool _12213 = all(bool2(_19837.x > 0.0f.xx.x, _19837.y > 0.0f.xx.y));
                    bool _12219;
                    if (_12213)
                    {
                        _12219 = all(bool2(_19837.x < 1.0f.xx.x, _19837.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12219 = _12213;
                    }
                    _6285 = _12219;
                }
                else
                {
                    _6285 = _6280;
                }
                bool _6293;
                if (_6285)
                {
                    uint _12226_dummy_parameter;
                    _6293 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19837 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12226_dummy_parameter))))), 0)).x) > _12177;
                }
                else
                {
                    _6293 = _6285;
                }
                float4 _20517;
                if (_6293)
                {
                    float4 _19536 = _20514;
                    _19536.z = 0.0f;
                    _20517 = _19536;
                }
                else
                {
                    _20517 = _20514;
                }
                _20516 = _20517;
            }
            else
            {
                _20516 = _20503;
            }
            float4 _20588;
            if (any(bool4(_20516.x < 1.0f.xxxx.x, _20516.y < 1.0f.xxxx.y, _20516.z < 1.0f.xxxx.z, _20516.w < 1.0f.xxxx.w)))
            {
                float4 _6304 = _20405 * _20516;
                float _6306 = dot(_6304, 1.0f.xxxx);
                float4 _20589;
                if (_6306 > 0.0f)
                {
                    _20589 = _6304 / _6306.xxxx;
                }
                else
                {
                    bool _6317 = _20516.y == 0.0f;
                    bool _6323;
                    if (_6317)
                    {
                        _6323 = _20516.x > 0.0f;
                    }
                    else
                    {
                        _6323 = _6317;
                    }
                    bool _6328;
                    if (_6323)
                    {
                        bool _12244 = all(bool2(_19834.x > 0.0f.xx.x, _19834.y > 0.0f.xx.y));
                        bool _12250;
                        if (_12244)
                        {
                            _12250 = all(bool2(_19834.x < 1.0f.xx.x, _19834.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12250 = _12244;
                        }
                        _6328 = _12250;
                    }
                    else
                    {
                        _6328 = _6323;
                    }
                    float4 _20590;
                    if (_6328)
                    {
                        _20590 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6333 = _20516.x == 0.0f;
                        bool _6339;
                        if (_6333)
                        {
                            _6339 = _20516.y > 0.0f;
                        }
                        else
                        {
                            _6339 = _6333;
                        }
                        bool _6344;
                        if (_6339)
                        {
                            bool _12255 = all(bool2(_19836.x > 0.0f.xx.x, _19836.y > 0.0f.xx.y));
                            bool _12261;
                            if (_12255)
                            {
                                _12261 = all(bool2(_19836.x < 1.0f.xx.x, _19836.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12261 = _12255;
                            }
                            _6344 = _12261;
                        }
                        else
                        {
                            _6344 = _6339;
                        }
                        bool4 _23734 = _6344.xxxx;
                        _20590 = float4(_23734.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20405.x, _23734.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20405.y, _23734.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20405.z, _23734.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20405.w);
                    }
                    _20589 = _20590;
                }
                _20588 = _20589;
            }
            else
            {
                _20588 = _20405;
            }
            _20587 = _20588;
        }
        else
        {
            _20587 = _20410;
        }
        float4 _21317;
        bool _21623;
        float3 _21813;
        if (((cbFI_pad0 & 32768u) != 0u) && _6053)
        {
            bool _6361 = _20587.x > 0.00999999977648258209228515625f;
            bool _6364 = _20587.y > 0.00999999977648258209228515625f;
            bool _6373 = (_20587.z + _20587.w) > 0.0199999995529651641845703125f;
            bool _6379;
            if (_6373)
            {
                bool _12266 = all(bool2(_19837.x > 0.0f.xx.x, _19837.y > 0.0f.xx.y));
                bool _12272;
                if (_12266)
                {
                    _12272 = all(bool2(_19837.x < 1.0f.xx.x, _19837.y < 1.0f.xx.y));
                }
                else
                {
                    _12272 = _12266;
                }
                _6379 = _12272;
            }
            else
            {
                _6379 = _6373;
            }
            bool _6384;
            if (_6379)
            {
                bool _12277 = all(bool2(_19838.x > 0.0f.xx.x, _19838.y > 0.0f.xx.y));
                bool _12283;
                if (_12277)
                {
                    _12283 = all(bool2(_19838.x < 1.0f.xx.x, _19838.y < 1.0f.xx.y));
                }
                else
                {
                    _12283 = _12277;
                }
                _6384 = _12283;
            }
            else
            {
                _6384 = _6379;
            }
            bool _6391;
            if (_6384)
            {
                float _20603;
                do
                {
                    bool _12366 = all(bool2(_19837.x > 0.0f.xx.x, _19837.y > 0.0f.xx.y));
                    bool _12372;
                    if (_12366)
                    {
                        _12372 = all(bool2(_19837.x < 1.0f.xx.x, _19837.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12372 = _12366;
                    }
                    bool _12303 = !_12372;
                    bool _12310;
                    if (!_12303)
                    {
                        bool _12377 = all(bool2(_19838.x > 0.0f.xx.x, _19838.y > 0.0f.xx.y));
                        bool _12383;
                        if (_12377)
                        {
                            _12383 = all(bool2(_19838.x < 1.0f.xx.x, _19838.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12383 = _12377;
                        }
                        _12310 = !_12383;
                    }
                    else
                    {
                        _12310 = _12303;
                    }
                    if (_12310)
                    {
                        _20603 = 0.0f;
                        break;
                    }
                    uint _12390_dummy_parameter;
                    uint _12406_dummy_parameter;
                    float4x4 _20602;
                    do
                    {
                        float4x4 _12420;
                        bool _20601;
                        do
                        {
                            _12420 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20601 = false;
                                break;
                            }
                            uint _12454 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12454 + 32u) * 4 + 0) != 1u)
                            {
                                _20601 = false;
                                break;
                            }
                            uint _20598;
                            _20598 = 0u;
                            for (; _20598 < 4u; _20598++)
                            {
                                for (uint _20599 = 0u; _20599 < 4u; )
                                {
                                    _12420[_20598][_20599] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12454 + 16u) + (_20598 * 4u)) + _20599) * 4 + 0));
                                    _20599++;
                                    continue;
                                }
                            }
                            _20601 = true;
                            break;
                        } while(false);
                        if (_20601)
                        {
                            _20602 = _12420;
                            break;
                        }
                        _20602 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12331 = mul(float4((float2(_19837.x, 1.0f - _19837.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19837 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12390_dummy_parameter))))), 0)).x, 1.0f), _20602);
                    float _12333 = _12331.w;
                    if (abs(_12333) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20603 = 0.0f;
                        break;
                    }
                    float _12344 = abs(cbFI_DeviceToViewDepth.y / ((_12331.z / _12333) - cbFI_DeviceToViewDepth.x));
                    float _12347 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19838 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12406_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20603 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12344 - _12347) / max(max(_12344, _12347), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6391 = _20603 < 0.5f;
            }
            else
            {
                _6391 = _6384;
            }
            float4 _20622;
            if (_6391)
            {
                uint _12558_dummy_parameter;
                uint _12589_dummy_parameter;
                float4 _20623;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19837 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12558_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19838 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12589_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20623 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20623 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20622 = _20623;
            }
            else
            {
                _20622 = 1.0f.xxxx;
            }
            bool _6415;
            if (_11023)
            {
                bool _12618 = all(bool2(_19834.x > 0.0f.xx.x, _19834.y > 0.0f.xx.y));
                bool _12624;
                if (_12618)
                {
                    _12624 = all(bool2(_19834.x < 1.0f.xx.x, _19834.y < 1.0f.xx.y));
                }
                else
                {
                    _12624 = _12618;
                }
                _6415 = _12624;
            }
            else
            {
                _6415 = _11023;
            }
            bool _6421;
            if (_11023)
            {
                bool _12629 = all(bool2(_19836.x > 0.0f.xx.x, _19836.y > 0.0f.xx.y));
                bool _12635;
                if (_12629)
                {
                    _12635 = all(bool2(_19836.x < 1.0f.xx.x, _19836.y < 1.0f.xx.y));
                }
                else
                {
                    _12635 = _12629;
                }
                _6421 = _12635;
            }
            else
            {
                _6421 = _11023;
            }
            bool _6427;
            if (_11055)
            {
                bool _12640 = all(bool2(_19837.x > 0.0f.xx.x, _19837.y > 0.0f.xx.y));
                bool _12646;
                if (_12640)
                {
                    _12646 = all(bool2(_19837.x < 1.0f.xx.x, _19837.y < 1.0f.xx.y));
                }
                else
                {
                    _12646 = _12640;
                }
                _6427 = _12646;
            }
            else
            {
                _6427 = _11055;
            }
            bool _6433;
            if (_11055)
            {
                bool _12651 = all(bool2(_19838.x > 0.0f.xx.x, _19838.y > 0.0f.xx.y));
                bool _12657;
                if (_12651)
                {
                    _12657 = all(bool2(_19838.x < 1.0f.xx.x, _19838.y < 1.0f.xx.y));
                }
                else
                {
                    _12657 = _12651;
                }
                _6433 = _12657;
            }
            else
            {
                _6433 = _11055;
            }
            bool _6436 = _6427 != _6433;
            bool _6442;
            if (_6436)
            {
                _6442 = _6415 || _6421;
            }
            else
            {
                _6442 = _6436;
            }
            float4 _20725;
            if (_6442)
            {
                float4 _19563 = _20622;
                _19563.z = 0.0f;
                _19563.w = 0.0f;
                _20725 = _19563;
            }
            else
            {
                _20725 = _20622;
            }
            bool _6449 = _6415 && _6361;
            bool _6452 = _6421 && _6364;
            float4 _20830;
            float3 _21922;
            if (_6449 || _6452)
            {
                float _20720;
                do
                {
                    uint4 _12796 = r_warped_motion_qdata_tp1.Load(int3(_20055, 0));
                    uint _12797 = _12796.x;
                    if (_12797 != 0u)
                    {
                        float _20719;
                        if (_12797 == 0u)
                        {
                            _20719 = -1.0f;
                        }
                        else
                        {
                            _20719 = float((_12797 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20720 = _20719;
                        break;
                    }
                    int _20702;
                    uint _20703;
                    _20703 = _12797;
                    _20702 = -1;
                    uint _20718;
                    for (; _20702 <= 1; _20703 = _20718, _20702++)
                    {
                        _20718 = _20703;
                        for (int _20716 = -1; _20716 <= 1; )
                        {
                            _20718 = max(_20718, r_warped_motion_qdata_tp1.Load(int3(clamp(_20055 + int2(_20716, _20702), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20716++;
                            continue;
                        }
                    }
                    if (_20703 != 0u)
                    {
                        float _20715;
                        if (_20703 == 0u)
                        {
                            _20715 = -1.0f;
                        }
                        else
                        {
                            _20715 = float((_20703 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20720 = _20715;
                        break;
                    }
                    uint _20705;
                    _20705 = 4294967295u;
                    uint _23363;
                    for (int _20704 = 0; _20704 < 8; _20705 = _23363, _20704++)
                    {
                        int _20708 = 0;
                        for (;;)
                        {
                            if (_20708 < 5)
                            {
                                int2 _12747 = _20055 + (_1248[_20704] * _1257[_20708].xx);
                                bool _12750 = any(bool2(_12747.x < int2(0, 0).x, _12747.y < int2(0, 0).y));
                                bool _12758;
                                if (!_12750)
                                {
                                    _12758 = any(bool2(_12747.x >= cbFI_MvDepthLaneSize.x, _12747.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12758 = _12750;
                                }
                                if (_12758)
                                {
                                    _23363 = _20705;
                                    break;
                                }
                                uint4 _12836 = r_warped_motion_qdata_tp1.Load(int3(_12747, 0));
                                uint _12837 = _12836.x;
                                if (_12837 != 0u)
                                {
                                    _23363 = min(_20705, _12837);
                                    break;
                                }
                                _20708++;
                                continue;
                            }
                            else
                            {
                                _23363 = _20705;
                                break;
                            }
                        }
                    }
                    float _20707;
                    if (_20705 == 4294967295u)
                    {
                        _20707 = -1.0f;
                    }
                    else
                    {
                        float _20706;
                        if (_20705 == 0u)
                        {
                            _20706 = -1.0f;
                        }
                        else
                        {
                            _20706 = float((_20705 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20707 = _20706;
                    }
                    _20720 = _20707;
                    break;
                } while(false);
                bool _6460 = _20720 < 0.0f;
                float _20721;
                if (_6460)
                {
                    _20721 = 0.0f;
                }
                else
                {
                    _20721 = _20720 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12858_dummy_parameter;
                uint _12890_dummy_parameter;
                float4 _20758;
                if ((_6460 && _6449) && _6452)
                {
                    uint _12922_dummy_parameter;
                    float _12946 = log(((r_depth_tm1.Load(int3(int2(floor(_19834 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12922_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12954_dummy_parameter;
                    float _12978 = log(((r_depth_tp1.Load(int3(int2(floor(_19836 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12954_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20759;
                    if (_12946 > (_12978 + 0.07999999821186065673828125f))
                    {
                        float4 _19567 = _20725;
                        _19567.x = 0.0f;
                        _20759 = _19567;
                    }
                    else
                    {
                        float4 _20760;
                        if (_12978 > (_12946 + 0.07999999821186065673828125f))
                        {
                            float4 _19569 = _20725;
                            _19569.y = 0.0f;
                            _20760 = _19569;
                        }
                        else
                        {
                            _20760 = _20725;
                        }
                        _20759 = _20760;
                    }
                    _20758 = _20759;
                }
                else
                {
                    _20758 = _20725;
                }
                float _6512 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6514 = _20720 >= 0.0f;
                float _20741;
                if (_6514)
                {
                    _20741 = _20720 - _6512;
                }
                else
                {
                    float _20737;
                    if (_6449)
                    {
                        float _20736;
                        _20736 = 2.0f;
                        float _13036;
                        for (int _20735 = 0; _20735 < 24; _20736 = _13036, _20735++)
                        {
                            float _13000 = float(_20735 & 7) * 0.785398185253143310546875f;
                            int _13002 = _20735 >> 3;
                            int _20738;
                            if (_13002 == 0)
                            {
                                _20738 = 16;
                            }
                            else
                            {
                                _20738 = (_13002 == 1) ? 48 : 96;
                            }
                            uint _13052_dummy_parameter;
                            _13036 = min(_20736, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19834 + ((cbFI_MvDepthLaneSizeRcp * float(_20738)) * float2(cos(_13000), sin(_13000))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13052_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20737 = _20736;
                    }
                    else
                    {
                        _20737 = 0.0f;
                    }
                    _20741 = _20737;
                }
                float _20748;
                if (_6514)
                {
                    _20748 = _20720 - _6512;
                }
                else
                {
                    float _20744;
                    if (_6452)
                    {
                        float _20743;
                        _20743 = 2.0f;
                        float _13150;
                        for (int _20742 = 0; _20742 < 24; _20743 = _13150, _20742++)
                        {
                            float _13114 = float(_20742 & 7) * 0.785398185253143310546875f;
                            int _13116 = _20742 >> 3;
                            int _20745;
                            if (_13116 == 0)
                            {
                                _20745 = 16;
                            }
                            else
                            {
                                _20745 = (_13116 == 1) ? 48 : 96;
                            }
                            uint _13182_dummy_parameter;
                            _13150 = min(_20743, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19836 + ((cbFI_MvDepthLaneSizeRcp * float(_20745)) * float2(cos(_13114), sin(_13114))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13182_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20744 = _20743;
                    }
                    else
                    {
                        _20744 = 0.0f;
                    }
                    _20748 = _20744;
                }
                float _20749;
                if (_6449)
                {
                    uint _13214_dummy_parameter;
                    _20749 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_19834 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13214_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20749 = 0.0f;
                }
                float _20750;
                if (_6452)
                {
                    uint _13234_dummy_parameter;
                    _20750 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_19836 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13234_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20750 = 0.0f;
                }
                bool _6569;
                if (_6449)
                {
                    _6569 = _20749 > ((exp((_20741 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6569 = _6449;
                }
                float4 _20766;
                if (_6569)
                {
                    float4 _19571 = _20758;
                    _19571.x = 0.0f;
                    _20766 = _19571;
                }
                else
                {
                    _20766 = _20758;
                }
                bool _6581;
                if (_6452)
                {
                    _6581 = _20750 > ((exp((_20748 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6581 = _6452;
                }
                float4 _20768;
                if (_6581)
                {
                    float4 _19573 = _20766;
                    _19573.y = 0.0f;
                    _20768 = _19573;
                }
                else
                {
                    _20768 = _20766;
                }
                float4 _20831;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6514)
                {
                    bool _6601;
                    if (_6449)
                    {
                        _6601 = _20749 < ((exp((_20741 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6601 = _6449;
                    }
                    float4 _20770;
                    if (_6601)
                    {
                        float4 _19575 = _20768;
                        _19575.x = 0.0f;
                        _20770 = _19575;
                    }
                    else
                    {
                        _20770 = _20768;
                    }
                    bool _6613;
                    if (_6452)
                    {
                        _6613 = _20750 < ((exp((_20748 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6613 = _6452;
                    }
                    float4 _20832;
                    if (_6613)
                    {
                        float4 _19577 = _20770;
                        _19577.y = 0.0f;
                        _20832 = _19577;
                    }
                    else
                    {
                        _20832 = _20770;
                    }
                    _20831 = _20832;
                }
                else
                {
                    _20831 = _20768;
                }
                _21922 = float3(_20721, log(((r_depth_tm1.Load(int3(int2(floor(_19834 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12858_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_19836 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12890_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _20830 = _20831;
            }
            else
            {
                _21922 = float3(0.0f, 0.0f, 0.5f);
                _20830 = _20725;
            }
            bool _6624 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6373;
            bool _6630;
            if (_6624)
            {
                _6630 = _6427 || _6433;
            }
            else
            {
                _6630 = _6624;
            }
            float4 _20873;
            if (_6630)
            {
                float _20825;
                do
                {
                    uint4 _13414 = r_warped_motion_qdata_tp1.Load(int3(_20055, 0));
                    uint _13415 = _13414.x;
                    if (_13415 != 0u)
                    {
                        float _20824;
                        if (_13415 == 0u)
                        {
                            _20824 = -1.0f;
                        }
                        else
                        {
                            _20824 = float((_13415 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20825 = _20824;
                        break;
                    }
                    int _20807;
                    uint _20808;
                    _20808 = _13415;
                    _20807 = -1;
                    uint _20823;
                    for (; _20807 <= 1; _20808 = _20823, _20807++)
                    {
                        _20823 = _20808;
                        for (int _20821 = -1; _20821 <= 1; )
                        {
                            _20823 = max(_20823, r_warped_motion_qdata_tp1.Load(int3(clamp(_20055 + int2(_20821, _20807), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20821++;
                            continue;
                        }
                    }
                    if (_20808 != 0u)
                    {
                        float _20820;
                        if (_20808 == 0u)
                        {
                            _20820 = -1.0f;
                        }
                        else
                        {
                            _20820 = float((_20808 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20825 = _20820;
                        break;
                    }
                    uint _20810;
                    _20810 = 4294967295u;
                    uint _23364;
                    for (int _20809 = 0; _20809 < 8; _20810 = _23364, _20809++)
                    {
                        int _20813 = 0;
                        for (;;)
                        {
                            if (_20813 < 5)
                            {
                                int2 _13365 = _20055 + (_1248[_20809] * _1257[_20813].xx);
                                bool _13368 = any(bool2(_13365.x < int2(0, 0).x, _13365.y < int2(0, 0).y));
                                bool _13376;
                                if (!_13368)
                                {
                                    _13376 = any(bool2(_13365.x >= cbFI_MvDepthLaneSize.x, _13365.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13376 = _13368;
                                }
                                if (_13376)
                                {
                                    _23364 = _20810;
                                    break;
                                }
                                uint4 _13454 = r_warped_motion_qdata_tp1.Load(int3(_13365, 0));
                                uint _13455 = _13454.x;
                                if (_13455 != 0u)
                                {
                                    _23364 = min(_20810, _13455);
                                    break;
                                }
                                _20813++;
                                continue;
                            }
                            else
                            {
                                _23364 = _20810;
                                break;
                            }
                        }
                    }
                    float _20812;
                    if (_20810 == 4294967295u)
                    {
                        _20812 = -1.0f;
                    }
                    else
                    {
                        float _20811;
                        if (_20810 == 0u)
                        {
                            _20811 = -1.0f;
                        }
                        else
                        {
                            _20811 = float((_20810 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20812 = _20811;
                    }
                    _20825 = _20812;
                    break;
                } while(false);
                float4 _20874;
                if (_20825 >= 0.0f)
                {
                    float _13476 = (exp((_20825 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6649;
                    if (_6427)
                    {
                        uint _13483_dummy_parameter;
                        _6649 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19837 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13483_dummy_parameter))))), 0)).x) > _13476;
                    }
                    else
                    {
                        _6649 = _6427;
                    }
                    float4 _20843;
                    if (_6649)
                    {
                        float4 _19579 = _20830;
                        _19579.z = 0.0f;
                        _20843 = _19579;
                    }
                    else
                    {
                        _20843 = _20830;
                    }
                    bool _6661;
                    if (_6433)
                    {
                        uint _13503_dummy_parameter;
                        _6661 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19838 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13503_dummy_parameter))))), 0)).x) > _13476;
                    }
                    else
                    {
                        _6661 = _6433;
                    }
                    float4 _20875;
                    if (_6661)
                    {
                        float4 _19581 = _20843;
                        _19581.w = 0.0f;
                        _20875 = _19581;
                    }
                    else
                    {
                        _20875 = _20843;
                    }
                    _20874 = _20875;
                }
                else
                {
                    _20874 = _20830;
                }
                _20873 = _20874;
            }
            else
            {
                _20873 = _20830;
            }
            bool _6669 = _6415 != _6421;
            bool _6676;
            if (_6669)
            {
                _6676 = _6415 ? _6361 : _6364;
            }
            else
            {
                _6676 = _6669;
            }
            bool _6683;
            if (_6676)
            {
                _6683 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6683 = _6676;
            }
            float4 _20976;
            if (_6683)
            {
                bool2 _6688 = _6415.xx;
                float2 _6689 = float2(_6688.x ? _19834.x : _19836.x, _6688.y ? _19834.y : _19836.y);
                float _20857;
                if (_6415)
                {
                    uint _13523_dummy_parameter;
                    _20857 = r_depth_tm1.Load(int3(int2(floor(_6689 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13523_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13539_dummy_parameter;
                    _20857 = r_depth_tp1.Load(int3(int2(floor(_6689 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13539_dummy_parameter))))), 0)).x;
                }
                float4x4 _20864;
                if (_6415)
                {
                    float4x4 _20853;
                    do
                    {
                        float4x4 _13553;
                        bool _20852;
                        do
                        {
                            _13553 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20852 = false;
                                break;
                            }
                            uint _13587 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13587 + 32u) * 4 + 0) != 1u)
                            {
                                _20852 = false;
                                break;
                            }
                            uint _20849;
                            _20849 = 0u;
                            for (; _20849 < 4u; _20849++)
                            {
                                for (uint _20850 = 0u; _20850 < 4u; )
                                {
                                    _13553[_20849][_20850] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13587 + 16u) + (_20849 * 4u)) + _20850) * 4 + 0));
                                    _20850++;
                                    continue;
                                }
                            }
                            _20852 = true;
                            break;
                        } while(false);
                        if (_20852)
                        {
                            _20853 = _13553;
                            break;
                        }
                        _20853 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20864 = _20853;
                }
                else
                {
                    float4x4 _20848;
                    do
                    {
                        float4x4 _13659;
                        bool _20847;
                        do
                        {
                            _13659 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20847 = false;
                                break;
                            }
                            uint _13693 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13693 + 32u) * 4 + 0) != 1u)
                            {
                                _20847 = false;
                                break;
                            }
                            uint _20844;
                            _20844 = 0u;
                            for (; _20844 < 4u; _20844++)
                            {
                                for (uint _20845 = 0u; _20845 < 4u; )
                                {
                                    _13659[_20844][_20845] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13693 + (_20844 * 4u)) + _20845) * 4 + 0));
                                    _20845++;
                                    continue;
                                }
                            }
                            _20847 = true;
                            break;
                        } while(false);
                        if (_20847)
                        {
                            _20848 = _13659;
                            break;
                        }
                        _20848 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20864 = _20848;
                }
                float2 _20865;
                do
                {
                    float _13770 = _6689.x;
                    float _13773 = 1.0f - _6689.y;
                    float4 _13784 = mul(float4((float2(_13770, _13773) * 2.0f) - 1.0f.xx, _20857, 1.0f), _20864);
                    float _13786 = _13784.w;
                    if (!(_13786 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20865 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13799 = ((_13784.xy / _13786.xx) + 1.0f.xx) * 0.5f;
                    _20865 = float2(_13799.x - _13770, _13773 - _13799.y);
                    break;
                } while(false);
                float2 _6719 = float2(cbFI_DisplaySize);
                float4 _20977;
                if (!(length(((_6689 + _20865) - float2(_6688.x ? _19836.x : _19834.x, _6688.y ? _19836.y : _19834.y)) * _6719) <= ((0.100000001490116119384765625f * length(_20865 * _6719)) + 8.0f)))
                {
                    float4 _20978;
                    if (_6415)
                    {
                        float4 _19591 = _20873;
                        _19591.x = 0.0f;
                        _20978 = _19591;
                    }
                    else
                    {
                        float4 _19593 = _20873;
                        _19593.y = 0.0f;
                        _20978 = _19593;
                    }
                    _20977 = _20978;
                }
                else
                {
                    _20977 = _20873;
                }
                _20976 = _20977;
            }
            else
            {
                _20976 = _20873;
            }
            float4 _6744 = _20587 * _20976;
            float _6746 = dot(_6744, 1.0f.xxxx);
            float4 _21318;
            bool _21624;
            if (_6746 > 0.0f)
            {
                _21624 = _20278;
                _21318 = _6744 / _6746.xxxx;
            }
            else
            {
                bool _6757 = any(bool4(_20976.x < 1.0f.xxxx.x, _20976.y < 1.0f.xxxx.y, _20976.z < 1.0f.xxxx.z, _20976.w < 1.0f.xxxx.w));
                if (_6757)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13821;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13821);
                    }
                }
                bool4 _23737 = _6757.xxxx;
                _21624 = _6757 ? true : _20278;
                _21318 = float4(_23737.x ? 0.0f.xxxx.x : _20587.x, _23737.y ? 0.0f.xxxx.y : _20587.y, _23737.z ? 0.0f.xxxx.z : _20587.z, _23737.w ? 0.0f.xxxx.w : _20587.w);
            }
            _21813 = _21922;
            _21623 = _21624;
            _21317 = _21318;
        }
        else
        {
            _21813 = float3(0.0f, 0.0f, 0.5f);
            _21623 = _20278;
            _21317 = _20587;
        }
        uint _6766 = (cbFI_pad0 >> 24u) & 31u;
        uint _6770 = (cbFI_pad0 >> 16u) & 255u;
        bool _6772 = _6766 != 0u;
        bool _6774 = _6770 == 12u;
        bool _6777 = _6770 == 13u;
        float4 _21338;
        if ((_6772 || _6774) || _6777)
        {
            float _20984;
            do
            {
                bool _13905 = all(bool2(_19837.x > 0.0f.xx.x, _19837.y > 0.0f.xx.y));
                bool _13911;
                if (_13905)
                {
                    _13911 = all(bool2(_19837.x < 1.0f.xx.x, _19837.y < 1.0f.xx.y));
                }
                else
                {
                    _13911 = _13905;
                }
                bool _13842 = !_13911;
                bool _13849;
                if (!_13842)
                {
                    bool _13916 = all(bool2(_19838.x > 0.0f.xx.x, _19838.y > 0.0f.xx.y));
                    bool _13922;
                    if (_13916)
                    {
                        _13922 = all(bool2(_19838.x < 1.0f.xx.x, _19838.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13922 = _13916;
                    }
                    _13849 = !_13922;
                }
                else
                {
                    _13849 = _13842;
                }
                if (_13849)
                {
                    _20984 = 0.0f;
                    break;
                }
                uint _13929_dummy_parameter;
                uint _13945_dummy_parameter;
                float4x4 _20983;
                do
                {
                    float4x4 _13959;
                    bool _20982;
                    do
                    {
                        _13959 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20982 = false;
                            break;
                        }
                        uint _13993 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13993 + 32u) * 4 + 0) != 1u)
                        {
                            _20982 = false;
                            break;
                        }
                        uint _20979;
                        _20979 = 0u;
                        for (; _20979 < 4u; _20979++)
                        {
                            for (uint _20980 = 0u; _20980 < 4u; )
                            {
                                _13959[_20979][_20980] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13993 + 16u) + (_20979 * 4u)) + _20980) * 4 + 0));
                                _20980++;
                                continue;
                            }
                        }
                        _20982 = true;
                        break;
                    } while(false);
                    if (_20982)
                    {
                        _20983 = _13959;
                        break;
                    }
                    _20983 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13870 = mul(float4((float2(_19837.x, 1.0f - _19837.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19837 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13929_dummy_parameter))))), 0)).x, 1.0f), _20983);
                float _13872 = _13870.w;
                if (abs(_13872) < 9.9999999747524270787835121154785e-07f)
                {
                    _20984 = 0.0f;
                    break;
                }
                float _13883 = abs(cbFI_DeviceToViewDepth.y / ((_13870.z / _13872) - cbFI_DeviceToViewDepth.x));
                float _13886 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19838 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13945_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20984 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13883 - _13886) / max(max(_13883, _13886), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14095 = all(bool2(_19838.x > 0.0f.xx.x, _19838.y > 0.0f.xx.y));
            bool _14101;
            if (_14095)
            {
                _14101 = all(bool2(_19838.x < 1.0f.xx.x, _19838.y < 1.0f.xx.y));
            }
            else
            {
                _14101 = _14095;
            }
            float _20985;
            if (_14101)
            {
                uint _14108_dummy_parameter;
                _20985 = length((_7921 + (r_motion_tp1.Load(int3(int2(floor(_19838 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14108_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20985 = 1000000.0f;
            }
            float _21000;
            if ((_6766 & 1u) != 0u)
            {
                _21000 = _20984;
            }
            else
            {
                _21000 = 1.0f;
            }
            float _21001;
            if ((_6766 & 2u) != 0u)
            {
                _21001 = _21000 * (1.0f - smoothstep(2.0f, 8.0f, _20985));
            }
            else
            {
                _21001 = _21000;
            }
            float _21002;
            if ((_6766 & 4u) != 0u)
            {
                _21002 = _21001 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8642 - _8650) - length(_8626 - _8634))));
            }
            else
            {
                _21002 = _21001;
            }
            float _21332;
            if ((_6766 & 8u) != 0u)
            {
                _21332 = lerp(1.0f, _21002, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8626 - _8634)));
            }
            else
            {
                _21332 = _21002;
            }
            bool _6852 = (_6766 & 16u) != 0u;
            bool _6861;
            if (_6852)
            {
                _6861 = length(_19832 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6861 = _6852;
            }
            float _23739 = _6861 ? 1.0f : _21332;
            bool _6867 = _6772 && _11023;
            bool _6872;
            if (_6867)
            {
                bool _14133 = all(bool2(_19834.x > 0.0f.xx.x, _19834.y > 0.0f.xx.y));
                bool _14139;
                if (_14133)
                {
                    _14139 = all(bool2(_19834.x < 1.0f.xx.x, _19834.y < 1.0f.xx.y));
                }
                else
                {
                    _14139 = _14133;
                }
                _6872 = _14139;
            }
            else
            {
                _6872 = _6867;
            }
            bool _6877;
            if (_6872)
            {
                bool _14144 = all(bool2(_19836.x > 0.0f.xx.x, _19836.y > 0.0f.xx.y));
                bool _14150;
                if (_14144)
                {
                    _14150 = all(bool2(_19836.x < 1.0f.xx.x, _19836.y < 1.0f.xx.y));
                }
                else
                {
                    _14150 = _14144;
                }
                _6877 = _14150;
            }
            else
            {
                _6877 = _6872;
            }
            float4 _21339;
            if (_6877)
            {
                float _6883 = _21317.x + _21317.y;
                float _6892 = (_21317.z + _21317.w) * (1.0f - _23739);
                float _21335;
                if (_6883 > 9.9999997473787516355514526367188e-06f)
                {
                    _21335 = _21317.x / _6883;
                }
                else
                {
                    _21335 = _5622;
                }
                _21339 = float4(_21317.x + (_6892 * _21335), _21317.y + (_6892 * (1.0f - _21335)), _21317.zw * _23739);
            }
            else
            {
                _21339 = _21317;
            }
            _21338 = _21339;
        }
        else
        {
            _21338 = _21317;
        }
        float3 _6953 = (((_8626 * _21338.x) + (_8634 * _21338.y)) + (_8642 * _21338.z)) + (_8650 * _21338.w);
        float3 _22938;
        if (_5638 && (_21353 > 0.0f))
        {
            uint _14157_dummy_parameter;
            float2 _14172 = r_motion_tp1.Load(int3(int2(floor(_5397 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14157_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21615;
            if (_7949)
            {
                float2 _14217 = clamp((((_19811 + (_14172 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14220 = tan(_14217.x);
                _21615 = (float2(_14220 / cbFI_DeviceToViewDepth.z, (tan(_14217.y) * sqrt(1.0f + (_14220 * _14220))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21615 = _19811 + (_14172 * cbFI_Timestep);
            }
            float2 _21616;
            if (_7949)
            {
                float2 _14296 = clamp((((_19811 + (_14172 * _5612)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14299 = tan(_14296.x);
                _21616 = (float2(_14299 / cbFI_DeviceToViewDepth.z, (tan(_14296.y) * sqrt(1.0f + (_14299 * _14299))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21616 = _19811 + (_14172 * _5612);
            }
            _22938 = lerp(_6953, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21615, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21616, 0.0f).xyz, cbFI_Timestep.xxx), _21353.xxx);
        }
        else
        {
            _22938 = _6953;
        }
        float3 _22937;
        if (_21623)
        {
            float3 _14341 = r_current_interpolation_source.Load(int3(_4885, 0)).xyz;
            float3 _22939;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11023)
            {
                uint _14348_dummy_parameter;
                float _21746;
                _21746 = r_depth_tm1.Load(int3(int2(floor(_19834 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14348_dummy_parameter))))), 0)).x;
                float _7034;
                for (int _21745 = 0; _21745 < 24; _21746 = _7034, _21745++)
                {
                    float _7006 = float(_21745 & 7) * 0.785398185253143310546875f;
                    int _7008 = _21745 >> 3;
                    int _23206;
                    if (_7008 == 0)
                    {
                        _23206 = 16;
                    }
                    else
                    {
                        _23206 = (_7008 == 1) ? 48 : 96;
                    }
                    uint _14368_dummy_parameter;
                    _7034 = max(_21746, r_depth_tm1.Load(int3(int2(floor(clamp(_19834 + ((cbFI_MvDepthLaneSizeRcp * float(_23206)) * float2(cos(_7006), sin(_7006))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14368_dummy_parameter))))), 0)).x);
                }
                float2 _21747;
                do
                {
                    float _14390 = 1.0f - _19834.y;
                    float4 _14401 = mul(float4((float2(_19834.x, _14390) * 2.0f) - 1.0f.xx, _21746, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14403 = _14401.w;
                    if (!(_14403 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21747 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14416 = ((_14401.xy / _14403.xx) + 1.0f.xx) * 0.5f;
                    _21747 = float2(_14416.x - _19834.x, _14390 - _14416.y);
                    break;
                } while(false);
                float2 _7045 = _19834 + _21747;
                bool _14434 = all(bool2(_7045.x > 0.0f.xx.x, _7045.y > 0.0f.xx.y));
                bool _14440;
                if (_14434)
                {
                    _14440 = all(bool2(_7045.x < 1.0f.xx.x, _7045.y < 1.0f.xx.y));
                }
                else
                {
                    _14440 = _14434;
                }
                float3 _22940;
                if (_14440)
                {
                    float _7051 = abs(cbFI_DeviceToViewDepth.y / (_21746 - cbFI_DeviceToViewDepth.x));
                    uint _14460_dummy_parameter;
                    int2 _14460 = int2(spvTextureSize(r_depth_m2, uint(0), _14460_dummy_parameter));
                    float _7055 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7045 * float2(_14460))), int2(0, 0), _14460 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22945;
                    if (abs(_7055 - _7051) <= (0.20000000298023223876953125f * max(_7055, _7051)))
                    {
                        uint _14494_dummy_parameter;
                        int2 _14494 = int2(spvTextureSize(r_colour_m2, uint(0), _14494_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14517;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14517);
                        }
                        _22945 = r_colour_m2.Load(int3(clamp(int2(floor(_7045 * float2(_14494))), int2(0, 0), _14494 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14527;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14527);
                        }
                        _22945 = _14341;
                    }
                    _22940 = _22945;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14537;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14537);
                    }
                    _22940 = _14341;
                }
                _22939 = _22940;
            }
            else
            {
                _22939 = _14341;
            }
            _22937 = _22939;
        }
        else
        {
            _22937 = _22938;
        }
        bool _7080 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22936;
        float _23012;
        if (_7080)
        {
            float _14714;
            float2 _7084 = float2(cbFI_DisplaySize);
            float3 _21804;
            do
            {
                bool _14775;
                float4x4 _21754;
                do
                {
                    float4x4 _14751;
                    bool _21753;
                    do
                    {
                        _14751 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14775 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14775)
                        {
                            _21753 = false;
                            break;
                        }
                        uint _14785 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14785 + 32u) * 4 + 0) != 1u)
                        {
                            _21753 = false;
                            break;
                        }
                        uint _21750;
                        _21750 = 0u;
                        for (; _21750 < 4u; _21750++)
                        {
                            for (uint _21751 = 0u; _21751 < 4u; )
                            {
                                _14751[_21750][_21751] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14785 + (_21750 * 4u)) + _21751) * 4 + 0));
                                _21751++;
                                continue;
                            }
                        }
                        _21753 = true;
                        break;
                    } while(false);
                    if (_21753)
                    {
                        _21754 = _14751;
                        break;
                    }
                    _21754 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float _14862;
                float _14865;
                float4 _14875;
                float2 _21755;
                do
                {
                    _14862 = _5397.x;
                    _14865 = 1.0f - _5397.y;
                    _14875 = float4((float2(_14862, _14865) * 2.0f) - 1.0f.xx, 0.99999988079071044921875f, 1.0f);
                    float4 _14876 = mul(_14875, _21754);
                    float _14878 = _14876.w;
                    if (!(_14878 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21755 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14891 = ((_14876.xy / _14878.xx) + 1.0f.xx) * 0.5f;
                    _21755 = float2(_14891.x - _14862, _14865 - _14891.y);
                    break;
                } while(false);
                float4x4 _21760;
                do
                {
                    float4x4 _14909;
                    bool _21759;
                    do
                    {
                        _14909 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_14775)
                        {
                            _21759 = false;
                            break;
                        }
                        uint _14943 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14943 + 32u) * 4 + 0) != 1u)
                        {
                            _21759 = false;
                            break;
                        }
                        uint _21756;
                        _21756 = 0u;
                        for (; _21756 < 4u; _21756++)
                        {
                            for (uint _21757 = 0u; _21757 < 4u; )
                            {
                                _14909[_21756][_21757] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14943 + 16u) + (_21756 * 4u)) + _21757) * 4 + 0));
                                _21757++;
                                continue;
                            }
                        }
                        _21759 = true;
                        break;
                    } while(false);
                    if (_21759)
                    {
                        _21760 = _14909;
                        break;
                    }
                    _21760 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float2 _21761;
                do
                {
                    float4 _15034 = mul(_14875, _21760);
                    float _15036 = _15034.w;
                    if (!(_15036 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21761 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15049 = ((_15034.xy / _15036.xx) + 1.0f.xx) * 0.5f;
                    _21761 = float2(_15049.x - _14862, _14865 - _15049.y);
                    break;
                } while(false);
                float2 _14592 = abs(_21755);
                bool2 _23740 = any(bool2(_14592.x > 4.0f.xx.x, _14592.y > 4.0f.xx.y)).xx;
                float2 _14598 = abs(_21761);
                bool2 _23742 = any(bool2(_14598.x > 4.0f.xx.x, _14598.y > 4.0f.xx.y)).xx;
                float2 _15063[3];
                _15063[0] = _5397;
                float2 _15179 = clamp(_5397, 0.0f.xx, 1.0f.xx);
                uint _15187_dummy_parameter;
                _15063[1] = _5397 - ((r_motion_tp1.Load(int3(int2(floor(_15179 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15187_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5622);
                _15063[2] = _5397 - (float2(_23740.x ? 0.0f.xx.x : _21755.x, _23740.y ? 0.0f.xx.y : _21755.y) * _5622);
                float _21771;
                float2 _21772;
                _21772 = _5397;
                _21771 = 1000000000.0f;
                float _23744;
                float2 _23746;
                float _23747;
                int _21770 = 0;
                float _23198 = -1.0f;
                for (; _21770 < 3; _23198 = _23744, _21772 = _23746, _21771 = _23747, _21770++)
                {
                    float2 _23188;
                    _23188 = _15063[_21770];
                    for (int _23187 = 0; _23187 < 30; )
                    {
                        uint _15803_dummy_parameter;
                        _23188 += (((_5397 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_23188, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15803_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5622)) - _23188) * 0.699999988079071044921875f);
                        _23187++;
                        continue;
                    }
                    float2 _16339 = clamp(_23188, 0.0f.xx, 1.0f.xx);
                    uint _16347_dummy_parameter;
                    bool _16883 = all(bool2(_23188.x > 0.0f.xx.x, _23188.y > 0.0f.xx.y));
                    bool _16889;
                    if (_16883)
                    {
                        _16889 = all(bool2(_23188.x < 1.0f.xx.x, _23188.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _16889 = _16883;
                    }
                    float _23190;
                    if (_16889)
                    {
                        _23190 = length(((_23188 + ((r_motion_tp1.Load(int3(int2(floor(_16339 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16347_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5622)) - _5397) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _23190 = 1000000000.0f;
                    }
                    uint _16900_dummy_parameter;
                    float _16940 = log(((r_depth_tp1.Load(int3(int2(floor(_16339 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16900_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15139 = _23190 < 0.3499999940395355224609375f;
                    bool _15141 = _21771 < 0.3499999940395355224609375f;
                    bool _15151;
                    if (_15139)
                    {
                        _15151 = (!_15141) || (_16940 > _23198);
                    }
                    else
                    {
                        _15151 = _15139;
                    }
                    bool _15164;
                    if (!_15151)
                    {
                        _15164 = ((!_15139) && (!_15141)) && (_23190 < _21771);
                    }
                    else
                    {
                        _15164 = _15151;
                    }
                    _23744 = _15164 ? _16940 : _23198;
                    bool2 _23745 = _15164.xx;
                    _23746 = float2(_23745.x ? _23188.x : _21772.x, _23745.y ? _23188.y : _21772.y);
                    _23747 = _15164 ? _23190 : _21771;
                }
                float2 _16942[3];
                _16942[0] = _5397;
                float2 _21800;
                do
                {
                    bool _21781;
                    do
                    {
                        bool _17185 = all(bool2(_15179.x > 0.0f.xx.x, _15179.y > 0.0f.xx.y));
                        bool _17191;
                        if (_17185)
                        {
                            _17191 = all(bool2(_15179.x < 1.0f.xx.x, _15179.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17191 = _17185;
                        }
                        if (!_17191)
                        {
                            _21781 = false;
                            break;
                        }
                        uint _17198_dummy_parameter;
                        float4x4 _21779;
                        do
                        {
                            float4x4 _17212;
                            bool _21778;
                            do
                            {
                                _17212 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14775)
                                {
                                    _21778 = false;
                                    break;
                                }
                                uint _17246 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17246 + 32u) * 4 + 0) != 1u)
                                {
                                    _21778 = false;
                                    break;
                                }
                                uint _21775;
                                _21775 = 0u;
                                for (; _21775 < 4u; _21775++)
                                {
                                    for (uint _21776 = 0u; _21776 < 4u; )
                                    {
                                        _17212[_21775][_21776] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17246 + (_21775 * 4u)) + _21776) * 4 + 0));
                                        _21776++;
                                        continue;
                                    }
                                }
                                _21778 = true;
                                break;
                            } while(false);
                            if (_21778)
                            {
                                _21779 = _17212;
                                break;
                            }
                            _21779 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21780;
                        do
                        {
                            float _17323 = _15179.x;
                            float _17326 = 1.0f - _15179.y;
                            float4 _17337 = mul(float4((float2(_17323, _17326) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15179 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17198_dummy_parameter))))), 0)).x, 1.0f), _21779);
                            float _17339 = _17337.w;
                            if (!(_17339 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21780 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17352 = ((_17337.xy / _17339.xx) + 1.0f.xx) * 0.5f;
                            _21780 = float2(_17352.x - _17323, _17326 - _17352.y);
                            break;
                        } while(false);
                        float2 _17149 = abs(_21780);
                        if (any(bool2(_17149.x > 100000.0f.xx.x, _17149.y > 100000.0f.xx.y)))
                        {
                            _21781 = false;
                            break;
                        }
                        float _17157 = length(_21780 * _7084);
                        uint _17372_dummy_parameter;
                        bool _17171 = _17157 > ((8.0f * _7084.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17178;
                        if (_17171)
                        {
                            _17178 = length((r_motion_tp1.Load(int3(int2(floor(_15179 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17372_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7084) < (0.20000000298023223876953125f * _17157);
                        }
                        else
                        {
                            _17178 = _17171;
                        }
                        _21781 = _17178;
                        break;
                    } while(false);
                    if (_21781)
                    {
                        uint _17403_dummy_parameter;
                        _21800 = -(r_motion_tp1.Load(int3(int2(floor(_15179 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17403_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17430_dummy_parameter;
                    float4x4 _21794;
                    do
                    {
                        float4x4 _17444;
                        bool _21793;
                        do
                        {
                            _17444 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14775)
                            {
                                _21793 = false;
                                break;
                            }
                            uint _17478 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_17478 + 32u) * 4 + 0) != 1u)
                            {
                                _21793 = false;
                                break;
                            }
                            uint _21790;
                            _21790 = 0u;
                            for (; _21790 < 4u; _21790++)
                            {
                                for (uint _21791 = 0u; _21791 < 4u; )
                                {
                                    _17444[_21790][_21791] = asfloat(rw_nfru_diagnostics.Load<uint>((((_17478 + 16u) + (_21790 * 4u)) + _21791) * 4 + 0));
                                    _21791++;
                                    continue;
                                }
                            }
                            _21793 = true;
                            break;
                        } while(false);
                        if (_21793)
                        {
                            _21794 = _17444;
                            break;
                        }
                        _21794 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _21799;
                    do
                    {
                        float _17555 = _15179.x;
                        float _17558 = 1.0f - _15179.y;
                        float4 _17569 = mul(float4((float2(_17555, _17558) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15179 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17430_dummy_parameter))))), 0)).x, 1.0f), _21794);
                        float _17571 = _17569.w;
                        if (!(_17571 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21799 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17584 = ((_17569.xy / _17571.xx) + 1.0f.xx) * 0.5f;
                        _21799 = float2(_17584.x - _17555, _17558 - _17584.y);
                        break;
                    } while(false);
                    float2 _17116 = abs(_21799);
                    bool2 _17120 = any(bool2(_17116.x > 4.0f.xx.x, _17116.y > 4.0f.xx.y)).xx;
                    _21800 = float2(_17120.x ? 0.0f.xx.x : _21799.x, _17120.y ? 0.0f.xx.y : _21799.y);
                    break;
                } while(false);
                _16942[1] = _5397 - (_21800 * cbFI_Timestep);
                _16942[2] = _5397 - (float2(_23742.x ? 0.0f.xx.x : _21761.x, _23742.y ? 0.0f.xx.y : _21761.y) * cbFI_Timestep);
                float _21802;
                float2 _21803;
                _21803 = _5397;
                _21802 = 1000000000.0f;
                float _23748;
                float2 _23750;
                float _23751;
                float4x4 _17828;
                float4x4 _18060;
                float4x4 _18372;
                float4x4 _18604;
                int _21801 = 0;
                float _23100 = -1.0f;
                for (; _21801 < 3; _23100 = _23748, _21803 = _23750, _21802 = _23751, _21801++)
                {
                    float2 _23033;
                    _23033 = _16942[_21801];
                    float2 _17638;
                    for (int _23032 = 0; _23032 < 30; _23033 = _17638, _23032++)
                    {
                        float2 _23158;
                        do
                        {
                            float2 _17717 = clamp(_23033, 0.0f.xx, 1.0f.xx);
                            bool _23139;
                            do
                            {
                                bool _17801 = all(bool2(_17717.x > 0.0f.xx.x, _17717.y > 0.0f.xx.y));
                                bool _17807;
                                if (_17801)
                                {
                                    _17807 = all(bool2(_17717.x < 1.0f.xx.x, _17717.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17807 = _17801;
                                }
                                if (!_17807)
                                {
                                    _23139 = false;
                                    break;
                                }
                                uint _17814_dummy_parameter;
                                float4x4 _23137;
                                do
                                {
                                    bool _23136;
                                    do
                                    {
                                        _17828 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14775)
                                        {
                                            _23136 = false;
                                            break;
                                        }
                                        uint _17862 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17862 + 32u) * 4 + 0) != 1u)
                                        {
                                            _23136 = false;
                                            break;
                                        }
                                        uint _23133;
                                        _23133 = 0u;
                                        for (; _23133 < 4u; _23133++)
                                        {
                                            for (uint _23134 = 0u; _23134 < 4u; )
                                            {
                                                _17828[_23133][_23134] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17862 + (_23133 * 4u)) + _23134) * 4 + 0));
                                                _23134++;
                                                continue;
                                            }
                                        }
                                        _23136 = true;
                                        break;
                                    } while(false);
                                    if (_23136)
                                    {
                                        _23137 = _17828;
                                        break;
                                    }
                                    _23137 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _23138;
                                do
                                {
                                    float _17939 = _17717.x;
                                    float _17942 = 1.0f - _17717.y;
                                    float4 _17953 = mul(float4((float2(_17939, _17942) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17717 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17814_dummy_parameter))))), 0)).x, 1.0f), _23137);
                                    float _17955 = _17953.w;
                                    if (!(_17955 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _23138 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _17968 = ((_17953.xy / _17955.xx) + 1.0f.xx) * 0.5f;
                                    _23138 = float2(_17968.x - _17939, _17942 - _17968.y);
                                    break;
                                } while(false);
                                float2 _17765 = abs(_23138);
                                if (any(bool2(_17765.x > 100000.0f.xx.x, _17765.y > 100000.0f.xx.y)))
                                {
                                    _23139 = false;
                                    break;
                                }
                                float _17773 = length(_23138 * _7084);
                                uint _17988_dummy_parameter;
                                bool _17787 = _17773 > ((8.0f * _7084.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17794;
                                if (_17787)
                                {
                                    _17794 = length((r_motion_tp1.Load(int3(int2(floor(_17717 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17988_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7084) < (0.20000000298023223876953125f * _17773);
                                }
                                else
                                {
                                    _17794 = _17787;
                                }
                                _23139 = _17794;
                                break;
                            } while(false);
                            if (_23139)
                            {
                                uint _18019_dummy_parameter;
                                _23158 = -(r_motion_tp1.Load(int3(int2(floor(_17717 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18019_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _18046_dummy_parameter;
                            float4x4 _23152;
                            do
                            {
                                bool _23151;
                                do
                                {
                                    _18060 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14775)
                                    {
                                        _23151 = false;
                                        break;
                                    }
                                    uint _18094 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18094 + 32u) * 4 + 0) != 1u)
                                    {
                                        _23151 = false;
                                        break;
                                    }
                                    uint _23148;
                                    _23148 = 0u;
                                    for (; _23148 < 4u; _23148++)
                                    {
                                        for (uint _23149 = 0u; _23149 < 4u; )
                                        {
                                            _18060[_23148][_23149] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18094 + 16u) + (_23148 * 4u)) + _23149) * 4 + 0));
                                            _23149++;
                                            continue;
                                        }
                                    }
                                    _23151 = true;
                                    break;
                                } while(false);
                                if (_23151)
                                {
                                    _23152 = _18060;
                                    break;
                                }
                                _23152 = cbFI_MotionTM1ToTP1;
                                break;
                            } while(false);
                            float2 _23157;
                            do
                            {
                                float _18171 = _17717.x;
                                float _18174 = 1.0f - _17717.y;
                                float4 _18185 = mul(float4((float2(_18171, _18174) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17717 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18046_dummy_parameter))))), 0)).x, 1.0f), _23152);
                                float _18187 = _18185.w;
                                if (!(_18187 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _23157 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18200 = ((_18185.xy / _18187.xx) + 1.0f.xx) * 0.5f;
                                _23157 = float2(_18200.x - _18171, _18174 - _18200.y);
                                break;
                            } while(false);
                            float2 _17732 = abs(_23157);
                            bool2 _17736 = any(bool2(_17732.x > 4.0f.xx.x, _17732.y > 4.0f.xx.y)).xx;
                            _23158 = float2(_17736.x ? 0.0f.xx.x : _23157.x, _17736.y ? 0.0f.xx.y : _23157.y);
                            break;
                        } while(false);
                        _17638 = _23033 + (((_5397 - (_23158 * cbFI_Timestep)) - _23033) * 0.699999988079071044921875f);
                    }
                    float2 _18261;
                    float2 _23059;
                    do
                    {
                        _18261 = clamp(_23033, 0.0f.xx, 1.0f.xx);
                        bool _23040;
                        do
                        {
                            bool _18345 = all(bool2(_18261.x > 0.0f.xx.x, _18261.y > 0.0f.xx.y));
                            bool _18351;
                            if (_18345)
                            {
                                _18351 = all(bool2(_18261.x < 1.0f.xx.x, _18261.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18351 = _18345;
                            }
                            if (!_18351)
                            {
                                _23040 = false;
                                break;
                            }
                            uint _18358_dummy_parameter;
                            float4x4 _23038;
                            do
                            {
                                bool _23037;
                                do
                                {
                                    _18372 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14775)
                                    {
                                        _23037 = false;
                                        break;
                                    }
                                    uint _18406 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18406 + 32u) * 4 + 0) != 1u)
                                    {
                                        _23037 = false;
                                        break;
                                    }
                                    uint _23034;
                                    _23034 = 0u;
                                    for (; _23034 < 4u; _23034++)
                                    {
                                        for (uint _23035 = 0u; _23035 < 4u; )
                                        {
                                            _18372[_23034][_23035] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18406 + (_23034 * 4u)) + _23035) * 4 + 0));
                                            _23035++;
                                            continue;
                                        }
                                    }
                                    _23037 = true;
                                    break;
                                } while(false);
                                if (_23037)
                                {
                                    _23038 = _18372;
                                    break;
                                }
                                _23038 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _23039;
                            do
                            {
                                float _18486 = 1.0f - _18261.y;
                                float4 _18497 = mul(float4((float2(_18261.x, _18486) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18261 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18358_dummy_parameter))))), 0)).x, 1.0f), _23038);
                                float _18499 = _18497.w;
                                if (!(_18499 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _23039 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18512 = ((_18497.xy / _18499.xx) + 1.0f.xx) * 0.5f;
                                _23039 = float2(_18512.x - _18261.x, _18486 - _18512.y);
                                break;
                            } while(false);
                            float2 _18309 = abs(_23039);
                            if (any(bool2(_18309.x > 100000.0f.xx.x, _18309.y > 100000.0f.xx.y)))
                            {
                                _23040 = false;
                                break;
                            }
                            float _18317 = length(_23039 * _7084);
                            uint _18532_dummy_parameter;
                            bool _18331 = _18317 > ((8.0f * _7084.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18338;
                            if (_18331)
                            {
                                _18338 = length((r_motion_tp1.Load(int3(int2(floor(_18261 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18532_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7084) < (0.20000000298023223876953125f * _18317);
                            }
                            else
                            {
                                _18338 = _18331;
                            }
                            _23040 = _18338;
                            break;
                        } while(false);
                        if (_23040)
                        {
                            uint _18563_dummy_parameter;
                            _23059 = -(r_motion_tp1.Load(int3(int2(floor(_18261 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18563_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18590_dummy_parameter;
                        float4x4 _23053;
                        do
                        {
                            bool _23052;
                            do
                            {
                                _18604 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14775)
                                {
                                    _23052 = false;
                                    break;
                                }
                                uint _18638 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_18638 + 32u) * 4 + 0) != 1u)
                                {
                                    _23052 = false;
                                    break;
                                }
                                uint _23049;
                                _23049 = 0u;
                                for (; _23049 < 4u; _23049++)
                                {
                                    for (uint _23050 = 0u; _23050 < 4u; )
                                    {
                                        _18604[_23049][_23050] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18638 + 16u) + (_23049 * 4u)) + _23050) * 4 + 0));
                                        _23050++;
                                        continue;
                                    }
                                }
                                _23052 = true;
                                break;
                            } while(false);
                            if (_23052)
                            {
                                _23053 = _18604;
                                break;
                            }
                            _23053 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float2 _23058;
                        do
                        {
                            float _18718 = 1.0f - _18261.y;
                            float4 _18729 = mul(float4((float2(_18261.x, _18718) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18261 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18590_dummy_parameter))))), 0)).x, 1.0f), _23053);
                            float _18731 = _18729.w;
                            if (!(_18731 > 9.9999999747524270787835121154785e-07f))
                            {
                                _23058 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18744 = ((_18729.xy / _18731.xx) + 1.0f.xx) * 0.5f;
                            _23058 = float2(_18744.x - _18261.x, _18718 - _18744.y);
                            break;
                        } while(false);
                        float2 _18276 = abs(_23058);
                        bool2 _18280 = any(bool2(_18276.x > 4.0f.xx.x, _18276.y > 4.0f.xx.y)).xx;
                        _23059 = float2(_18280.x ? 0.0f.xx.x : _23058.x, _18280.y ? 0.0f.xx.y : _23058.y);
                        break;
                    } while(false);
                    bool _18762 = all(bool2(_23033.x > 0.0f.xx.x, _23033.y > 0.0f.xx.y));
                    bool _18768;
                    if (_18762)
                    {
                        _18768 = all(bool2(_23033.x < 1.0f.xx.x, _23033.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18768 = _18762;
                    }
                    float _23075;
                    if (_18768)
                    {
                        _23075 = length(((_23033 + (_23059 * cbFI_Timestep)) - _5397) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _23075 = 1000000000.0f;
                    }
                    uint _18795_dummy_parameter;
                    float _18819 = log(((r_depth_tm1.Load(int3(int2(floor(_18261 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18795_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _17018 = _23075 < 0.3499999940395355224609375f;
                    bool _17020 = _21802 < 0.3499999940395355224609375f;
                    bool _17030;
                    if (_17018)
                    {
                        _17030 = (!_17020) || (_18819 > _23100);
                    }
                    else
                    {
                        _17030 = _17018;
                    }
                    bool _17043;
                    if (!_17030)
                    {
                        _17043 = ((!_17018) && (!_17020)) && (_23075 < _21802);
                    }
                    else
                    {
                        _17043 = _17030;
                    }
                    _23748 = _17043 ? _18819 : _23100;
                    bool2 _23749 = _17043.xx;
                    _23750 = float2(_23749.x ? _23033.x : _21803.x, _23749.y ? _23033.y : _21803.y);
                    _23751 = _17043 ? _23075 : _21802;
                }
                float3 _18828 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21772, 0.0f).xyz;
                float3 _18836 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21803, 0.0f).xyz;
                uint _18843_dummy_parameter;
                uint _18874_dummy_parameter;
                float _14636 = exp((_21771 * (-2.0f)) * (_21771 * 2.0f));
                float _14643 = exp((_21802 * (-2.0f)) * (_21802 * 2.0f));
                float _14656 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21803, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18874_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21772, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18843_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14670 = ((_14636 * cbFI_Timestep) * ((1.0f - _14643) + ((_14643 * 2.0f) * _14656))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14680 = 1.0f - _14656;
                float _14687 = ((_14643 * _5622) * ((1.0f - _14636) + ((_14636 * 2.0f) * _14680))) + (9.9999997473787516355514526367188e-05f * _5622);
                float _14696 = (((_14636 * _14643) * 4.0f) * _14656) * _14680;
                _14714 = (_14696 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18836 - _18828, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14696)) * max(_14636, _14643));
                if (_6770 == 30u)
                {
                    _21804 = _18828;
                    break;
                }
                if (_6770 == 31u)
                {
                    _21804 = _18836;
                    break;
                }
                if (_6770 == 32u)
                {
                    _21804 = float3(_14636, _14643, _14656);
                    break;
                }
                _21804 = ((_18828 * _14670) + (_18836 * _14687)) / (_14670 + _14687).xxx;
                break;
            } while(false);
            _23012 = _14714;
            _22936 = _21804;
        }
        else
        {
            _23012 = 1.0f;
            _22936 = _22937;
        }
        uint _7100 = cbFI_pad0 & 255u;
        bool _22780;
        float3 _22935;
        if (_7100 != 0u)
        {
            float3 _7105 = r_present_backbuffer.Load(int3(_4885, 0)).xyz;
            float3 _7109 = r_current_interpolation_source.Load(int3(_4885, 0)).xyz;
            float3 _7113 = abs(_7105 - _7109);
            float3 _21805;
            if (_7100 == 2u)
            {
                _21805 = (abs(_7109) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21805 = 0.000244140625f.xxx;
            }
            bool _7129 = any(bool3(_7113.x > _21805.x, _7113.y > _21805.y, _7113.z > _21805.z));
            bool3 _23752 = _7129.xxx;
            _22935 = float3(_23752.x ? _7105.x : _22936.x, _23752.y ? _7105.y : _22936.y, _23752.z ? _7105.z : _22936.z);
            _22780 = _7129;
        }
        else
        {
            _22935 = _22936;
            _22780 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18912;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18912);
        }
        float3 _22917;
        if (_6770 == 1u)
        {
            _22917 = lerp(_8626, _8634, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22918;
            if (_6770 == 2u)
            {
                _22918 = lerp(_8642, _8650, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22919;
                if (_6770 == 3u)
                {
                    _22919 = float(_22780).xxx;
                }
                else
                {
                    float3 _22920;
                    if (_6770 == 4u)
                    {
                        _22920 = float3(((_19832 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22921;
                        if (_6770 == 5u)
                        {
                            _22921 = float3(((_7921 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22922;
                            if (_6770 == 6u)
                            {
                                _22922 = float3(_21338.xy, _21338.z + _21338.w);
                            }
                            else
                            {
                                float3 _22923;
                                if (_6770 == 7u)
                                {
                                    _22923 = r_current_interpolation_source.Load(int3(_4885, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22924;
                                    if (_6770 == 8u)
                                    {
                                        _22924 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5397, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22925;
                                        if (_6774)
                                        {
                                            uint _18934_dummy_parameter;
                                            uint _18966_dummy_parameter;
                                            _22925 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_5397 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18934_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_5397 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18966_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22926;
                                            if (_6777)
                                            {
                                                _22926 = _8642;
                                            }
                                            else
                                            {
                                                float3 _22927;
                                                if (_6770 == 20u)
                                                {
                                                    _22927 = _8626;
                                                }
                                                else
                                                {
                                                    float3 _22928;
                                                    if (_6770 == 21u)
                                                    {
                                                        _22928 = _8634;
                                                    }
                                                    else
                                                    {
                                                        float3 _22929;
                                                        if (_6770 == 22u)
                                                        {
                                                            _22929 = _8650;
                                                        }
                                                        else
                                                        {
                                                            float3 _22930;
                                                            if (_6770 == 18u)
                                                            {
                                                                _22930 = _22339;
                                                            }
                                                            else
                                                            {
                                                                float3 _22931;
                                                                if (_6770 == 19u)
                                                                {
                                                                    _22931 = _22073;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22932;
                                                                    if (_6770 == 23u)
                                                                    {
                                                                        _22932 = _21813;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22933;
                                                                        if (_6770 == 24u)
                                                                        {
                                                                            uint _7273 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7278 = float(rw_nfru_diagnostics.Load<uint>((_7273 + 35u) * 4 + 0));
                                                                            float _21806;
                                                                            if (_7278 > 0.0f)
                                                                            {
                                                                                _21806 = float(rw_nfru_diagnostics.Load<uint>((_7273 + 34u) * 4 + 0)) / _7278;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21806 = 0.0f;
                                                                            }
                                                                            _22933 = float3(float(rw_nfru_diagnostics.Load<uint>((_7273 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7273 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21806);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22933 = _22935;
                                                                        }
                                                                        _22932 = _22933;
                                                                    }
                                                                    _22931 = _22932;
                                                                }
                                                                _22930 = _22931;
                                                            }
                                                            _22929 = _22930;
                                                        }
                                                        _22928 = _22929;
                                                    }
                                                    _22927 = _22928;
                                                }
                                                _22926 = _22927;
                                            }
                                            _22925 = _22926;
                                        }
                                        _22924 = _22925;
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
        float3 _22916;
        if ((_6770 >= 9u) && (_6770 <= 11u))
        {
            uint _7338 = 64u + uint((_20055.y * cbFI_MvDepthLaneSize.x) + _20055.x);
            uint _7342 = rw_nfru_diagnostics.Load<uint>(_7338 * 4 + 0) & 15u;
            float3 _22950;
            if (_6770 == 10u)
            {
                float3 _22915;
                if ((rw_nfru_diagnostics.Load<uint>(_7338 * 4 + 0) & 32u) != 0u)
                {
                    _22915 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22914;
                    if ((rw_nfru_diagnostics.Load<uint>(_7338 * 4 + 0) & 16u) != 0u)
                    {
                        _22914 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7363 = ((rw_nfru_diagnostics.Load<uint>(_7338 * 4 + 0) & 64u) != 0u).xxx;
                        _22914 = float3(_7363.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7363.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7363.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22915 = _22914;
                }
                _22950 = _22915;
            }
            else
            {
                float3 _22951;
                if (_6770 == 11u)
                {
                    uint _7376 = (rw_nfru_diagnostics.Load<uint>(_7338 * 4 + 0) >> 8u) & 15u;
                    uint _7379 = (rw_nfru_diagnostics.Load<uint>(_7338 * 4 + 0) >> 12u) & 15u;
                    float3 _22907;
                    if ((_7342 == 2u) || (_7342 == 3u))
                    {
                        _22907 = _4567[_7342];
                    }
                    else
                    {
                        bool _7391 = _7376 == 3u;
                        bool _7393 = _7379 == 3u;
                        float3 _22908;
                        if (_7391 && _7393)
                        {
                            _22908 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22909;
                            if (_7391)
                            {
                                _22909 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22910;
                                if (_7393)
                                {
                                    _22910 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22911;
                                    if ((_7376 == 4u) || (_7379 == 4u))
                                    {
                                        _22911 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22912;
                                        if ((_7376 == 1u) || (_7379 == 1u))
                                        {
                                            _22912 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23754 = (_7342 == 1u).xxx;
                                            _22912 = float3(_23754.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23754.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23754.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22911 = _22912;
                                    }
                                    _22910 = _22911;
                                }
                                _22909 = _22910;
                            }
                            _22908 = _22909;
                        }
                        _22907 = _22908;
                    }
                    _22951 = _22907;
                }
                else
                {
                    _22951 = _4567[min(_7342, 7u)];
                }
                _22950 = _22951;
            }
            _22916 = _22950;
        }
        else
        {
            _22916 = _22917;
        }
        float4 _22954;
        if ((_6770 >= 14u) && (_6770 <= 16u))
        {
            float2 _22952;
            if (_6770 == 14u)
            {
                uint _7449_dummy_parameter;
                uint _7455_dummy_parameter;
                _22952 = r_flow_tm1.Load(int3(clamp(int2(floor(_5397 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7449_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7455_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22953;
                if (_6770 == 16u)
                {
                    uint _19042 = r_warped_flow_qdata_tm1.Load(int3(_5413, 0)).x & 2147483647u;
                    uint _19074 = uint(max((int((_19042 >> 16u) & 15u) - 6), 0));
                    _22953 = ((float2(float((1 - (2 * int((_19042 >> 15u) & 1u))) * int(((_19042 >> uint(7)) & 127u) << _19074)), float((1 - (2 * int((_19042 >> 14u) & 1u))) * int((_19042 & 127u) << _19074))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22953 = _7921 * float2(cbFI_DisplaySize);
                }
                _22952 = _22953;
            }
            uint2 _7488 = uint2(clamp(round(_22952 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7490 = _7488.x;
            uint _7497 = _7488.y;
            _22954 = float4(float(_7490 & 255u), float((_7490 >> 8u) | ((_7497 & 15u) << 4u)), float(_7497 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22955;
            if (_6770 == 17u)
            {
                _22955 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5413, 0)).x != 0u), _5857, 0.0f, 1.0f);
            }
            else
            {
                _22955 = float4(_22916, 1.0f);
            }
            _22954 = _22955;
        }
        rw_output[_4885] = _22954.xyz;
        if (_7080)
        {
            uint _19119 = uint((_4885.y * cbFI_DisplaySize.x) + _4885.x) * 2u;
            rw_nfru_select.Store<uint>(_19119 * 4 + 0, spvPackHalf2x16(_22954.xy));
            rw_nfru_select.Store<uint>((_19119 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22954.z, (_22780 || (_6770 != 0u)) ? 2.0f : _23012)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7555 = ((uint(_4885.y) * uint(cbFI_DisplaySize.x)) + uint(_4885.x)) * 6u;
            uint _19145 = spvPackHalf2x16(clamp(_8625.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7555 * 4 + 0, (((_19145 & 32767u) >> 4u) | ((((_19145 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8625.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19180 = spvPackHalf2x16(clamp(_8633.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7555 + 1u) * 4 + 0, (((_19180 & 32767u) >> 4u) | ((((_19180 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8633.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19215 = spvPackHalf2x16(clamp(_8641.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7555 + 2u) * 4 + 0, (((_19215 & 32767u) >> 4u) | ((((_19215 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8641.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19250 = spvPackHalf2x16(clamp(_8649.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7555 + 3u) * 4 + 0, (((_19250 & 32767u) >> 4u) | ((((_19250 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8649.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19277 = r_current_interpolation_source.Load(int3(_4885, 0));
            uint _19291 = spvPackHalf2x16(clamp(_19277.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7555 + 4u) * 4 + 0, (((_19291 & 32767u) >> 4u) | ((((_19291 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19277.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _23031;
            if (_22780 || (_6770 != 0u))
            {
                _23031 = 4294967295u;
            }
            else
            {
                uint _19326 = spvPackHalf2x16(clamp(_22954.xy, 0.0f.xx, 65000.0f.xx));
                _23031 = (((_19326 & 32767u) >> 4u) | ((((_19326 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22954.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7555 + 5u) * 4 + 0, _23031);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4885] = float4(r_current_interpolation_source.Load(int3(_4885, 0)).xyz, 1.0f).xyz;
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
