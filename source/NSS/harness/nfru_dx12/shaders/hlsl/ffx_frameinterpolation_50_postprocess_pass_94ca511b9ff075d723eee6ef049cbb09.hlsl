static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19740;

static const int2 _1247[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1256[5] = { 2, 4, 7, 11, 16 };
static const float3 _4538[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4856 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4856.x >= cbFI_DisplaySize.x, _4856.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4856] = float4(r_present_backbuffer.Load(int3(_4856, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4856] = float4(r_current_interpolation_source.Load(int3(_4856, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7736 = cbFI_DisplaySize - int2(1, 1);
                int2 _7737 = clamp(_4856, int2(0, 0), _7736);
                uint _7747 = uint((_7737.y * cbFI_DisplaySize.x) + _7737.x) * 2u;
                uint _7750 = rw_nfru_select.Load<uint>(_7747 * 4 + 0);
                float2 _7751 = spvUnpackHalf2x16(_7750);
                uint _7755 = rw_nfru_select.Load<uint>((_7747 + 1u) * 4 + 0);
                float2 _7756 = spvUnpackHalf2x16(_7755);
                float _7757 = _7751.x;
                float _7759 = _7756.x;
                if (_7756.y > 1.5f)
                {
                    rw_output[_4856] = float4(_7757, _7751.y, _7759, 1.0f).xyz;
                    break;
                }
                int _23170;
                float _23171;
                float3 _23172;
                float _23173;
                float _23174;
                _23174 = 0.0f;
                _23173 = 0.0f;
                _23172 = 0.0f.xxx;
                _23171 = 0.0f;
                _23170 = -2;
                float3 _23177;
                float _23178;
                float _23179;
                float _23180;
                for (; _23170 <= 2; _23174 = _23180, _23173 = _23179, _23172 = _23177, _23171 = _23178, _23170++)
                {
                    _23180 = _23174;
                    _23179 = _23173;
                    _23178 = _23171;
                    _23177 = _23172;
                    for (int _23175 = -2; _23175 <= 2; )
                    {
                        float _7653 = float((_23175 * _23175) + (_23170 * _23170));
                        float _7658 = exp(_7653 * (-0.319999992847442626953125f));
                        int2 _7663 = int2(_23175, _23170);
                        int2 _7773 = clamp(_4856 + (_7663 * int2(2, 2)), int2(0, 0), _7736);
                        uint _7783 = uint((_7773.y * cbFI_DisplaySize.x) + _7773.x) * 2u;
                        float _7680 = exp(_7653 * (-0.5f));
                        int2 _7805 = clamp(_4856 + (_7663 * int2(6, 6)), int2(0, 0), _7736);
                        _23180 += _7680;
                        _23179 += (_7680 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7805.y * cbFI_DisplaySize.x) + _7805.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23178 += _7658;
                        _23177 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7783 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7783 + 1u) * 4 + 0)).x, _19740).xyz * _7658);
                        _23175++;
                        continue;
                    }
                }
                float3 _7710 = _23172 / _23171.xxx;
                rw_output[_4856] = float4(_7710 + ((float4(_7757, _7751.y, _7759, _7756.y).xyz - _7710) * clamp(_23173 / _23174, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5362 = (float2(_4856) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5364 = float2(cbFI_MvDepthLaneSize);
        int2 _5373 = int2(floor(_5362 * _5364));
        int2 _5378 = int2(floor(_5362 * float2(cbFI_FlowLaneSize)));
        float4 _7876 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5362 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7882 = r_warped_filled_flow_tm1.Load(int3(_5378, 0)).xy;
        float2 _7888 = r_warped_filled_motion_tp1.Load(int3(_5373, 0)).xy;
        bool _7910 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19741;
        if (_7910)
        {
            float _7923 = ((2.0f * _5362.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19741 = float2(atan(_7923) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5362.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7923 * _7923))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19741 = _5362;
        }
        bool _5399 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19762;
        bool _19904;
        int2 _19985;
        float3 _22266;
        if (_5399)
        {
            float _19743;
            float _19745;
            _19745 = 2.0f;
            _19743 = -1.0f;
            uint _4950[9];
            float _23181;
            float _23184;
            for (int _19742 = 0; _19742 < 9; _19745 = _23184, _19743 = _23181, _19742++)
            {
                _4950[_19742] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5373 + int2((_19742 % 3) - 1, (_19742 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4950[_19742] != 0u)
                {
                    float _23165;
                    if (_4950[_19742] == 0u)
                    {
                        _23165 = -1.0f;
                    }
                    else
                    {
                        _23165 = float((_4950[_19742] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23184 = min(_19745, _23165);
                    _23181 = max(_19743, _23165);
                }
                else
                {
                    _23184 = _19745;
                    _23181 = _19743;
                }
            }
            float _5445 = float(_19743 >= 0.0f);
            float3 _19308 = 0.0f.xxx;
            _19308.y = _5445;
            float2 _19763;
            bool _19905;
            int2 _19986;
            float3 _22267;
            if ((_19743 - _19745) > 0.0199999995529651641845703125f)
            {
                float _19751;
                int2 _19752;
                float2 _19753;
                int2 _19755;
                float2 _19761;
                _19761 = _7888;
                _19755 = _5373;
                _19753 = _7888;
                _19752 = _5373;
                _19751 = -1.0f;
                float _23189;
                int2 _23193;
                float2 _23204;
                int2 _23215;
                float2 _23248;
                float _23633;
                int _19750 = 0;
                float _23146 = 1000000000.0f;
                for (; _19750 < 9; _23146 = _23633, _19761 = _23248, _19755 = _23215, _19753 = _23204, _19752 = _23193, _19751 = _23189, _19750++)
                {
                    if (_4950[_19750] == 0u)
                    {
                        _23633 = _23146;
                        _23248 = _19761;
                        _23215 = _19755;
                        _23204 = _19753;
                        _23193 = _19752;
                        _23189 = _19751;
                        continue;
                    }
                    int2 _5480 = clamp(_5373 + int2((_19750 % 3) - 1, (_19750 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _7998 = _4950[_19750] & 2147483647u;
                    uint _8030 = uint(max((int((_7998 >> 16u) & 15u) - 6), 0));
                    float2 _5486 = (float2(float((1 - (2 * int((_7998 >> 15u) & 1u))) * int(((_7998 >> uint(7)) & 127u) << _8030)), float((1 - (2 * int((_7998 >> 14u) & 1u))) * int((_7998 & 127u) << _8030))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23132;
                    if (_4950[_19750] == 0u)
                    {
                        _23132 = -1.0f;
                    }
                    else
                    {
                        _23132 = float((_4950[_19750] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5491 = _23132 - 0.100000001490116119384765625f;
                    float2 _23133;
                    if (_7910)
                    {
                        float2 _8107 = clamp((((_19741 + (_5486 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8110 = tan(_8107.x);
                        _23133 = (float2(_8110 / cbFI_DeviceToViewDepth.z, (tan(_8107.y) * sqrt(1.0f + (_8110 * _8110))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23133 = _19741 + (_5486 * cbFI_Timestep);
                    }
                    float _5498 = cbFI_Timestep - 1.0f;
                    float2 _23134;
                    if (_7910)
                    {
                        float2 _8178 = clamp((((_19741 + (_5486 * _5498)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8181 = tan(_8178.x);
                        _23134 = (float2(_8181 / cbFI_DeviceToViewDepth.z, (tan(_8178.y) * sqrt(1.0f + (_8181 * _8181))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23134 = _19741 + (_5486 * _5498);
                    }
                    bool _8214 = all(bool2(_23133.x > 0.0f.xx.x, _23133.y > 0.0f.xx.y));
                    bool _8220;
                    if (_8214)
                    {
                        _8220 = all(bool2(_23133.x < 1.0f.xx.x, _23133.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8220 = _8214;
                    }
                    float _23137;
                    if (_8220)
                    {
                        uint _8227_dummy_parameter;
                        _23137 = max((_5491 - (log((r_depth_tm1.Load(int3(int2(floor(_23133 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8227_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23137 = 0.0f;
                    }
                    bool _8257 = all(bool2(_23134.x > 0.0f.xx.x, _23134.y > 0.0f.xx.y));
                    bool _8263;
                    if (_8257)
                    {
                        _8263 = all(bool2(_23134.x < 1.0f.xx.x, _23134.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8263 = _8257;
                    }
                    float _23138;
                    if (_8263)
                    {
                        uint _8270_dummy_parameter;
                        _23138 = _23137 + max((_5491 - (log((r_depth_tp1.Load(int3(int2(floor(_23134 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8270_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23138 = _23137;
                    }
                    float _23190;
                    int2 _23194;
                    float2 _23205;
                    int2 _23216;
                    float2 _23249;
                    float _23634;
                    if (_23138 == 0.0f)
                    {
                        bool _5533 = _5491 > _19751;
                        bool2 _23642 = _5533.xx;
                        _23634 = _23146;
                        _23249 = float2(_23642.x ? _5486.x : _19761.x, _23642.y ? _5486.y : _19761.y);
                        _23216 = int2(_23642.x ? _5480.x : _19755.x, _23642.y ? _5480.y : _19755.y);
                        _23205 = _19753;
                        _23194 = _19752;
                        _23190 = _5533 ? _5491 : _19751;
                    }
                    else
                    {
                        bool _5542 = _23138 < _23146;
                        bool2 _23638 = _5542.xx;
                        _23634 = _5542 ? _23138 : _23146;
                        _23249 = _19761;
                        _23216 = _19755;
                        _23205 = float2(_23638.x ? _5486.x : _19753.x, _23638.y ? _5486.y : _19753.y);
                        _23194 = int2(_23638.x ? _5480.x : _19752.x, _23638.y ? _5480.y : _19752.y);
                        _23190 = _19751;
                    }
                    _23633 = _23634;
                    _23248 = _23249;
                    _23215 = _23216;
                    _23204 = _23205;
                    _23193 = _23194;
                    _23189 = _23190;
                }
                bool _5554 = _19751 < 0.0f;
                bool2 _23648 = _5554.xx;
                int2 _23651 = int2(_23648.x ? _19752.x : _19755.x, _23648.y ? _19752.y : _19755.y);
                _22267 = float3(1.0f, _5445, float(any(bool2(_23651.x != _5373.x, _23651.y != _5373.y))));
                _19986 = _23651;
                _19905 = _5554 ? false : true;
                _19763 = float2(_23648.x ? _19753.x : _19761.x, _23648.y ? _19753.y : _19761.y);
            }
            else
            {
                _22267 = _19308;
                _19986 = _5373;
                _19905 = false;
                _19763 = _7888;
            }
            _22266 = _22267;
            _19985 = _19986;
            _19904 = _19905;
            _19762 = _19763;
        }
        else
        {
            _22266 = 0.0f.xxx;
            _19985 = _5373;
            _19904 = false;
            _19762 = _7888;
        }
        float2 _19764;
        if (_7910)
        {
            float2 _8335 = clamp((((_19741 + (_19762 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8338 = tan(_8335.x);
            _19764 = (float2(_8338 / cbFI_DeviceToViewDepth.z, (tan(_8335.y) * sqrt(1.0f + (_8338 * _8338))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19764 = _19741 + (_19762 * cbFI_Timestep);
        }
        float _5577 = cbFI_Timestep - 1.0f;
        float2 _19766;
        if (_7910)
        {
            float2 _8406 = clamp((((_19741 + (_19762 * _5577)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8409 = tan(_8406.x);
            _19766 = (float2(_8409 / cbFI_DeviceToViewDepth.z, (tan(_8406.y) * sqrt(1.0f + (_8409 * _8409))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19766 = _19741 + (_19762 * _5577);
        }
        float _5582 = -cbFI_Timestep;
        float2 _19767;
        if (_7910)
        {
            float2 _8477 = clamp((((_19741 + (_7882 * _5582)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8480 = tan(_8477.x);
            _19767 = (float2(_8480 / cbFI_DeviceToViewDepth.z, (tan(_8477.y) * sqrt(1.0f + (_8480 * _8480))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19767 = _19741 + (_7882 * _5582);
        }
        float _5587 = 1.0f - cbFI_Timestep;
        float2 _19768;
        if (_7910)
        {
            float2 _8548 = clamp((((_19741 + (_7882 * _5587)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8551 = tan(_8548.x);
            _19768 = (float2(_8551 / cbFI_DeviceToViewDepth.z, (tan(_8548.y) * sqrt(1.0f + (_8551 * _8551))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19768 = _19741 + (_7882 * _5587);
        }
        float4 _8586 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19764, 0.0f);
        float3 _8587 = _8586.xyz;
        float4 _8594 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19766, 0.0f);
        float3 _8595 = _8594.xyz;
        float4 _8602 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19767, 0.0f);
        float3 _8603 = _8602.xyz;
        float4 _8610 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19768, 0.0f);
        float3 _8611 = _8610.xyz;
        float4 _8625 = exp(_7876 - max(max(max(_7876.x, _7876.y), _7876.z), _7876.w).xxxx);
        float4 _8632 = _8625 / (dot(_8625, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5603 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19975;
        float _21283;
        if (_5603)
        {
            float2 _5609 = 0.5f.xx / _5364;
            float _5612 = _5609.x;
            float _5613 = -_5612;
            float _5615 = _5609.y;
            float _5616 = -_5615;
            float2 _5618 = _5362 + float2(_5613, _5616);
            float2 _5620 = float2(cbFI_DisplaySize);
            bool _19785;
            do
            {
                bool _8712 = all(bool2(_5618.x > 0.0f.xx.x, _5618.y > 0.0f.xx.y));
                bool _8718;
                if (_8712)
                {
                    _8718 = all(bool2(_5618.x < 1.0f.xx.x, _5618.y < 1.0f.xx.y));
                }
                else
                {
                    _8718 = _8712;
                }
                if (!_8718)
                {
                    _19785 = false;
                    break;
                }
                uint _8725_dummy_parameter;
                float4x4 _19783;
                do
                {
                    float4x4 _8739;
                    bool _19782;
                    do
                    {
                        _8739 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19782 = false;
                            break;
                        }
                        uint _8773 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8773 + 32u) * 4 + 0) != 1u)
                        {
                            _19782 = false;
                            break;
                        }
                        uint _19779;
                        _19779 = 0u;
                        for (; _19779 < 4u; _19779++)
                        {
                            for (uint _19780 = 0u; _19780 < 4u; )
                            {
                                _8739[_19779][_19780] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8773 + (_19779 * 4u)) + _19780) * 4 + 0));
                                _19780++;
                                continue;
                            }
                        }
                        _19782 = true;
                        break;
                    } while(false);
                    if (_19782)
                    {
                        _19783 = _8739;
                        break;
                    }
                    _19783 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19784;
                do
                {
                    float _8850 = _5618.x;
                    float _8853 = 1.0f - _5618.y;
                    float4 _8864 = mul(float4((float2(_8850, _8853) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5618 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8725_dummy_parameter))))), 0)).x, 1.0f), _19783);
                    float _8866 = _8864.w;
                    if (!(_8866 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19784 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8879 = ((_8864.xy / _8866.xx) + 1.0f.xx) * 0.5f;
                    _19784 = float2(_8879.x - _8850, _8853 - _8879.y);
                    break;
                } while(false);
                float2 _8676 = abs(_19784);
                if (any(bool2(_8676.x > 100000.0f.xx.x, _8676.y > 100000.0f.xx.y)))
                {
                    _19785 = false;
                    break;
                }
                float _8684 = length(_19784 * _5620);
                uint _8899_dummy_parameter;
                bool _8698 = _8684 > ((8.0f * _5620.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8705;
                if (_8698)
                {
                    _8705 = length((r_motion_tp1.Load(int3(int2(floor(_5618 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8899_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5620) < (0.20000000298023223876953125f * _8684);
                }
                else
                {
                    _8705 = _8698;
                }
                _19785 = _8705;
                break;
            } while(false);
            float2 _5630 = _5362 + float2(_5612, _5616);
            bool _19792;
            do
            {
                bool _8985 = all(bool2(_5630.x > 0.0f.xx.x, _5630.y > 0.0f.xx.y));
                bool _8991;
                if (_8985)
                {
                    _8991 = all(bool2(_5630.x < 1.0f.xx.x, _5630.y < 1.0f.xx.y));
                }
                else
                {
                    _8991 = _8985;
                }
                if (!_8991)
                {
                    _19792 = false;
                    break;
                }
                uint _8998_dummy_parameter;
                float4x4 _19790;
                do
                {
                    float4x4 _9012;
                    bool _19789;
                    do
                    {
                        _9012 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19789 = false;
                            break;
                        }
                        uint _9046 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9046 + 32u) * 4 + 0) != 1u)
                        {
                            _19789 = false;
                            break;
                        }
                        uint _19786;
                        _19786 = 0u;
                        for (; _19786 < 4u; _19786++)
                        {
                            for (uint _19787 = 0u; _19787 < 4u; )
                            {
                                _9012[_19786][_19787] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9046 + (_19786 * 4u)) + _19787) * 4 + 0));
                                _19787++;
                                continue;
                            }
                        }
                        _19789 = true;
                        break;
                    } while(false);
                    if (_19789)
                    {
                        _19790 = _9012;
                        break;
                    }
                    _19790 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19791;
                do
                {
                    float _9123 = _5630.x;
                    float _9126 = 1.0f - _5630.y;
                    float4 _9137 = mul(float4((float2(_9123, _9126) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5630 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8998_dummy_parameter))))), 0)).x, 1.0f), _19790);
                    float _9139 = _9137.w;
                    if (!(_9139 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19791 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9152 = ((_9137.xy / _9139.xx) + 1.0f.xx) * 0.5f;
                    _19791 = float2(_9152.x - _9123, _9126 - _9152.y);
                    break;
                } while(false);
                float2 _8949 = abs(_19791);
                if (any(bool2(_8949.x > 100000.0f.xx.x, _8949.y > 100000.0f.xx.y)))
                {
                    _19792 = false;
                    break;
                }
                float _8957 = length(_19791 * _5620);
                uint _9172_dummy_parameter;
                bool _8971 = _8957 > ((8.0f * _5620.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8978;
                if (_8971)
                {
                    _8978 = length((r_motion_tp1.Load(int3(int2(floor(_5630 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9172_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5620) < (0.20000000298023223876953125f * _8957);
                }
                else
                {
                    _8978 = _8971;
                }
                _19792 = _8978;
                break;
            } while(false);
            float2 _5643 = _5362 + float2(_5613, _5615);
            bool _19799;
            do
            {
                bool _9258 = all(bool2(_5643.x > 0.0f.xx.x, _5643.y > 0.0f.xx.y));
                bool _9264;
                if (_9258)
                {
                    _9264 = all(bool2(_5643.x < 1.0f.xx.x, _5643.y < 1.0f.xx.y));
                }
                else
                {
                    _9264 = _9258;
                }
                if (!_9264)
                {
                    _19799 = false;
                    break;
                }
                uint _9271_dummy_parameter;
                float4x4 _19797;
                do
                {
                    float4x4 _9285;
                    bool _19796;
                    do
                    {
                        _9285 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19796 = false;
                            break;
                        }
                        uint _9319 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9319 + 32u) * 4 + 0) != 1u)
                        {
                            _19796 = false;
                            break;
                        }
                        uint _19793;
                        _19793 = 0u;
                        for (; _19793 < 4u; _19793++)
                        {
                            for (uint _19794 = 0u; _19794 < 4u; )
                            {
                                _9285[_19793][_19794] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9319 + (_19793 * 4u)) + _19794) * 4 + 0));
                                _19794++;
                                continue;
                            }
                        }
                        _19796 = true;
                        break;
                    } while(false);
                    if (_19796)
                    {
                        _19797 = _9285;
                        break;
                    }
                    _19797 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19798;
                do
                {
                    float _9396 = _5643.x;
                    float _9399 = 1.0f - _5643.y;
                    float4 _9410 = mul(float4((float2(_9396, _9399) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5643 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9271_dummy_parameter))))), 0)).x, 1.0f), _19797);
                    float _9412 = _9410.w;
                    if (!(_9412 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19798 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9425 = ((_9410.xy / _9412.xx) + 1.0f.xx) * 0.5f;
                    _19798 = float2(_9425.x - _9396, _9399 - _9425.y);
                    break;
                } while(false);
                float2 _9222 = abs(_19798);
                if (any(bool2(_9222.x > 100000.0f.xx.x, _9222.y > 100000.0f.xx.y)))
                {
                    _19799 = false;
                    break;
                }
                float _9230 = length(_19798 * _5620);
                uint _9445_dummy_parameter;
                bool _9244 = _9230 > ((8.0f * _5620.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9251;
                if (_9244)
                {
                    _9251 = length((r_motion_tp1.Load(int3(int2(floor(_5643 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9445_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5620) < (0.20000000298023223876953125f * _9230);
                }
                else
                {
                    _9251 = _9244;
                }
                _19799 = _9251;
                break;
            } while(false);
            float2 _5655 = _5362 + _5609;
            bool _19806;
            do
            {
                bool _9531 = all(bool2(_5655.x > 0.0f.xx.x, _5655.y > 0.0f.xx.y));
                bool _9537;
                if (_9531)
                {
                    _9537 = all(bool2(_5655.x < 1.0f.xx.x, _5655.y < 1.0f.xx.y));
                }
                else
                {
                    _9537 = _9531;
                }
                if (!_9537)
                {
                    _19806 = false;
                    break;
                }
                uint _9544_dummy_parameter;
                float4x4 _19804;
                do
                {
                    float4x4 _9558;
                    bool _19803;
                    do
                    {
                        _9558 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19803 = false;
                            break;
                        }
                        uint _9592 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9592 + 32u) * 4 + 0) != 1u)
                        {
                            _19803 = false;
                            break;
                        }
                        uint _19800;
                        _19800 = 0u;
                        for (; _19800 < 4u; _19800++)
                        {
                            for (uint _19801 = 0u; _19801 < 4u; )
                            {
                                _9558[_19800][_19801] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9592 + (_19800 * 4u)) + _19801) * 4 + 0));
                                _19801++;
                                continue;
                            }
                        }
                        _19803 = true;
                        break;
                    } while(false);
                    if (_19803)
                    {
                        _19804 = _9558;
                        break;
                    }
                    _19804 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19805;
                do
                {
                    float _9669 = _5655.x;
                    float _9672 = 1.0f - _5655.y;
                    float4 _9683 = mul(float4((float2(_9669, _9672) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5655 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9544_dummy_parameter))))), 0)).x, 1.0f), _19804);
                    float _9685 = _9683.w;
                    if (!(_9685 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19805 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9698 = ((_9683.xy / _9685.xx) + 1.0f.xx) * 0.5f;
                    _19805 = float2(_9698.x - _9669, _9672 - _9698.y);
                    break;
                } while(false);
                float2 _9495 = abs(_19805);
                if (any(bool2(_9495.x > 100000.0f.xx.x, _9495.y > 100000.0f.xx.y)))
                {
                    _19806 = false;
                    break;
                }
                float _9503 = length(_19805 * _5620);
                uint _9718_dummy_parameter;
                bool _9517 = _9503 > ((8.0f * _5620.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9524;
                if (_9517)
                {
                    _9524 = length((r_motion_tp1.Load(int3(int2(floor(_5655 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9718_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5620) < (0.20000000298023223876953125f * _9503);
                }
                else
                {
                    _9524 = _9517;
                }
                _19806 = _9524;
                break;
            } while(false);
            float _5661 = 0.25f * (((float(_19785) + float(_19792)) + float(_19799)) + float(_19806));
            float4 _19976;
            if (_5661 < 1.0f)
            {
                bool _19813;
                do
                {
                    bool _9804 = all(bool2(_19764.x > 0.0f.xx.x, _19764.y > 0.0f.xx.y));
                    bool _9810;
                    if (_9804)
                    {
                        _9810 = all(bool2(_19764.x < 1.0f.xx.x, _19764.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9810 = _9804;
                    }
                    if (!_9810)
                    {
                        _19813 = false;
                        break;
                    }
                    uint _9817_dummy_parameter;
                    float4x4 _19811;
                    do
                    {
                        float4x4 _9831;
                        bool _19810;
                        do
                        {
                            _9831 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19810 = false;
                                break;
                            }
                            uint _9865 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9865 + 32u) * 4 + 0) != 1u)
                            {
                                _19810 = false;
                                break;
                            }
                            uint _19807;
                            _19807 = 0u;
                            for (; _19807 < 4u; _19807++)
                            {
                                for (uint _19808 = 0u; _19808 < 4u; )
                                {
                                    _9831[_19807][_19808] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9865 + (_19807 * 4u)) + _19808) * 4 + 0));
                                    _19808++;
                                    continue;
                                }
                            }
                            _19810 = true;
                            break;
                        } while(false);
                        if (_19810)
                        {
                            _19811 = _9831;
                            break;
                        }
                        _19811 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19812;
                    do
                    {
                        float _9945 = 1.0f - _19764.y;
                        float4 _9956 = mul(float4((float2(_19764.x, _9945) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19764 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9817_dummy_parameter))))), 0)).x, 1.0f), _19811);
                        float _9958 = _9956.w;
                        if (!(_9958 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19812 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9971 = ((_9956.xy / _9958.xx) + 1.0f.xx) * 0.5f;
                        _19812 = float2(_9971.x - _19764.x, _9945 - _9971.y);
                        break;
                    } while(false);
                    float2 _9768 = abs(_19812);
                    if (any(bool2(_9768.x > 100000.0f.xx.x, _9768.y > 100000.0f.xx.y)))
                    {
                        _19813 = false;
                        break;
                    }
                    float _9776 = length(_19812 * _5620);
                    uint _9991_dummy_parameter;
                    bool _9790 = _9776 > ((8.0f * _5620.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9797;
                    if (_9790)
                    {
                        _9797 = length((r_motion_tp1.Load(int3(int2(floor(_19764 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9991_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5620) < (0.20000000298023223876953125f * _9776);
                    }
                    else
                    {
                        _9797 = _9790;
                    }
                    _19813 = _9797;
                    break;
                } while(false);
                bool _19820;
                do
                {
                    bool _10077 = all(bool2(_19766.x > 0.0f.xx.x, _19766.y > 0.0f.xx.y));
                    bool _10083;
                    if (_10077)
                    {
                        _10083 = all(bool2(_19766.x < 1.0f.xx.x, _19766.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10083 = _10077;
                    }
                    if (!_10083)
                    {
                        _19820 = false;
                        break;
                    }
                    uint _10090_dummy_parameter;
                    float4x4 _19818;
                    do
                    {
                        float4x4 _10104;
                        bool _19817;
                        do
                        {
                            _10104 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19817 = false;
                                break;
                            }
                            uint _10138 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10138 + 32u) * 4 + 0) != 1u)
                            {
                                _19817 = false;
                                break;
                            }
                            uint _19814;
                            _19814 = 0u;
                            for (; _19814 < 4u; _19814++)
                            {
                                for (uint _19815 = 0u; _19815 < 4u; )
                                {
                                    _10104[_19814][_19815] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10138 + (_19814 * 4u)) + _19815) * 4 + 0));
                                    _19815++;
                                    continue;
                                }
                            }
                            _19817 = true;
                            break;
                        } while(false);
                        if (_19817)
                        {
                            _19818 = _10104;
                            break;
                        }
                        _19818 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19819;
                    do
                    {
                        float _10218 = 1.0f - _19766.y;
                        float4 _10229 = mul(float4((float2(_19766.x, _10218) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19766 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10090_dummy_parameter))))), 0)).x, 1.0f), _19818);
                        float _10231 = _10229.w;
                        if (!(_10231 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19819 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10244 = ((_10229.xy / _10231.xx) + 1.0f.xx) * 0.5f;
                        _19819 = float2(_10244.x - _19766.x, _10218 - _10244.y);
                        break;
                    } while(false);
                    float2 _10041 = abs(_19819);
                    if (any(bool2(_10041.x > 100000.0f.xx.x, _10041.y > 100000.0f.xx.y)))
                    {
                        _19820 = false;
                        break;
                    }
                    float _10049 = length(_19819 * _5620);
                    uint _10264_dummy_parameter;
                    bool _10063 = _10049 > ((8.0f * _5620.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10070;
                    if (_10063)
                    {
                        _10070 = length((r_motion_tp1.Load(int3(int2(floor(_19766 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10264_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5620) < (0.20000000298023223876953125f * _10049);
                    }
                    else
                    {
                        _10070 = _10063;
                    }
                    _19820 = _10070;
                    break;
                } while(false);
                bool _19827;
                do
                {
                    bool _10350 = all(bool2(_19767.x > 0.0f.xx.x, _19767.y > 0.0f.xx.y));
                    bool _10356;
                    if (_10350)
                    {
                        _10356 = all(bool2(_19767.x < 1.0f.xx.x, _19767.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10356 = _10350;
                    }
                    if (!_10356)
                    {
                        _19827 = false;
                        break;
                    }
                    uint _10363_dummy_parameter;
                    float4x4 _19825;
                    do
                    {
                        float4x4 _10377;
                        bool _19824;
                        do
                        {
                            _10377 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19824 = false;
                                break;
                            }
                            uint _10411 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10411 + 32u) * 4 + 0) != 1u)
                            {
                                _19824 = false;
                                break;
                            }
                            uint _19821;
                            _19821 = 0u;
                            for (; _19821 < 4u; _19821++)
                            {
                                for (uint _19822 = 0u; _19822 < 4u; )
                                {
                                    _10377[_19821][_19822] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10411 + (_19821 * 4u)) + _19822) * 4 + 0));
                                    _19822++;
                                    continue;
                                }
                            }
                            _19824 = true;
                            break;
                        } while(false);
                        if (_19824)
                        {
                            _19825 = _10377;
                            break;
                        }
                        _19825 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19826;
                    do
                    {
                        float _10491 = 1.0f - _19767.y;
                        float4 _10502 = mul(float4((float2(_19767.x, _10491) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19767 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10363_dummy_parameter))))), 0)).x, 1.0f), _19825);
                        float _10504 = _10502.w;
                        if (!(_10504 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19826 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10517 = ((_10502.xy / _10504.xx) + 1.0f.xx) * 0.5f;
                        _19826 = float2(_10517.x - _19767.x, _10491 - _10517.y);
                        break;
                    } while(false);
                    float2 _10314 = abs(_19826);
                    if (any(bool2(_10314.x > 100000.0f.xx.x, _10314.y > 100000.0f.xx.y)))
                    {
                        _19827 = false;
                        break;
                    }
                    float _10322 = length(_19826 * _5620);
                    uint _10537_dummy_parameter;
                    bool _10336 = _10322 > ((8.0f * _5620.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10343;
                    if (_10336)
                    {
                        _10343 = length((r_motion_tp1.Load(int3(int2(floor(_19767 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10537_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5620) < (0.20000000298023223876953125f * _10322);
                    }
                    else
                    {
                        _10343 = _10336;
                    }
                    _19827 = _10343;
                    break;
                } while(false);
                bool _19834;
                do
                {
                    bool _10623 = all(bool2(_19768.x > 0.0f.xx.x, _19768.y > 0.0f.xx.y));
                    bool _10629;
                    if (_10623)
                    {
                        _10629 = all(bool2(_19768.x < 1.0f.xx.x, _19768.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10629 = _10623;
                    }
                    if (!_10629)
                    {
                        _19834 = false;
                        break;
                    }
                    uint _10636_dummy_parameter;
                    float4x4 _19832;
                    do
                    {
                        float4x4 _10650;
                        bool _19831;
                        do
                        {
                            _10650 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19831 = false;
                                break;
                            }
                            uint _10684 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10684 + 32u) * 4 + 0) != 1u)
                            {
                                _19831 = false;
                                break;
                            }
                            uint _19828;
                            _19828 = 0u;
                            for (; _19828 < 4u; _19828++)
                            {
                                for (uint _19829 = 0u; _19829 < 4u; )
                                {
                                    _10650[_19828][_19829] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10684 + (_19828 * 4u)) + _19829) * 4 + 0));
                                    _19829++;
                                    continue;
                                }
                            }
                            _19831 = true;
                            break;
                        } while(false);
                        if (_19831)
                        {
                            _19832 = _10650;
                            break;
                        }
                        _19832 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19833;
                    do
                    {
                        float _10764 = 1.0f - _19768.y;
                        float4 _10775 = mul(float4((float2(_19768.x, _10764) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19768 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10636_dummy_parameter))))), 0)).x, 1.0f), _19832);
                        float _10777 = _10775.w;
                        if (!(_10777 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19833 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10790 = ((_10775.xy / _10777.xx) + 1.0f.xx) * 0.5f;
                        _19833 = float2(_10790.x - _19768.x, _10764 - _10790.y);
                        break;
                    } while(false);
                    float2 _10587 = abs(_19833);
                    if (any(bool2(_10587.x > 100000.0f.xx.x, _10587.y > 100000.0f.xx.y)))
                    {
                        _19834 = false;
                        break;
                    }
                    float _10595 = length(_19833 * _5620);
                    uint _10810_dummy_parameter;
                    bool _10609 = _10595 > ((8.0f * _5620.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10616;
                    if (_10609)
                    {
                        _10616 = length((r_motion_tp1.Load(int3(int2(floor(_19768 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10810_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5620) < (0.20000000298023223876953125f * _10595);
                    }
                    else
                    {
                        _10616 = _10609;
                    }
                    _19834 = _10616;
                    break;
                } while(false);
                float4 _5688 = _8632 * float4(_19813 ? 0.0f : 1.0f, _19820 ? 0.0f : 1.0f, _19827 ? 0.0f : 1.0f, _19834 ? 0.0f : 1.0f);
                float _5690 = dot(_5688, 1.0f.xxxx);
                float4 _19977;
                if (_5690 > 0.001000000047497451305389404296875f)
                {
                    _19977 = _5688 / _5690.xxxx;
                }
                else
                {
                    _19977 = _8632;
                }
                _19976 = _19977;
            }
            else
            {
                _19976 = _8632;
            }
            _21283 = _5661;
            _19975 = _19976;
        }
        else
        {
            _21283 = 0.0f;
            _19975 = _8632;
        }
        bool _5707 = _5399 && (!_19904);
        bool _5716;
        if (_5707)
        {
            _5716 = (_19975.z + _19975.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5716 = _5707;
        }
        bool _5727;
        if (_5716)
        {
            _5727 = length((_19767 - _19764) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5727 = _5716;
        }
        bool _20064;
        if (_5727)
        {
            uint4 _10839 = r_warped_motion_qdata_tp1.Load(int3(_19985, 0));
            uint _10840 = _10839.x;
            bool _20067;
            if (_10840 != 0u)
            {
                float _20053;
                if (_10840 == 0u)
                {
                    _20053 = -1.0f;
                }
                else
                {
                    _20053 = float((_10840 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5737 = _20053 - 0.12000000476837158203125f;
                bool _10859 = all(bool2(_19767.x > 0.0f.xx.x, _19767.y > 0.0f.xx.y));
                bool _10865;
                if (_10859)
                {
                    _10865 = all(bool2(_19767.x < 1.0f.xx.x, _19767.y < 1.0f.xx.y));
                }
                else
                {
                    _10865 = _10859;
                }
                bool _5747;
                if (_10865)
                {
                    uint _10872_dummy_parameter;
                    _5747 = (log((r_depth_tm1.Load(int3(int2(floor(_19767 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10872_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5737;
                }
                else
                {
                    _5747 = _10865;
                }
                bool _5761;
                if (!_5747)
                {
                    bool _10902 = all(bool2(_19768.x > 0.0f.xx.x, _19768.y > 0.0f.xx.y));
                    bool _10908;
                    if (_10902)
                    {
                        _10908 = all(bool2(_19768.x < 1.0f.xx.x, _19768.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10908 = _10902;
                    }
                    bool _5759;
                    if (_10908)
                    {
                        uint _10915_dummy_parameter;
                        _5759 = (log((r_depth_tp1.Load(int3(int2(floor(_19768 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10915_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5737;
                    }
                    else
                    {
                        _5759 = _10908;
                    }
                    _5761 = _5759;
                }
                else
                {
                    _5761 = _5747;
                }
                _20067 = _5761;
            }
            else
            {
                _20067 = false;
            }
            _20064 = _20067;
        }
        else
        {
            _20064 = false;
        }
        bool _5766 = _19904 || _20064;
        bool _5771;
        if (_5766)
        {
            bool _10945 = all(bool2(_19764.x > 0.0f.xx.x, _19764.y > 0.0f.xx.y));
            bool _10951;
            if (_10945)
            {
                _10951 = all(bool2(_19764.x < 1.0f.xx.x, _19764.y < 1.0f.xx.y));
            }
            else
            {
                _10951 = _10945;
            }
            _5771 = _10951;
        }
        else
        {
            _5771 = _5766;
        }
        bool _5776;
        if (_5771)
        {
            bool _10956 = all(bool2(_19766.x > 0.0f.xx.x, _19766.y > 0.0f.xx.y));
            bool _10962;
            if (_10956)
            {
                _10962 = all(bool2(_19766.x < 1.0f.xx.x, _19766.y < 1.0f.xx.y));
            }
            else
            {
                _10962 = _10956;
            }
            _5776 = _10962;
        }
        else
        {
            _5776 = _5771;
        }
        float4 _20187;
        if (_5776)
        {
            float _5782 = _19975.x + _19975.y;
            float _5787 = _19975.z + _19975.w;
            float _20082;
            if (_5782 > 0.001000000047497451305389404296875f)
            {
                _20082 = _19975.x / _5782;
            }
            else
            {
                _20082 = _5587;
            }
            _20187 = float4(_19975.x + (_5787 * _20082), _19975.y + (_5787 * (1.0f - _20082)), 0.0f, 0.0f);
        }
        else
        {
            _20187 = _19975;
        }
        bool _10990 = (cbFI_pad0 & 1024u) != 0u;
        bool _10966 = !_10990;
        bool _10967 = !_10966;
        bool _10984;
        if (_10967)
        {
            _10984 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19985.y * cbFI_MvDepthLaneSize.x) + _19985.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _10984 = _10966;
        }
        bool _11016;
        if (_10967)
        {
            _11016 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5378.y * cbFI_FlowLaneSize.x) + _5378.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11016 = _10966;
        }
        float _5822 = float(_11016);
        bool _20208;
        float4 _20247;
        float3 _22001;
        if (_10990)
        {
            bool _5832;
            if (_10984)
            {
                _5832 = all(bool2(_19764.x > 0.0f.xx.x, _19764.y > 0.0f.xx.y));
            }
            else
            {
                _5832 = _10984;
            }
            bool _5838;
            if (_5832)
            {
                _5838 = all(bool2(_19764.x < 1.0f.xx.x, _19764.y < 1.0f.xx.y));
            }
            else
            {
                _5838 = _5832;
            }
            bool _5845;
            if (_10984)
            {
                _5845 = all(bool2(_19766.x > 0.0f.xx.x, _19766.y > 0.0f.xx.y));
            }
            else
            {
                _5845 = _10984;
            }
            bool _5851;
            if (_5845)
            {
                _5851 = all(bool2(_19766.x < 1.0f.xx.x, _19766.y < 1.0f.xx.y));
            }
            else
            {
                _5851 = _5845;
            }
            bool _5858;
            if (_11016)
            {
                _5858 = all(bool2(_19767.x > 0.0f.xx.x, _19767.y > 0.0f.xx.y));
            }
            else
            {
                _5858 = _11016;
            }
            bool _5864;
            if (_5858)
            {
                _5864 = all(bool2(_19767.x < 1.0f.xx.x, _19767.y < 1.0f.xx.y));
            }
            else
            {
                _5864 = _5858;
            }
            bool _5871;
            if (_11016)
            {
                _5871 = all(bool2(_19768.x > 0.0f.xx.x, _19768.y > 0.0f.xx.y));
            }
            else
            {
                _5871 = _11016;
            }
            bool _5877;
            if (_5871)
            {
                _5877 = all(bool2(_19768.x < 1.0f.xx.x, _19768.y < 1.0f.xx.y));
            }
            else
            {
                _5877 = _5871;
            }
            bool _5879 = !_10984;
            if (_5879)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11058;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11058);
                }
            }
            bool _5884 = !_11016;
            if (_5884)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11068;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11068);
                }
            }
            if (_10984 && _5884)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11078;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11078);
                }
            }
            if (_5879 && _11016)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11088;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11088);
                }
            }
            float _5903 = float(_5838);
            float _5905 = float(_5851);
            bool _5908 = _5864 && _5877;
            float _20116;
            if (_5908)
            {
                _20116 = 1.0f;
            }
            else
            {
                _20116 = (_5864 || _5877) ? 0.5f : 0.0f;
            }
            bool _20131;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5838)) && (!_5851))
            {
                bool _5938;
                if (_5908)
                {
                    float _20124;
                    do
                    {
                        bool _11172 = all(bool2(_19767.x > 0.0f.xx.x, _19767.y > 0.0f.xx.y));
                        bool _11178;
                        if (_11172)
                        {
                            _11178 = all(bool2(_19767.x < 1.0f.xx.x, _19767.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11178 = _11172;
                        }
                        bool _11109 = !_11178;
                        bool _11116;
                        if (!_11109)
                        {
                            bool _11183 = all(bool2(_19768.x > 0.0f.xx.x, _19768.y > 0.0f.xx.y));
                            bool _11189;
                            if (_11183)
                            {
                                _11189 = all(bool2(_19768.x < 1.0f.xx.x, _19768.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11189 = _11183;
                            }
                            _11116 = !_11189;
                        }
                        else
                        {
                            _11116 = _11109;
                        }
                        if (_11116)
                        {
                            _20124 = 0.0f;
                            break;
                        }
                        uint _11196_dummy_parameter;
                        uint _11212_dummy_parameter;
                        float4x4 _20123;
                        do
                        {
                            float4x4 _11226;
                            bool _20122;
                            do
                            {
                                _11226 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20122 = false;
                                    break;
                                }
                                uint _11260 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11260 + 32u) * 4 + 0) != 1u)
                                {
                                    _20122 = false;
                                    break;
                                }
                                uint _20119;
                                _20119 = 0u;
                                for (; _20119 < 4u; _20119++)
                                {
                                    for (uint _20120 = 0u; _20120 < 4u; )
                                    {
                                        _11226[_20119][_20120] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11260 + 16u) + (_20119 * 4u)) + _20120) * 4 + 0));
                                        _20120++;
                                        continue;
                                    }
                                }
                                _20122 = true;
                                break;
                            } while(false);
                            if (_20122)
                            {
                                _20123 = _11226;
                                break;
                            }
                            _20123 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11137 = mul(float4((float2(_19767.x, 1.0f - _19767.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19767 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11196_dummy_parameter))))), 0)).x, 1.0f), _20123);
                        float _11139 = _11137.w;
                        if (abs(_11139) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20124 = 0.0f;
                            break;
                        }
                        float _11150 = abs(cbFI_DeviceToViewDepth.y / ((_11137.z / _11139) - cbFI_DeviceToViewDepth.x));
                        float _11153 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19768 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11212_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20124 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11150 - _11153) / max(max(_11150, _11153), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5938 = _20124 >= 0.5f;
                }
                else
                {
                    _5938 = _5908;
                }
                bool _5946;
                if (_5938)
                {
                    _5946 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _5946 = _5938;
                }
                bool _20132;
                if (_5946)
                {
                    uint _11364_dummy_parameter;
                    float4x4 _20129;
                    do
                    {
                        float4x4 _11378;
                        bool _20128;
                        do
                        {
                            _11378 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20128 = false;
                                break;
                            }
                            uint _11412 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11412 + 32u) * 4 + 0) != 1u)
                            {
                                _20128 = false;
                                break;
                            }
                            uint _20125;
                            _20125 = 0u;
                            for (; _20125 < 4u; _20125++)
                            {
                                for (uint _20126 = 0u; _20126 < 4u; )
                                {
                                    _11378[_20125][_20126] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11412 + 16u) + (_20125 * 4u)) + _20126) * 4 + 0));
                                    _20126++;
                                    continue;
                                }
                            }
                            _20128 = true;
                            break;
                        } while(false);
                        if (_20128)
                        {
                            _20129 = _11378;
                            break;
                        }
                        _20129 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20130;
                    do
                    {
                        float _11492 = 1.0f - _19767.y;
                        float4 _11503 = mul(float4((float2(_19767.x, _11492) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19767 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11364_dummy_parameter))))), 0)).x, 1.0f), _20129);
                        float _11505 = _11503.w;
                        if (!(_11505 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20130 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11518 = ((_11503.xy / _11505.xx) + 1.0f.xx) * 0.5f;
                        _20130 = float2(_11518.x - _19767.x, _11492 - _11518.y);
                        break;
                    } while(false);
                    float2 _5959 = float2(cbFI_DisplaySize);
                    _20132 = length(((_19767 + _20130) - _19768) * _5959) <= ((0.100000001490116119384765625f * length(_20130 * _5959)) + 8.0f);
                }
                else
                {
                    _20132 = _5938;
                }
                _20131 = _20132;
            }
            else
            {
                _20131 = true;
            }
            bool _5973 = !_20131;
            bool _23652 = _5973 ? false : _5877;
            bool _23653 = _5973 ? false : _5864;
            bool _20209;
            float4 _20248;
            if (!(((_5838 && _5851) && _23653) && _23652))
            {
                float4 _5995 = _20187 * float4(_5903, _5905, float(_23653), float(_23652));
                float _5997 = dot(_5995, 1.0f.xxxx);
                bool _6000 = !(_5997 > 0.0f);
                float4 _20249;
                if (!_6000)
                {
                    _20249 = _5995 / _5997.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11540;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11540);
                    }
                    _20249 = 0.0f.xxxx;
                }
                _20248 = _20249;
                _20209 = _6000;
            }
            else
            {
                _20248 = _20187;
                _20209 = false;
            }
            _22001 = float3(_5903, _5905, _20116);
            _20247 = _20248;
            _20208 = _20209;
        }
        else
        {
            _22001 = float3(float(_10984), _5822, 0.0f);
            _20247 = _20187;
            _20208 = false;
        }
        bool _6018 = !_20208;
        float4 _20340;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6018)
        {
            float _6025 = _20247.x + _20247.y;
            float4 _20341;
            if (_6025 > 0.001000000047497451305389404296875f)
            {
                _20341 = float4(_20247.x / _6025, _20247.y / _6025, 0.0f, 0.0f);
            }
            else
            {
                _20341 = float4(_5587, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20340 = _20341;
        }
        else
        {
            _20340 = _20247;
        }
        float4 _20517;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6018) && _10984)
        {
            float _20314;
            do
            {
                uint4 _11680 = r_warped_motion_qdata_tp1.Load(int3(_19985, 0));
                uint _11681 = _11680.x;
                if (_11681 != 0u)
                {
                    float _20313;
                    if (_11681 == 0u)
                    {
                        _20313 = -1.0f;
                    }
                    else
                    {
                        _20313 = float((_11681 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20314 = _20313;
                    break;
                }
                int _20296;
                uint _20297;
                _20297 = _11681;
                _20296 = -1;
                uint _20312;
                for (; _20296 <= 1; _20297 = _20312, _20296++)
                {
                    _20312 = _20297;
                    for (int _20310 = -1; _20310 <= 1; )
                    {
                        _20312 = max(_20312, r_warped_motion_qdata_tp1.Load(int3(clamp(_19985 + int2(_20310, _20296), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20310++;
                        continue;
                    }
                }
                if (_20297 != 0u)
                {
                    float _20309;
                    if (_20297 == 0u)
                    {
                        _20309 = -1.0f;
                    }
                    else
                    {
                        _20309 = float((_20297 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20314 = _20309;
                    break;
                }
                uint _20299;
                _20299 = 4294967295u;
                uint _23285;
                for (int _20298 = 0; _20298 < 8; _20299 = _23285, _20298++)
                {
                    int _20302 = 0;
                    for (;;)
                    {
                        if (_20302 < 5)
                        {
                            int2 _11631 = _19985 + (_1247[_20298] * _1256[_20302].xx);
                            bool _11634 = any(bool2(_11631.x < int2(0, 0).x, _11631.y < int2(0, 0).y));
                            bool _11642;
                            if (!_11634)
                            {
                                _11642 = any(bool2(_11631.x >= cbFI_MvDepthLaneSize.x, _11631.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11642 = _11634;
                            }
                            if (_11642)
                            {
                                _23285 = _20299;
                                break;
                            }
                            uint4 _11720 = r_warped_motion_qdata_tp1.Load(int3(_11631, 0));
                            uint _11721 = _11720.x;
                            if (_11721 != 0u)
                            {
                                _23285 = min(_20299, _11721);
                                break;
                            }
                            _20302++;
                            continue;
                        }
                        else
                        {
                            _23285 = _20299;
                            break;
                        }
                    }
                }
                float _20301;
                if (_20299 == 4294967295u)
                {
                    _20301 = -1.0f;
                }
                else
                {
                    float _20300;
                    if (_20299 == 0u)
                    {
                        _20300 = -1.0f;
                    }
                    else
                    {
                        _20300 = float((_20299 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20301 = _20300;
                }
                _20314 = _20301;
                break;
            } while(false);
            float _6061 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6064 = r_warped_motion_qdata_tp1.Load(int3(_19985, 0)).x == 0u;
            bool _6070;
            if (_6064)
            {
                bool _11746 = all(bool2(_19764.x > 0.0f.xx.x, _19764.y > 0.0f.xx.y));
                bool _11752;
                if (_11746)
                {
                    _11752 = all(bool2(_19764.x < 1.0f.xx.x, _19764.y < 1.0f.xx.y));
                }
                else
                {
                    _11752 = _11746;
                }
                _6070 = _11752;
            }
            else
            {
                _6070 = _6064;
            }
            bool _6075;
            if (_6070)
            {
                bool _11757 = all(bool2(_19766.x > 0.0f.xx.x, _19766.y > 0.0f.xx.y));
                bool _11763;
                if (_11757)
                {
                    _11763 = all(bool2(_19766.x < 1.0f.xx.x, _19766.y < 1.0f.xx.y));
                }
                else
                {
                    _11763 = _11757;
                }
                _6075 = _11763;
            }
            else
            {
                _6075 = _6070;
            }
            bool _20326;
            float4 _20335;
            if (_6075)
            {
                uint _11770_dummy_parameter;
                float _11794 = log((r_depth_tm1.Load(int3(int2(floor(_19764 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11770_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _11802_dummy_parameter;
                float _11826 = log((r_depth_tp1.Load(int3(int2(floor(_19766 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11802_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _6086 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6093;
                if (_6086)
                {
                    _6093 = _11826 > (_11794 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6093 = _6086;
                }
                bool _20331;
                float4 _20353;
                if (_6093)
                {
                    _20353 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20331 = true;
                }
                else
                {
                    bool _6099 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6106;
                    if (_6099)
                    {
                        _6106 = _11794 > (_11826 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6106 = _6099;
                    }
                    bool4 _23654 = _6106.xxxx;
                    _20353 = float4(_23654.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20340.x, _23654.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20340.y, _23654.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20340.z, _23654.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20340.w);
                    _20331 = _6106 ? true : false;
                }
                _20335 = _20353;
                _20326 = _20331;
            }
            else
            {
                _20335 = _20340;
                _20326 = false;
            }
            float4 _20408;
            if (_20326)
            {
                _20408 = 1.0f.xxxx;
            }
            else
            {
                bool _6117 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6123;
                if (_6117)
                {
                    _6123 = _20335.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6123 = _6117;
                }
                bool _6128;
                if (_6123)
                {
                    bool _11832 = all(bool2(_19766.x > 0.0f.xx.x, _19766.y > 0.0f.xx.y));
                    bool _11838;
                    if (_11832)
                    {
                        _11838 = all(bool2(_19766.x < 1.0f.xx.x, _19766.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11838 = _11832;
                    }
                    _6128 = _11838;
                }
                else
                {
                    _6128 = _6123;
                }
                float4 _20409;
                if (_6128)
                {
                    float _20362;
                    if (_20314 >= 0.0f)
                    {
                        _20362 = _20314 - _6061;
                    }
                    else
                    {
                        float _20358;
                        _20358 = 2.0f;
                        float _11895;
                        for (int _20357 = 0; _20357 < 24; _20358 = _11895, _20357++)
                        {
                            float _11859 = float(_20357 & 7) * 0.785398185253143310546875f;
                            int _11861 = _20357 >> 3;
                            int _20359;
                            if (_11861 == 0)
                            {
                                _20359 = 16;
                            }
                            else
                            {
                                _20359 = (_11861 == 1) ? 48 : 96;
                            }
                            uint _11927_dummy_parameter;
                            _11895 = min(_20358, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19766 + ((cbFI_MvDepthLaneSizeRcp * float(_20359)) * float2(cos(_11859), sin(_11859))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11927_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20362 = _20358;
                    }
                    uint _11959_dummy_parameter;
                    float4 _20410;
                    if (r_depth_tp1.Load(int3(int2(floor(_19766 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11959_dummy_parameter))))), 0)).x > ((exp((_20362 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20410 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20410 = 1.0f.xxxx;
                    }
                    _20409 = _20410;
                }
                else
                {
                    _20409 = 1.0f.xxxx;
                }
                _20408 = _20409;
            }
            bool _6156 = _20314 >= 0.0f;
            bool _6157 = (!_20326) && _6156;
            bool _6164;
            if (_6157)
            {
                _6164 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6164 = _6157;
            }
            bool _6170;
            if (_6164)
            {
                _6170 = _20335.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6170 = _6164;
            }
            bool _6175;
            if (_6170)
            {
                bool _11983 = all(bool2(_19764.x > 0.0f.xx.x, _19764.y > 0.0f.xx.y));
                bool _11989;
                if (_11983)
                {
                    _11989 = all(bool2(_19764.x < 1.0f.xx.x, _19764.y < 1.0f.xx.y));
                }
                else
                {
                    _11989 = _11983;
                }
                _6175 = _11989;
            }
            else
            {
                _6175 = _6170;
            }
            float4 _20433;
            if (_6175)
            {
                float _20402;
                if (_6156)
                {
                    _20402 = _20314 - _6061;
                }
                else
                {
                    float _20398;
                    _20398 = 2.0f;
                    float _12046;
                    for (int _20397 = 0; _20397 < 24; _20398 = _12046, _20397++)
                    {
                        float _12010 = float(_20397 & 7) * 0.785398185253143310546875f;
                        int _12012 = _20397 >> 3;
                        int _20399;
                        if (_12012 == 0)
                        {
                            _20399 = 16;
                        }
                        else
                        {
                            _20399 = (_12012 == 1) ? 48 : 96;
                        }
                        uint _12062_dummy_parameter;
                        _12046 = min(_20398, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19764 + ((cbFI_MvDepthLaneSizeRcp * float(_20399)) * float2(cos(_12010), sin(_12010))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12062_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20402 = _20398;
                }
                uint _12110_dummy_parameter;
                float4 _20434;
                if (r_depth_tm1.Load(int3(int2(floor(_19764 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12110_dummy_parameter))))), 0)).x > ((exp((_20402 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19460 = _20408;
                    _19460.x = 0.0f;
                    _20434 = _19460;
                }
                else
                {
                    _20434 = _20408;
                }
                _20433 = _20434;
            }
            else
            {
                _20433 = _20408;
            }
            float4 _20446;
            if (_6157)
            {
                float _12136 = (exp(((_20314 - _6061) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6213 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6219;
                if (_6213)
                {
                    _6219 = _20335.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6219 = _6213;
                }
                bool _6224;
                if (_6219)
                {
                    bool _12141 = all(bool2(_19768.x > 0.0f.xx.x, _19768.y > 0.0f.xx.y));
                    bool _12147;
                    if (_12141)
                    {
                        _12147 = all(bool2(_19768.x < 1.0f.xx.x, _19768.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12147 = _12141;
                    }
                    _6224 = _12147;
                }
                else
                {
                    _6224 = _6219;
                }
                bool _6232;
                if (_6224)
                {
                    uint _12154_dummy_parameter;
                    _6232 = r_depth_tp1.Load(int3(int2(floor(_19768 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12154_dummy_parameter))))), 0)).x > _12136;
                }
                else
                {
                    _6232 = _6224;
                }
                float4 _20444;
                if (_6232)
                {
                    float4 _19463 = _20433;
                    _19463.w = 0.0f;
                    _20444 = _19463;
                }
                else
                {
                    _20444 = _20433;
                }
                bool _6239 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6245;
                if (_6239)
                {
                    _6245 = _20335.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6245 = _6239;
                }
                bool _6250;
                if (_6245)
                {
                    bool _12171 = all(bool2(_19767.x > 0.0f.xx.x, _19767.y > 0.0f.xx.y));
                    bool _12177;
                    if (_12171)
                    {
                        _12177 = all(bool2(_19767.x < 1.0f.xx.x, _19767.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12177 = _12171;
                    }
                    _6250 = _12177;
                }
                else
                {
                    _6250 = _6245;
                }
                bool _6258;
                if (_6250)
                {
                    uint _12184_dummy_parameter;
                    _6258 = r_depth_tm1.Load(int3(int2(floor(_19767 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12184_dummy_parameter))))), 0)).x > _12136;
                }
                else
                {
                    _6258 = _6250;
                }
                float4 _20447;
                if (_6258)
                {
                    float4 _19466 = _20444;
                    _19466.z = 0.0f;
                    _20447 = _19466;
                }
                else
                {
                    _20447 = _20444;
                }
                _20446 = _20447;
            }
            else
            {
                _20446 = _20433;
            }
            float4 _20518;
            if (any(bool4(_20446.x < 1.0f.xxxx.x, _20446.y < 1.0f.xxxx.y, _20446.z < 1.0f.xxxx.z, _20446.w < 1.0f.xxxx.w)))
            {
                float4 _6269 = _20335 * _20446;
                float _6271 = dot(_6269, 1.0f.xxxx);
                float4 _20519;
                if (_6271 > 0.0f)
                {
                    _20519 = _6269 / _6271.xxxx;
                }
                else
                {
                    bool _6282 = _20446.y == 0.0f;
                    bool _6288;
                    if (_6282)
                    {
                        _6288 = _20446.x > 0.0f;
                    }
                    else
                    {
                        _6288 = _6282;
                    }
                    bool _6293;
                    if (_6288)
                    {
                        bool _12201 = all(bool2(_19764.x > 0.0f.xx.x, _19764.y > 0.0f.xx.y));
                        bool _12207;
                        if (_12201)
                        {
                            _12207 = all(bool2(_19764.x < 1.0f.xx.x, _19764.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12207 = _12201;
                        }
                        _6293 = _12207;
                    }
                    else
                    {
                        _6293 = _6288;
                    }
                    float4 _20520;
                    if (_6293)
                    {
                        _20520 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6298 = _20446.x == 0.0f;
                        bool _6304;
                        if (_6298)
                        {
                            _6304 = _20446.y > 0.0f;
                        }
                        else
                        {
                            _6304 = _6298;
                        }
                        bool _6309;
                        if (_6304)
                        {
                            bool _12212 = all(bool2(_19766.x > 0.0f.xx.x, _19766.y > 0.0f.xx.y));
                            bool _12218;
                            if (_12212)
                            {
                                _12218 = all(bool2(_19766.x < 1.0f.xx.x, _19766.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12218 = _12212;
                            }
                            _6309 = _12218;
                        }
                        else
                        {
                            _6309 = _6304;
                        }
                        bool4 _23657 = _6309.xxxx;
                        _20520 = float4(_23657.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20335.x, _23657.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20335.y, _23657.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20335.z, _23657.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20335.w);
                    }
                    _20519 = _20520;
                }
                _20518 = _20519;
            }
            else
            {
                _20518 = _20335;
            }
            _20517 = _20518;
        }
        else
        {
            _20517 = _20340;
        }
        float4 _21247;
        bool _21553;
        float3 _21742;
        if (((cbFI_pad0 & 32768u) != 0u) && _6018)
        {
            bool _6326 = _20517.x > 0.00999999977648258209228515625f;
            bool _6329 = _20517.y > 0.00999999977648258209228515625f;
            bool _6338 = (_20517.z + _20517.w) > 0.0199999995529651641845703125f;
            bool _6344;
            if (_6338)
            {
                bool _12223 = all(bool2(_19767.x > 0.0f.xx.x, _19767.y > 0.0f.xx.y));
                bool _12229;
                if (_12223)
                {
                    _12229 = all(bool2(_19767.x < 1.0f.xx.x, _19767.y < 1.0f.xx.y));
                }
                else
                {
                    _12229 = _12223;
                }
                _6344 = _12229;
            }
            else
            {
                _6344 = _6338;
            }
            bool _6349;
            if (_6344)
            {
                bool _12234 = all(bool2(_19768.x > 0.0f.xx.x, _19768.y > 0.0f.xx.y));
                bool _12240;
                if (_12234)
                {
                    _12240 = all(bool2(_19768.x < 1.0f.xx.x, _19768.y < 1.0f.xx.y));
                }
                else
                {
                    _12240 = _12234;
                }
                _6349 = _12240;
            }
            else
            {
                _6349 = _6344;
            }
            bool _6356;
            if (_6349)
            {
                float _20533;
                do
                {
                    bool _12323 = all(bool2(_19767.x > 0.0f.xx.x, _19767.y > 0.0f.xx.y));
                    bool _12329;
                    if (_12323)
                    {
                        _12329 = all(bool2(_19767.x < 1.0f.xx.x, _19767.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12329 = _12323;
                    }
                    bool _12260 = !_12329;
                    bool _12267;
                    if (!_12260)
                    {
                        bool _12334 = all(bool2(_19768.x > 0.0f.xx.x, _19768.y > 0.0f.xx.y));
                        bool _12340;
                        if (_12334)
                        {
                            _12340 = all(bool2(_19768.x < 1.0f.xx.x, _19768.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12340 = _12334;
                        }
                        _12267 = !_12340;
                    }
                    else
                    {
                        _12267 = _12260;
                    }
                    if (_12267)
                    {
                        _20533 = 0.0f;
                        break;
                    }
                    uint _12347_dummy_parameter;
                    uint _12363_dummy_parameter;
                    float4x4 _20532;
                    do
                    {
                        float4x4 _12377;
                        bool _20531;
                        do
                        {
                            _12377 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20531 = false;
                                break;
                            }
                            uint _12411 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12411 + 32u) * 4 + 0) != 1u)
                            {
                                _20531 = false;
                                break;
                            }
                            uint _20528;
                            _20528 = 0u;
                            for (; _20528 < 4u; _20528++)
                            {
                                for (uint _20529 = 0u; _20529 < 4u; )
                                {
                                    _12377[_20528][_20529] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12411 + 16u) + (_20528 * 4u)) + _20529) * 4 + 0));
                                    _20529++;
                                    continue;
                                }
                            }
                            _20531 = true;
                            break;
                        } while(false);
                        if (_20531)
                        {
                            _20532 = _12377;
                            break;
                        }
                        _20532 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12288 = mul(float4((float2(_19767.x, 1.0f - _19767.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19767 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12347_dummy_parameter))))), 0)).x, 1.0f), _20532);
                    float _12290 = _12288.w;
                    if (abs(_12290) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20533 = 0.0f;
                        break;
                    }
                    float _12301 = abs(cbFI_DeviceToViewDepth.y / ((_12288.z / _12290) - cbFI_DeviceToViewDepth.x));
                    float _12304 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19768 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12363_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20533 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12301 - _12304) / max(max(_12301, _12304), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6356 = _20533 < 0.5f;
            }
            else
            {
                _6356 = _6349;
            }
            float4 _20552;
            if (_6356)
            {
                uint _12515_dummy_parameter;
                uint _12546_dummy_parameter;
                float4 _20553;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19767 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12515_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19768 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12546_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20553 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20553 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20552 = _20553;
            }
            else
            {
                _20552 = 1.0f.xxxx;
            }
            bool _6380;
            if (_10984)
            {
                bool _12575 = all(bool2(_19764.x > 0.0f.xx.x, _19764.y > 0.0f.xx.y));
                bool _12581;
                if (_12575)
                {
                    _12581 = all(bool2(_19764.x < 1.0f.xx.x, _19764.y < 1.0f.xx.y));
                }
                else
                {
                    _12581 = _12575;
                }
                _6380 = _12581;
            }
            else
            {
                _6380 = _10984;
            }
            bool _6386;
            if (_10984)
            {
                bool _12586 = all(bool2(_19766.x > 0.0f.xx.x, _19766.y > 0.0f.xx.y));
                bool _12592;
                if (_12586)
                {
                    _12592 = all(bool2(_19766.x < 1.0f.xx.x, _19766.y < 1.0f.xx.y));
                }
                else
                {
                    _12592 = _12586;
                }
                _6386 = _12592;
            }
            else
            {
                _6386 = _10984;
            }
            bool _6392;
            if (_11016)
            {
                bool _12597 = all(bool2(_19767.x > 0.0f.xx.x, _19767.y > 0.0f.xx.y));
                bool _12603;
                if (_12597)
                {
                    _12603 = all(bool2(_19767.x < 1.0f.xx.x, _19767.y < 1.0f.xx.y));
                }
                else
                {
                    _12603 = _12597;
                }
                _6392 = _12603;
            }
            else
            {
                _6392 = _11016;
            }
            bool _6398;
            if (_11016)
            {
                bool _12608 = all(bool2(_19768.x > 0.0f.xx.x, _19768.y > 0.0f.xx.y));
                bool _12614;
                if (_12608)
                {
                    _12614 = all(bool2(_19768.x < 1.0f.xx.x, _19768.y < 1.0f.xx.y));
                }
                else
                {
                    _12614 = _12608;
                }
                _6398 = _12614;
            }
            else
            {
                _6398 = _11016;
            }
            bool _6401 = _6392 != _6398;
            bool _6407;
            if (_6401)
            {
                _6407 = _6380 || _6386;
            }
            else
            {
                _6407 = _6401;
            }
            float4 _20655;
            if (_6407)
            {
                float4 _19493 = _20552;
                _19493.z = 0.0f;
                _19493.w = 0.0f;
                _20655 = _19493;
            }
            else
            {
                _20655 = _20552;
            }
            bool _6414 = _6380 && _6326;
            bool _6417 = _6386 && _6329;
            float4 _20760;
            float3 _21851;
            if (_6414 || _6417)
            {
                float _20650;
                do
                {
                    uint4 _12753 = r_warped_motion_qdata_tp1.Load(int3(_19985, 0));
                    uint _12754 = _12753.x;
                    if (_12754 != 0u)
                    {
                        float _20649;
                        if (_12754 == 0u)
                        {
                            _20649 = -1.0f;
                        }
                        else
                        {
                            _20649 = float((_12754 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20650 = _20649;
                        break;
                    }
                    int _20632;
                    uint _20633;
                    _20633 = _12754;
                    _20632 = -1;
                    uint _20648;
                    for (; _20632 <= 1; _20633 = _20648, _20632++)
                    {
                        _20648 = _20633;
                        for (int _20646 = -1; _20646 <= 1; )
                        {
                            _20648 = max(_20648, r_warped_motion_qdata_tp1.Load(int3(clamp(_19985 + int2(_20646, _20632), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20646++;
                            continue;
                        }
                    }
                    if (_20633 != 0u)
                    {
                        float _20645;
                        if (_20633 == 0u)
                        {
                            _20645 = -1.0f;
                        }
                        else
                        {
                            _20645 = float((_20633 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20650 = _20645;
                        break;
                    }
                    uint _20635;
                    _20635 = 4294967295u;
                    uint _23286;
                    for (int _20634 = 0; _20634 < 8; _20635 = _23286, _20634++)
                    {
                        int _20638 = 0;
                        for (;;)
                        {
                            if (_20638 < 5)
                            {
                                int2 _12704 = _19985 + (_1247[_20634] * _1256[_20638].xx);
                                bool _12707 = any(bool2(_12704.x < int2(0, 0).x, _12704.y < int2(0, 0).y));
                                bool _12715;
                                if (!_12707)
                                {
                                    _12715 = any(bool2(_12704.x >= cbFI_MvDepthLaneSize.x, _12704.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12715 = _12707;
                                }
                                if (_12715)
                                {
                                    _23286 = _20635;
                                    break;
                                }
                                uint4 _12793 = r_warped_motion_qdata_tp1.Load(int3(_12704, 0));
                                uint _12794 = _12793.x;
                                if (_12794 != 0u)
                                {
                                    _23286 = min(_20635, _12794);
                                    break;
                                }
                                _20638++;
                                continue;
                            }
                            else
                            {
                                _23286 = _20635;
                                break;
                            }
                        }
                    }
                    float _20637;
                    if (_20635 == 4294967295u)
                    {
                        _20637 = -1.0f;
                    }
                    else
                    {
                        float _20636;
                        if (_20635 == 0u)
                        {
                            _20636 = -1.0f;
                        }
                        else
                        {
                            _20636 = float((_20635 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20637 = _20636;
                    }
                    _20650 = _20637;
                    break;
                } while(false);
                bool _6425 = _20650 < 0.0f;
                float _20651;
                if (_6425)
                {
                    _20651 = 0.0f;
                }
                else
                {
                    _20651 = _20650 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12815_dummy_parameter;
                uint _12847_dummy_parameter;
                float4 _20688;
                if ((_6425 && _6414) && _6417)
                {
                    uint _12879_dummy_parameter;
                    float _12903 = log((r_depth_tm1.Load(int3(int2(floor(_19764 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12879_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12911_dummy_parameter;
                    float _12935 = log((r_depth_tp1.Load(int3(int2(floor(_19766 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12911_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20689;
                    if (_12903 > (_12935 + 0.07999999821186065673828125f))
                    {
                        float4 _19497 = _20655;
                        _19497.x = 0.0f;
                        _20689 = _19497;
                    }
                    else
                    {
                        float4 _20690;
                        if (_12935 > (_12903 + 0.07999999821186065673828125f))
                        {
                            float4 _19499 = _20655;
                            _19499.y = 0.0f;
                            _20690 = _19499;
                        }
                        else
                        {
                            _20690 = _20655;
                        }
                        _20689 = _20690;
                    }
                    _20688 = _20689;
                }
                else
                {
                    _20688 = _20655;
                }
                float _6477 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6479 = _20650 >= 0.0f;
                float _20671;
                if (_6479)
                {
                    _20671 = _20650 - _6477;
                }
                else
                {
                    float _20667;
                    if (_6414)
                    {
                        float _20666;
                        _20666 = 2.0f;
                        float _12993;
                        for (int _20665 = 0; _20665 < 24; _20666 = _12993, _20665++)
                        {
                            float _12957 = float(_20665 & 7) * 0.785398185253143310546875f;
                            int _12959 = _20665 >> 3;
                            int _20668;
                            if (_12959 == 0)
                            {
                                _20668 = 16;
                            }
                            else
                            {
                                _20668 = (_12959 == 1) ? 48 : 96;
                            }
                            uint _13009_dummy_parameter;
                            _12993 = min(_20666, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19764 + ((cbFI_MvDepthLaneSizeRcp * float(_20668)) * float2(cos(_12957), sin(_12957))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13009_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20667 = _20666;
                    }
                    else
                    {
                        _20667 = 0.0f;
                    }
                    _20671 = _20667;
                }
                float _20678;
                if (_6479)
                {
                    _20678 = _20650 - _6477;
                }
                else
                {
                    float _20674;
                    if (_6417)
                    {
                        float _20673;
                        _20673 = 2.0f;
                        float _13107;
                        for (int _20672 = 0; _20672 < 24; _20673 = _13107, _20672++)
                        {
                            float _13071 = float(_20672 & 7) * 0.785398185253143310546875f;
                            int _13073 = _20672 >> 3;
                            int _20675;
                            if (_13073 == 0)
                            {
                                _20675 = 16;
                            }
                            else
                            {
                                _20675 = (_13073 == 1) ? 48 : 96;
                            }
                            uint _13139_dummy_parameter;
                            _13107 = min(_20673, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19766 + ((cbFI_MvDepthLaneSizeRcp * float(_20675)) * float2(cos(_13071), sin(_13071))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13139_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20674 = _20673;
                    }
                    else
                    {
                        _20674 = 0.0f;
                    }
                    _20678 = _20674;
                }
                float _20679;
                if (_6414)
                {
                    uint _13171_dummy_parameter;
                    _20679 = r_depth_tm1.Load(int3(int2(floor(_19764 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13171_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20679 = 0.0f;
                }
                float _20680;
                if (_6417)
                {
                    uint _13190_dummy_parameter;
                    _20680 = r_depth_tp1.Load(int3(int2(floor(_19766 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13190_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20680 = 0.0f;
                }
                bool _6534;
                if (_6414)
                {
                    _6534 = _20679 > ((exp((_20671 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6534 = _6414;
                }
                float4 _20696;
                if (_6534)
                {
                    float4 _19501 = _20688;
                    _19501.x = 0.0f;
                    _20696 = _19501;
                }
                else
                {
                    _20696 = _20688;
                }
                bool _6546;
                if (_6417)
                {
                    _6546 = _20680 > ((exp((_20678 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6546 = _6417;
                }
                float4 _20698;
                if (_6546)
                {
                    float4 _19503 = _20696;
                    _19503.y = 0.0f;
                    _20698 = _19503;
                }
                else
                {
                    _20698 = _20696;
                }
                float4 _20761;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6479)
                {
                    bool _6566;
                    if (_6414)
                    {
                        _6566 = _20679 < ((exp((_20671 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6566 = _6414;
                    }
                    float4 _20700;
                    if (_6566)
                    {
                        float4 _19505 = _20698;
                        _19505.x = 0.0f;
                        _20700 = _19505;
                    }
                    else
                    {
                        _20700 = _20698;
                    }
                    bool _6578;
                    if (_6417)
                    {
                        _6578 = _20680 < ((exp((_20678 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6578 = _6417;
                    }
                    float4 _20762;
                    if (_6578)
                    {
                        float4 _19507 = _20700;
                        _19507.y = 0.0f;
                        _20762 = _19507;
                    }
                    else
                    {
                        _20762 = _20700;
                    }
                    _20761 = _20762;
                }
                else
                {
                    _20761 = _20698;
                }
                _21851 = float3(_20651, log((r_depth_tm1.Load(int3(int2(floor(_19764 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12815_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_19766 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12847_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _20760 = _20761;
            }
            else
            {
                _21851 = float3(0.0f, 0.0f, 0.5f);
                _20760 = _20655;
            }
            bool _6589 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6338;
            bool _6595;
            if (_6589)
            {
                _6595 = _6392 || _6398;
            }
            else
            {
                _6595 = _6589;
            }
            float4 _20803;
            if (_6595)
            {
                float _20755;
                do
                {
                    uint4 _13369 = r_warped_motion_qdata_tp1.Load(int3(_19985, 0));
                    uint _13370 = _13369.x;
                    if (_13370 != 0u)
                    {
                        float _20754;
                        if (_13370 == 0u)
                        {
                            _20754 = -1.0f;
                        }
                        else
                        {
                            _20754 = float((_13370 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20755 = _20754;
                        break;
                    }
                    int _20737;
                    uint _20738;
                    _20738 = _13370;
                    _20737 = -1;
                    uint _20753;
                    for (; _20737 <= 1; _20738 = _20753, _20737++)
                    {
                        _20753 = _20738;
                        for (int _20751 = -1; _20751 <= 1; )
                        {
                            _20753 = max(_20753, r_warped_motion_qdata_tp1.Load(int3(clamp(_19985 + int2(_20751, _20737), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20751++;
                            continue;
                        }
                    }
                    if (_20738 != 0u)
                    {
                        float _20750;
                        if (_20738 == 0u)
                        {
                            _20750 = -1.0f;
                        }
                        else
                        {
                            _20750 = float((_20738 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20755 = _20750;
                        break;
                    }
                    uint _20740;
                    _20740 = 4294967295u;
                    uint _23287;
                    for (int _20739 = 0; _20739 < 8; _20740 = _23287, _20739++)
                    {
                        int _20743 = 0;
                        for (;;)
                        {
                            if (_20743 < 5)
                            {
                                int2 _13320 = _19985 + (_1247[_20739] * _1256[_20743].xx);
                                bool _13323 = any(bool2(_13320.x < int2(0, 0).x, _13320.y < int2(0, 0).y));
                                bool _13331;
                                if (!_13323)
                                {
                                    _13331 = any(bool2(_13320.x >= cbFI_MvDepthLaneSize.x, _13320.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13331 = _13323;
                                }
                                if (_13331)
                                {
                                    _23287 = _20740;
                                    break;
                                }
                                uint4 _13409 = r_warped_motion_qdata_tp1.Load(int3(_13320, 0));
                                uint _13410 = _13409.x;
                                if (_13410 != 0u)
                                {
                                    _23287 = min(_20740, _13410);
                                    break;
                                }
                                _20743++;
                                continue;
                            }
                            else
                            {
                                _23287 = _20740;
                                break;
                            }
                        }
                    }
                    float _20742;
                    if (_20740 == 4294967295u)
                    {
                        _20742 = -1.0f;
                    }
                    else
                    {
                        float _20741;
                        if (_20740 == 0u)
                        {
                            _20741 = -1.0f;
                        }
                        else
                        {
                            _20741 = float((_20740 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20742 = _20741;
                    }
                    _20755 = _20742;
                    break;
                } while(false);
                float4 _20804;
                if (_20755 >= 0.0f)
                {
                    float _13431 = (exp((_20755 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6614;
                    if (_6392)
                    {
                        uint _13438_dummy_parameter;
                        _6614 = r_depth_tm1.Load(int3(int2(floor(_19767 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13438_dummy_parameter))))), 0)).x > _13431;
                    }
                    else
                    {
                        _6614 = _6392;
                    }
                    float4 _20773;
                    if (_6614)
                    {
                        float4 _19509 = _20760;
                        _19509.z = 0.0f;
                        _20773 = _19509;
                    }
                    else
                    {
                        _20773 = _20760;
                    }
                    bool _6626;
                    if (_6398)
                    {
                        uint _13457_dummy_parameter;
                        _6626 = r_depth_tp1.Load(int3(int2(floor(_19768 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13457_dummy_parameter))))), 0)).x > _13431;
                    }
                    else
                    {
                        _6626 = _6398;
                    }
                    float4 _20805;
                    if (_6626)
                    {
                        float4 _19511 = _20773;
                        _19511.w = 0.0f;
                        _20805 = _19511;
                    }
                    else
                    {
                        _20805 = _20773;
                    }
                    _20804 = _20805;
                }
                else
                {
                    _20804 = _20760;
                }
                _20803 = _20804;
            }
            else
            {
                _20803 = _20760;
            }
            bool _6634 = _6380 != _6386;
            bool _6641;
            if (_6634)
            {
                _6641 = _6380 ? _6326 : _6329;
            }
            else
            {
                _6641 = _6634;
            }
            bool _6648;
            if (_6641)
            {
                _6648 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6648 = _6641;
            }
            float4 _20906;
            if (_6648)
            {
                bool2 _6653 = _6380.xx;
                float2 _6654 = float2(_6653.x ? _19764.x : _19766.x, _6653.y ? _19764.y : _19766.y);
                float _20787;
                if (_6380)
                {
                    uint _13476_dummy_parameter;
                    _20787 = r_depth_tm1.Load(int3(int2(floor(_6654 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13476_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13492_dummy_parameter;
                    _20787 = r_depth_tp1.Load(int3(int2(floor(_6654 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13492_dummy_parameter))))), 0)).x;
                }
                float4x4 _20794;
                if (_6380)
                {
                    float4x4 _20783;
                    do
                    {
                        float4x4 _13506;
                        bool _20782;
                        do
                        {
                            _13506 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20782 = false;
                                break;
                            }
                            uint _13540 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13540 + 32u) * 4 + 0) != 1u)
                            {
                                _20782 = false;
                                break;
                            }
                            uint _20779;
                            _20779 = 0u;
                            for (; _20779 < 4u; _20779++)
                            {
                                for (uint _20780 = 0u; _20780 < 4u; )
                                {
                                    _13506[_20779][_20780] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13540 + 16u) + (_20779 * 4u)) + _20780) * 4 + 0));
                                    _20780++;
                                    continue;
                                }
                            }
                            _20782 = true;
                            break;
                        } while(false);
                        if (_20782)
                        {
                            _20783 = _13506;
                            break;
                        }
                        _20783 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20794 = _20783;
                }
                else
                {
                    float4x4 _20778;
                    do
                    {
                        float4x4 _13612;
                        bool _20777;
                        do
                        {
                            _13612 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20777 = false;
                                break;
                            }
                            uint _13646 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13646 + 32u) * 4 + 0) != 1u)
                            {
                                _20777 = false;
                                break;
                            }
                            uint _20774;
                            _20774 = 0u;
                            for (; _20774 < 4u; _20774++)
                            {
                                for (uint _20775 = 0u; _20775 < 4u; )
                                {
                                    _13612[_20774][_20775] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13646 + (_20774 * 4u)) + _20775) * 4 + 0));
                                    _20775++;
                                    continue;
                                }
                            }
                            _20777 = true;
                            break;
                        } while(false);
                        if (_20777)
                        {
                            _20778 = _13612;
                            break;
                        }
                        _20778 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20794 = _20778;
                }
                float2 _20795;
                do
                {
                    float _13723 = _6654.x;
                    float _13726 = 1.0f - _6654.y;
                    float4 _13737 = mul(float4((float2(_13723, _13726) * 2.0f) - 1.0f.xx, _20787, 1.0f), _20794);
                    float _13739 = _13737.w;
                    if (!(_13739 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20795 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13752 = ((_13737.xy / _13739.xx) + 1.0f.xx) * 0.5f;
                    _20795 = float2(_13752.x - _13723, _13726 - _13752.y);
                    break;
                } while(false);
                float2 _6684 = float2(cbFI_DisplaySize);
                float4 _20907;
                if (!(length(((_6654 + _20795) - float2(_6653.x ? _19766.x : _19764.x, _6653.y ? _19766.y : _19764.y)) * _6684) <= ((0.100000001490116119384765625f * length(_20795 * _6684)) + 8.0f)))
                {
                    float4 _20908;
                    if (_6380)
                    {
                        float4 _19521 = _20803;
                        _19521.x = 0.0f;
                        _20908 = _19521;
                    }
                    else
                    {
                        float4 _19523 = _20803;
                        _19523.y = 0.0f;
                        _20908 = _19523;
                    }
                    _20907 = _20908;
                }
                else
                {
                    _20907 = _20803;
                }
                _20906 = _20907;
            }
            else
            {
                _20906 = _20803;
            }
            float4 _6709 = _20517 * _20906;
            float _6711 = dot(_6709, 1.0f.xxxx);
            float4 _21248;
            bool _21554;
            if (_6711 > 0.0f)
            {
                _21554 = _20208;
                _21248 = _6709 / _6711.xxxx;
            }
            else
            {
                bool _6722 = any(bool4(_20906.x < 1.0f.xxxx.x, _20906.y < 1.0f.xxxx.y, _20906.z < 1.0f.xxxx.z, _20906.w < 1.0f.xxxx.w));
                if (_6722)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13774;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13774);
                    }
                }
                bool4 _23660 = _6722.xxxx;
                _21554 = _6722 ? true : _20208;
                _21248 = float4(_23660.x ? 0.0f.xxxx.x : _20517.x, _23660.y ? 0.0f.xxxx.y : _20517.y, _23660.z ? 0.0f.xxxx.z : _20517.z, _23660.w ? 0.0f.xxxx.w : _20517.w);
            }
            _21742 = _21851;
            _21553 = _21554;
            _21247 = _21248;
        }
        else
        {
            _21742 = float3(0.0f, 0.0f, 0.5f);
            _21553 = _20208;
            _21247 = _20517;
        }
        uint _6731 = (cbFI_pad0 >> 24u) & 31u;
        uint _6735 = (cbFI_pad0 >> 16u) & 255u;
        bool _6737 = _6731 != 0u;
        bool _6739 = _6735 == 12u;
        bool _6742 = _6735 == 13u;
        float4 _21268;
        if ((_6737 || _6739) || _6742)
        {
            float _20914;
            do
            {
                bool _13858 = all(bool2(_19767.x > 0.0f.xx.x, _19767.y > 0.0f.xx.y));
                bool _13864;
                if (_13858)
                {
                    _13864 = all(bool2(_19767.x < 1.0f.xx.x, _19767.y < 1.0f.xx.y));
                }
                else
                {
                    _13864 = _13858;
                }
                bool _13795 = !_13864;
                bool _13802;
                if (!_13795)
                {
                    bool _13869 = all(bool2(_19768.x > 0.0f.xx.x, _19768.y > 0.0f.xx.y));
                    bool _13875;
                    if (_13869)
                    {
                        _13875 = all(bool2(_19768.x < 1.0f.xx.x, _19768.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13875 = _13869;
                    }
                    _13802 = !_13875;
                }
                else
                {
                    _13802 = _13795;
                }
                if (_13802)
                {
                    _20914 = 0.0f;
                    break;
                }
                uint _13882_dummy_parameter;
                uint _13898_dummy_parameter;
                float4x4 _20913;
                do
                {
                    float4x4 _13912;
                    bool _20912;
                    do
                    {
                        _13912 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20912 = false;
                            break;
                        }
                        uint _13946 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_13946 + 32u) * 4 + 0) != 1u)
                        {
                            _20912 = false;
                            break;
                        }
                        uint _20909;
                        _20909 = 0u;
                        for (; _20909 < 4u; _20909++)
                        {
                            for (uint _20910 = 0u; _20910 < 4u; )
                            {
                                _13912[_20909][_20910] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13946 + 16u) + (_20909 * 4u)) + _20910) * 4 + 0));
                                _20910++;
                                continue;
                            }
                        }
                        _20912 = true;
                        break;
                    } while(false);
                    if (_20912)
                    {
                        _20913 = _13912;
                        break;
                    }
                    _20913 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13823 = mul(float4((float2(_19767.x, 1.0f - _19767.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19767 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13882_dummy_parameter))))), 0)).x, 1.0f), _20913);
                float _13825 = _13823.w;
                if (abs(_13825) < 9.9999999747524270787835121154785e-07f)
                {
                    _20914 = 0.0f;
                    break;
                }
                float _13836 = abs(cbFI_DeviceToViewDepth.y / ((_13823.z / _13825) - cbFI_DeviceToViewDepth.x));
                float _13839 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19768 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13898_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20914 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13836 - _13839) / max(max(_13836, _13839), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14048 = all(bool2(_19768.x > 0.0f.xx.x, _19768.y > 0.0f.xx.y));
            bool _14054;
            if (_14048)
            {
                _14054 = all(bool2(_19768.x < 1.0f.xx.x, _19768.y < 1.0f.xx.y));
            }
            else
            {
                _14054 = _14048;
            }
            float _20915;
            if (_14054)
            {
                uint _14061_dummy_parameter;
                _20915 = length((_7882 + (r_motion_tp1.Load(int3(int2(floor(_19768 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14061_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20915 = 1000000.0f;
            }
            float _20930;
            if ((_6731 & 1u) != 0u)
            {
                _20930 = _20914;
            }
            else
            {
                _20930 = 1.0f;
            }
            float _20931;
            if ((_6731 & 2u) != 0u)
            {
                _20931 = _20930 * (1.0f - smoothstep(2.0f, 8.0f, _20915));
            }
            else
            {
                _20931 = _20930;
            }
            float _20932;
            if ((_6731 & 4u) != 0u)
            {
                _20932 = _20931 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8603 - _8611) - length(_8587 - _8595))));
            }
            else
            {
                _20932 = _20931;
            }
            float _21262;
            if ((_6731 & 8u) != 0u)
            {
                _21262 = lerp(1.0f, _20932, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8587 - _8595)));
            }
            else
            {
                _21262 = _20932;
            }
            bool _6817 = (_6731 & 16u) != 0u;
            bool _6826;
            if (_6817)
            {
                _6826 = length(_19762 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6826 = _6817;
            }
            float _23662 = _6826 ? 1.0f : _21262;
            bool _6832 = _6737 && _10984;
            bool _6837;
            if (_6832)
            {
                bool _14086 = all(bool2(_19764.x > 0.0f.xx.x, _19764.y > 0.0f.xx.y));
                bool _14092;
                if (_14086)
                {
                    _14092 = all(bool2(_19764.x < 1.0f.xx.x, _19764.y < 1.0f.xx.y));
                }
                else
                {
                    _14092 = _14086;
                }
                _6837 = _14092;
            }
            else
            {
                _6837 = _6832;
            }
            bool _6842;
            if (_6837)
            {
                bool _14097 = all(bool2(_19766.x > 0.0f.xx.x, _19766.y > 0.0f.xx.y));
                bool _14103;
                if (_14097)
                {
                    _14103 = all(bool2(_19766.x < 1.0f.xx.x, _19766.y < 1.0f.xx.y));
                }
                else
                {
                    _14103 = _14097;
                }
                _6842 = _14103;
            }
            else
            {
                _6842 = _6837;
            }
            float4 _21269;
            if (_6842)
            {
                float _6848 = _21247.x + _21247.y;
                float _6857 = (_21247.z + _21247.w) * (1.0f - _23662);
                float _21265;
                if (_6848 > 9.9999997473787516355514526367188e-06f)
                {
                    _21265 = _21247.x / _6848;
                }
                else
                {
                    _21265 = _5587;
                }
                _21269 = float4(_21247.x + (_6857 * _21265), _21247.y + (_6857 * (1.0f - _21265)), _21247.zw * _23662);
            }
            else
            {
                _21269 = _21247;
            }
            _21268 = _21269;
        }
        else
        {
            _21268 = _21247;
        }
        float3 _6918 = (((_8587 * _21268.x) + (_8595 * _21268.y)) + (_8603 * _21268.z)) + (_8611 * _21268.w);
        float3 _22861;
        if (_5603 && (_21283 > 0.0f))
        {
            uint _14110_dummy_parameter;
            float2 _14125 = r_motion_tp1.Load(int3(int2(floor(_5362 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14110_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21545;
            if (_7910)
            {
                float2 _14170 = clamp((((_19741 + (_14125 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14173 = tan(_14170.x);
                _21545 = (float2(_14173 / cbFI_DeviceToViewDepth.z, (tan(_14170.y) * sqrt(1.0f + (_14173 * _14173))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21545 = _19741 + (_14125 * cbFI_Timestep);
            }
            float2 _21546;
            if (_7910)
            {
                float2 _14249 = clamp((((_19741 + (_14125 * _5577)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14252 = tan(_14249.x);
                _21546 = (float2(_14252 / cbFI_DeviceToViewDepth.z, (tan(_14249.y) * sqrt(1.0f + (_14252 * _14252))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21546 = _19741 + (_14125 * _5577);
            }
            _22861 = lerp(_6918, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21545, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21546, 0.0f).xyz, cbFI_Timestep.xxx), _21283.xxx);
        }
        else
        {
            _22861 = _6918;
        }
        float3 _22860;
        if (_21553)
        {
            float3 _14294 = r_current_interpolation_source.Load(int3(_4856, 0)).xyz;
            float3 _22862;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _10984)
            {
                uint _14301_dummy_parameter;
                float _21676;
                _21676 = r_depth_tm1.Load(int3(int2(floor(_19764 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14301_dummy_parameter))))), 0)).x;
                float _6999;
                for (int _21675 = 0; _21675 < 24; _21676 = _6999, _21675++)
                {
                    float _6971 = float(_21675 & 7) * 0.785398185253143310546875f;
                    int _6973 = _21675 >> 3;
                    int _23129;
                    if (_6973 == 0)
                    {
                        _23129 = 16;
                    }
                    else
                    {
                        _23129 = (_6973 == 1) ? 48 : 96;
                    }
                    uint _14321_dummy_parameter;
                    _6999 = min(_21676, r_depth_tm1.Load(int3(int2(floor(clamp(_19764 + ((cbFI_MvDepthLaneSizeRcp * float(_23129)) * float2(cos(_6971), sin(_6971))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14321_dummy_parameter))))), 0)).x);
                }
                float2 _21677;
                do
                {
                    float _14343 = 1.0f - _19764.y;
                    float4 _14354 = mul(float4((float2(_19764.x, _14343) * 2.0f) - 1.0f.xx, _21676, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14356 = _14354.w;
                    if (!(_14356 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21677 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14369 = ((_14354.xy / _14356.xx) + 1.0f.xx) * 0.5f;
                    _21677 = float2(_14369.x - _19764.x, _14343 - _14369.y);
                    break;
                } while(false);
                float2 _7010 = _19764 + _21677;
                bool _14387 = all(bool2(_7010.x > 0.0f.xx.x, _7010.y > 0.0f.xx.y));
                bool _14393;
                if (_14387)
                {
                    _14393 = all(bool2(_7010.x < 1.0f.xx.x, _7010.y < 1.0f.xx.y));
                }
                else
                {
                    _14393 = _14387;
                }
                float3 _22863;
                if (_14393)
                {
                    float _7016 = abs(cbFI_DeviceToViewDepth.y / (_21676 - cbFI_DeviceToViewDepth.x));
                    uint _14413_dummy_parameter;
                    int2 _14413 = int2(spvTextureSize(r_depth_m2, uint(0), _14413_dummy_parameter));
                    float _7020 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7010 * float2(_14413))), int2(0, 0), _14413 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22868;
                    if (abs(_7020 - _7016) <= (0.20000000298023223876953125f * max(_7020, _7016)))
                    {
                        uint _14447_dummy_parameter;
                        int2 _14447 = int2(spvTextureSize(r_colour_m2, uint(0), _14447_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14470;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14470);
                        }
                        _22868 = r_colour_m2.Load(int3(clamp(int2(floor(_7010 * float2(_14447))), int2(0, 0), _14447 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14480;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14480);
                        }
                        _22868 = _14294;
                    }
                    _22863 = _22868;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14490;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14490);
                    }
                    _22863 = _14294;
                }
                _22862 = _22863;
            }
            else
            {
                _22862 = _14294;
            }
            _22860 = _22862;
        }
        else
        {
            _22860 = _22861;
        }
        bool _7045 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22859;
        float _22935;
        if (_7045)
        {
            bool _14705;
            float2 _7049 = float2(cbFI_DisplaySize);
            float4x4 _21684;
            do
            {
                float4x4 _14681;
                bool _21683;
                do
                {
                    _14681 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                    _14705 = (cbFI_NfruT2Flags & 524288u) == 0u;
                    if (_14705)
                    {
                        _21683 = false;
                        break;
                    }
                    uint _14715 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                    if (rw_nfru_diagnostics.Load<uint>((_14715 + 32u) * 4 + 0) != 1u)
                    {
                        _21683 = false;
                        break;
                    }
                    uint _21680;
                    _21680 = 0u;
                    for (; _21680 < 4u; _21680++)
                    {
                        for (uint _21681 = 0u; _21681 < 4u; )
                        {
                            _14681[_21680][_21681] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14715 + (_21680 * 4u)) + _21681) * 4 + 0));
                            _21681++;
                            continue;
                        }
                    }
                    _21683 = true;
                    break;
                } while(false);
                if (_21683)
                {
                    _21684 = _14681;
                    break;
                }
                _21684 = cbFI_MotionTP1ToTM1;
                break;
            } while(false);
            float _14792;
            float _14795;
            float4 _14805;
            float2 _21685;
            do
            {
                _14792 = _5362.x;
                _14795 = 1.0f - _5362.y;
                _14805 = float4((float2(_14792, _14795) * 2.0f) - 1.0f.xx, 1.0000000116860974230803549289703e-07f, 1.0f);
                float4 _14806 = mul(_14805, _21684);
                float _14808 = _14806.w;
                if (!(_14808 > 9.9999999747524270787835121154785e-07f))
                {
                    _21685 = 1000000.0f.xx;
                    break;
                }
                float2 _14821 = ((_14806.xy / _14808.xx) + 1.0f.xx) * 0.5f;
                _21685 = float2(_14821.x - _14792, _14795 - _14821.y);
                break;
            } while(false);
            float4x4 _21690;
            do
            {
                float4x4 _14839;
                bool _21689;
                do
                {
                    _14839 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                    if (_14705)
                    {
                        _21689 = false;
                        break;
                    }
                    uint _14873 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                    if (rw_nfru_diagnostics.Load<uint>((_14873 + 32u) * 4 + 0) != 1u)
                    {
                        _21689 = false;
                        break;
                    }
                    uint _21686;
                    _21686 = 0u;
                    for (; _21686 < 4u; _21686++)
                    {
                        for (uint _21687 = 0u; _21687 < 4u; )
                        {
                            _14839[_21686][_21687] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14873 + 16u) + (_21686 * 4u)) + _21687) * 4 + 0));
                            _21687++;
                            continue;
                        }
                    }
                    _21689 = true;
                    break;
                } while(false);
                if (_21689)
                {
                    _21690 = _14839;
                    break;
                }
                _21690 = cbFI_MotionTM1ToTP1;
                break;
            } while(false);
            float2 _21691;
            do
            {
                float4 _14964 = mul(_14805, _21690);
                float _14966 = _14964.w;
                if (!(_14966 > 9.9999999747524270787835121154785e-07f))
                {
                    _21691 = 1000000.0f.xx;
                    break;
                }
                float2 _14979 = ((_14964.xy / _14966.xx) + 1.0f.xx) * 0.5f;
                _21691 = float2(_14979.x - _14792, _14795 - _14979.y);
                break;
            } while(false);
            float2 _14542 = abs(_21685);
            bool2 _23663 = any(bool2(_14542.x > 4.0f.xx.x, _14542.y > 4.0f.xx.y)).xx;
            float2 _14548 = abs(_21691);
            bool2 _23665 = any(bool2(_14548.x > 4.0f.xx.x, _14548.y > 4.0f.xx.y)).xx;
            float2 _14993[3];
            _14993[0] = _5362;
            float2 _15109 = clamp(_5362, 0.0f.xx, 1.0f.xx);
            uint _15117_dummy_parameter;
            _14993[1] = _5362 - ((r_motion_tp1.Load(int3(int2(floor(_15109 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15117_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5587);
            _14993[2] = _5362 - (float2(_23663.x ? 0.0f.xx.x : _21685.x, _23663.y ? 0.0f.xx.y : _21685.y) * _5587);
            float _21701;
            float2 _21702;
            _21702 = _5362;
            _21701 = 1000000000.0f;
            float _23667;
            float2 _23669;
            float _23670;
            int _21700 = 0;
            float _23121 = -1.0f;
            for (; _21700 < 3; _23121 = _23667, _21702 = _23669, _21701 = _23670, _21700++)
            {
                float2 _23111;
                _23111 = _14993[_21700];
                for (int _23110 = 0; _23110 < 30; )
                {
                    uint _15733_dummy_parameter;
                    _23111 += (((_5362 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_23111, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15733_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5587)) - _23111) * 0.699999988079071044921875f);
                    _23110++;
                    continue;
                }
                float2 _16269 = clamp(_23111, 0.0f.xx, 1.0f.xx);
                uint _16277_dummy_parameter;
                bool _16813 = all(bool2(_23111.x > 0.0f.xx.x, _23111.y > 0.0f.xx.y));
                bool _16819;
                if (_16813)
                {
                    _16819 = all(bool2(_23111.x < 1.0f.xx.x, _23111.y < 1.0f.xx.y));
                }
                else
                {
                    _16819 = _16813;
                }
                float _23113;
                if (_16819)
                {
                    _23113 = length(((_23111 + ((r_motion_tp1.Load(int3(int2(floor(_16269 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16277_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5587)) - _5362) * float2(cbFI_RenderSize));
                }
                else
                {
                    _23113 = 1000000000.0f;
                }
                uint _16830_dummy_parameter;
                float _16870 = log((r_depth_tp1.Load(int3(int2(floor(_16269 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16830_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _15069 = _23113 < 0.3499999940395355224609375f;
                bool _15071 = _21701 < 0.3499999940395355224609375f;
                bool _15081;
                if (_15069)
                {
                    _15081 = (!_15071) || (_16870 > _23121);
                }
                else
                {
                    _15081 = _15069;
                }
                bool _15094;
                if (!_15081)
                {
                    _15094 = ((!_15069) && (!_15071)) && (_23113 < _21701);
                }
                else
                {
                    _15094 = _15081;
                }
                _23667 = _15094 ? _16870 : _23121;
                bool2 _23668 = _15094.xx;
                _23669 = float2(_23668.x ? _23111.x : _21702.x, _23668.y ? _23111.y : _21702.y);
                _23670 = _15094 ? _23113 : _21701;
            }
            float2 _16872[3];
            _16872[0] = _5362;
            float2 _21730;
            do
            {
                bool _21711;
                do
                {
                    bool _17115 = all(bool2(_15109.x > 0.0f.xx.x, _15109.y > 0.0f.xx.y));
                    bool _17121;
                    if (_17115)
                    {
                        _17121 = all(bool2(_15109.x < 1.0f.xx.x, _15109.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17121 = _17115;
                    }
                    if (!_17121)
                    {
                        _21711 = false;
                        break;
                    }
                    uint _17128_dummy_parameter;
                    float4x4 _21709;
                    do
                    {
                        float4x4 _17142;
                        bool _21708;
                        do
                        {
                            _17142 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14705)
                            {
                                _21708 = false;
                                break;
                            }
                            uint _17176 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_17176 + 32u) * 4 + 0) != 1u)
                            {
                                _21708 = false;
                                break;
                            }
                            uint _21705;
                            _21705 = 0u;
                            for (; _21705 < 4u; _21705++)
                            {
                                for (uint _21706 = 0u; _21706 < 4u; )
                                {
                                    _17142[_21705][_21706] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17176 + (_21705 * 4u)) + _21706) * 4 + 0));
                                    _21706++;
                                    continue;
                                }
                            }
                            _21708 = true;
                            break;
                        } while(false);
                        if (_21708)
                        {
                            _21709 = _17142;
                            break;
                        }
                        _21709 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _21710;
                    do
                    {
                        float _17253 = _15109.x;
                        float _17256 = 1.0f - _15109.y;
                        float4 _17267 = mul(float4((float2(_17253, _17256) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15109 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17128_dummy_parameter))))), 0)).x, 1.0f), _21709);
                        float _17269 = _17267.w;
                        if (!(_17269 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21710 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17282 = ((_17267.xy / _17269.xx) + 1.0f.xx) * 0.5f;
                        _21710 = float2(_17282.x - _17253, _17256 - _17282.y);
                        break;
                    } while(false);
                    float2 _17079 = abs(_21710);
                    if (any(bool2(_17079.x > 100000.0f.xx.x, _17079.y > 100000.0f.xx.y)))
                    {
                        _21711 = false;
                        break;
                    }
                    float _17087 = length(_21710 * _7049);
                    uint _17302_dummy_parameter;
                    bool _17101 = _17087 > ((8.0f * _7049.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _17108;
                    if (_17101)
                    {
                        _17108 = length((r_motion_tp1.Load(int3(int2(floor(_15109 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17302_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7049) < (0.20000000298023223876953125f * _17087);
                    }
                    else
                    {
                        _17108 = _17101;
                    }
                    _21711 = _17108;
                    break;
                } while(false);
                if (_21711)
                {
                    uint _17333_dummy_parameter;
                    _21730 = -(r_motion_tp1.Load(int3(int2(floor(_15109 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17333_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                    break;
                }
                uint _17360_dummy_parameter;
                float4x4 _21724;
                do
                {
                    float4x4 _17374;
                    bool _21723;
                    do
                    {
                        _17374 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if (_14705)
                        {
                            _21723 = false;
                            break;
                        }
                        uint _17408 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_17408 + 32u) * 4 + 0) != 1u)
                        {
                            _21723 = false;
                            break;
                        }
                        uint _21720;
                        _21720 = 0u;
                        for (; _21720 < 4u; _21720++)
                        {
                            for (uint _21721 = 0u; _21721 < 4u; )
                            {
                                _17374[_21720][_21721] = asfloat(rw_nfru_diagnostics.Load<uint>((((_17408 + 16u) + (_21720 * 4u)) + _21721) * 4 + 0));
                                _21721++;
                                continue;
                            }
                        }
                        _21723 = true;
                        break;
                    } while(false);
                    if (_21723)
                    {
                        _21724 = _17374;
                        break;
                    }
                    _21724 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float2 _21729;
                do
                {
                    float _17485 = _15109.x;
                    float _17488 = 1.0f - _15109.y;
                    float4 _17499 = mul(float4((float2(_17485, _17488) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15109 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17360_dummy_parameter))))), 0)).x, 1.0f), _21724);
                    float _17501 = _17499.w;
                    if (!(_17501 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21729 = 1000000.0f.xx;
                        break;
                    }
                    float2 _17514 = ((_17499.xy / _17501.xx) + 1.0f.xx) * 0.5f;
                    _21729 = float2(_17514.x - _17485, _17488 - _17514.y);
                    break;
                } while(false);
                float2 _17046 = abs(_21729);
                bool2 _17050 = any(bool2(_17046.x > 4.0f.xx.x, _17046.y > 4.0f.xx.y)).xx;
                _21730 = float2(_17050.x ? 0.0f.xx.x : _21729.x, _17050.y ? 0.0f.xx.y : _21729.y);
                break;
            } while(false);
            _16872[1] = _5362 - (_21730 * cbFI_Timestep);
            _16872[2] = _5362 - (float2(_23665.x ? 0.0f.xx.x : _21691.x, _23665.y ? 0.0f.xx.y : _21691.y) * cbFI_Timestep);
            float _21732;
            float2 _21733;
            _21733 = _5362;
            _21732 = 1000000000.0f;
            float _23671;
            float2 _23673;
            float _23674;
            float4x4 _17758;
            float4x4 _17990;
            float4x4 _18302;
            float4x4 _18534;
            int _21731 = 0;
            float _23023 = -1.0f;
            for (; _21731 < 3; _23023 = _23671, _21733 = _23673, _21732 = _23674, _21731++)
            {
                float2 _22956;
                _22956 = _16872[_21731];
                float2 _17568;
                for (int _22955 = 0; _22955 < 30; _22956 = _17568, _22955++)
                {
                    float2 _23081;
                    do
                    {
                        float2 _17647 = clamp(_22956, 0.0f.xx, 1.0f.xx);
                        bool _23062;
                        do
                        {
                            bool _17731 = all(bool2(_17647.x > 0.0f.xx.x, _17647.y > 0.0f.xx.y));
                            bool _17737;
                            if (_17731)
                            {
                                _17737 = all(bool2(_17647.x < 1.0f.xx.x, _17647.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _17737 = _17731;
                            }
                            if (!_17737)
                            {
                                _23062 = false;
                                break;
                            }
                            uint _17744_dummy_parameter;
                            float4x4 _23060;
                            do
                            {
                                bool _23059;
                                do
                                {
                                    _17758 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14705)
                                    {
                                        _23059 = false;
                                        break;
                                    }
                                    uint _17792 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_17792 + 32u) * 4 + 0) != 1u)
                                    {
                                        _23059 = false;
                                        break;
                                    }
                                    uint _23056;
                                    _23056 = 0u;
                                    for (; _23056 < 4u; _23056++)
                                    {
                                        for (uint _23057 = 0u; _23057 < 4u; )
                                        {
                                            _17758[_23056][_23057] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17792 + (_23056 * 4u)) + _23057) * 4 + 0));
                                            _23057++;
                                            continue;
                                        }
                                    }
                                    _23059 = true;
                                    break;
                                } while(false);
                                if (_23059)
                                {
                                    _23060 = _17758;
                                    break;
                                }
                                _23060 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _23061;
                            do
                            {
                                float _17869 = _17647.x;
                                float _17872 = 1.0f - _17647.y;
                                float4 _17883 = mul(float4((float2(_17869, _17872) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17647 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17744_dummy_parameter))))), 0)).x, 1.0f), _23060);
                                float _17885 = _17883.w;
                                if (!(_17885 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _23061 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17898 = ((_17883.xy / _17885.xx) + 1.0f.xx) * 0.5f;
                                _23061 = float2(_17898.x - _17869, _17872 - _17898.y);
                                break;
                            } while(false);
                            float2 _17695 = abs(_23061);
                            if (any(bool2(_17695.x > 100000.0f.xx.x, _17695.y > 100000.0f.xx.y)))
                            {
                                _23062 = false;
                                break;
                            }
                            float _17703 = length(_23061 * _7049);
                            uint _17918_dummy_parameter;
                            bool _17717 = _17703 > ((8.0f * _7049.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _17724;
                            if (_17717)
                            {
                                _17724 = length((r_motion_tp1.Load(int3(int2(floor(_17647 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17918_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7049) < (0.20000000298023223876953125f * _17703);
                            }
                            else
                            {
                                _17724 = _17717;
                            }
                            _23062 = _17724;
                            break;
                        } while(false);
                        if (_23062)
                        {
                            uint _17949_dummy_parameter;
                            _23081 = -(r_motion_tp1.Load(int3(int2(floor(_17647 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17949_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _17976_dummy_parameter;
                        float4x4 _23075;
                        do
                        {
                            bool _23074;
                            do
                            {
                                _17990 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14705)
                                {
                                    _23074 = false;
                                    break;
                                }
                                uint _18024 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_18024 + 32u) * 4 + 0) != 1u)
                                {
                                    _23074 = false;
                                    break;
                                }
                                uint _23071;
                                _23071 = 0u;
                                for (; _23071 < 4u; _23071++)
                                {
                                    for (uint _23072 = 0u; _23072 < 4u; )
                                    {
                                        _17990[_23071][_23072] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18024 + 16u) + (_23071 * 4u)) + _23072) * 4 + 0));
                                        _23072++;
                                        continue;
                                    }
                                }
                                _23074 = true;
                                break;
                            } while(false);
                            if (_23074)
                            {
                                _23075 = _17990;
                                break;
                            }
                            _23075 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float2 _23080;
                        do
                        {
                            float _18101 = _17647.x;
                            float _18104 = 1.0f - _17647.y;
                            float4 _18115 = mul(float4((float2(_18101, _18104) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17647 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17976_dummy_parameter))))), 0)).x, 1.0f), _23075);
                            float _18117 = _18115.w;
                            if (!(_18117 > 9.9999999747524270787835121154785e-07f))
                            {
                                _23080 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18130 = ((_18115.xy / _18117.xx) + 1.0f.xx) * 0.5f;
                            _23080 = float2(_18130.x - _18101, _18104 - _18130.y);
                            break;
                        } while(false);
                        float2 _17662 = abs(_23080);
                        bool2 _17666 = any(bool2(_17662.x > 4.0f.xx.x, _17662.y > 4.0f.xx.y)).xx;
                        _23081 = float2(_17666.x ? 0.0f.xx.x : _23080.x, _17666.y ? 0.0f.xx.y : _23080.y);
                        break;
                    } while(false);
                    _17568 = _22956 + (((_5362 - (_23081 * cbFI_Timestep)) - _22956) * 0.699999988079071044921875f);
                }
                float2 _18191;
                float2 _22982;
                do
                {
                    _18191 = clamp(_22956, 0.0f.xx, 1.0f.xx);
                    bool _22963;
                    do
                    {
                        bool _18275 = all(bool2(_18191.x > 0.0f.xx.x, _18191.y > 0.0f.xx.y));
                        bool _18281;
                        if (_18275)
                        {
                            _18281 = all(bool2(_18191.x < 1.0f.xx.x, _18191.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _18281 = _18275;
                        }
                        if (!_18281)
                        {
                            _22963 = false;
                            break;
                        }
                        uint _18288_dummy_parameter;
                        float4x4 _22961;
                        do
                        {
                            bool _22960;
                            do
                            {
                                _18302 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14705)
                                {
                                    _22960 = false;
                                    break;
                                }
                                uint _18336 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_18336 + 32u) * 4 + 0) != 1u)
                                {
                                    _22960 = false;
                                    break;
                                }
                                uint _22957;
                                _22957 = 0u;
                                for (; _22957 < 4u; _22957++)
                                {
                                    for (uint _22958 = 0u; _22958 < 4u; )
                                    {
                                        _18302[_22957][_22958] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18336 + (_22957 * 4u)) + _22958) * 4 + 0));
                                        _22958++;
                                        continue;
                                    }
                                }
                                _22960 = true;
                                break;
                            } while(false);
                            if (_22960)
                            {
                                _22961 = _18302;
                                break;
                            }
                            _22961 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _22962;
                        do
                        {
                            float _18416 = 1.0f - _18191.y;
                            float4 _18427 = mul(float4((float2(_18191.x, _18416) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18191 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18288_dummy_parameter))))), 0)).x, 1.0f), _22961);
                            float _18429 = _18427.w;
                            if (!(_18429 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22962 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18442 = ((_18427.xy / _18429.xx) + 1.0f.xx) * 0.5f;
                            _22962 = float2(_18442.x - _18191.x, _18416 - _18442.y);
                            break;
                        } while(false);
                        float2 _18239 = abs(_22962);
                        if (any(bool2(_18239.x > 100000.0f.xx.x, _18239.y > 100000.0f.xx.y)))
                        {
                            _22963 = false;
                            break;
                        }
                        float _18247 = length(_22962 * _7049);
                        uint _18462_dummy_parameter;
                        bool _18261 = _18247 > ((8.0f * _7049.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _18268;
                        if (_18261)
                        {
                            _18268 = length((r_motion_tp1.Load(int3(int2(floor(_18191 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18462_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7049) < (0.20000000298023223876953125f * _18247);
                        }
                        else
                        {
                            _18268 = _18261;
                        }
                        _22963 = _18268;
                        break;
                    } while(false);
                    if (_22963)
                    {
                        uint _18493_dummy_parameter;
                        _22982 = -(r_motion_tp1.Load(int3(int2(floor(_18191 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18493_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _18520_dummy_parameter;
                    float4x4 _22976;
                    do
                    {
                        bool _22975;
                        do
                        {
                            _18534 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if (_14705)
                            {
                                _22975 = false;
                                break;
                            }
                            uint _18568 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_18568 + 32u) * 4 + 0) != 1u)
                            {
                                _22975 = false;
                                break;
                            }
                            uint _22972;
                            _22972 = 0u;
                            for (; _22972 < 4u; _22972++)
                            {
                                for (uint _22973 = 0u; _22973 < 4u; )
                                {
                                    _18534[_22972][_22973] = asfloat(rw_nfru_diagnostics.Load<uint>((((_18568 + 16u) + (_22972 * 4u)) + _22973) * 4 + 0));
                                    _22973++;
                                    continue;
                                }
                            }
                            _22975 = true;
                            break;
                        } while(false);
                        if (_22975)
                        {
                            _22976 = _18534;
                            break;
                        }
                        _22976 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _22981;
                    do
                    {
                        float _18648 = 1.0f - _18191.y;
                        float4 _18659 = mul(float4((float2(_18191.x, _18648) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18191 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18520_dummy_parameter))))), 0)).x, 1.0f), _22976);
                        float _18661 = _18659.w;
                        if (!(_18661 > 9.9999999747524270787835121154785e-07f))
                        {
                            _22981 = 1000000.0f.xx;
                            break;
                        }
                        float2 _18674 = ((_18659.xy / _18661.xx) + 1.0f.xx) * 0.5f;
                        _22981 = float2(_18674.x - _18191.x, _18648 - _18674.y);
                        break;
                    } while(false);
                    float2 _18206 = abs(_22981);
                    bool2 _18210 = any(bool2(_18206.x > 4.0f.xx.x, _18206.y > 4.0f.xx.y)).xx;
                    _22982 = float2(_18210.x ? 0.0f.xx.x : _22981.x, _18210.y ? 0.0f.xx.y : _22981.y);
                    break;
                } while(false);
                bool _18692 = all(bool2(_22956.x > 0.0f.xx.x, _22956.y > 0.0f.xx.y));
                bool _18698;
                if (_18692)
                {
                    _18698 = all(bool2(_22956.x < 1.0f.xx.x, _22956.y < 1.0f.xx.y));
                }
                else
                {
                    _18698 = _18692;
                }
                float _22998;
                if (_18698)
                {
                    _22998 = length(((_22956 + (_22982 * cbFI_Timestep)) - _5362) * float2(cbFI_RenderSize));
                }
                else
                {
                    _22998 = 1000000000.0f;
                }
                uint _18725_dummy_parameter;
                float _18749 = log((r_depth_tm1.Load(int3(int2(floor(_18191 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18725_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _16948 = _22998 < 0.3499999940395355224609375f;
                bool _16950 = _21732 < 0.3499999940395355224609375f;
                bool _16960;
                if (_16948)
                {
                    _16960 = (!_16950) || (_18749 > _23023);
                }
                else
                {
                    _16960 = _16948;
                }
                bool _16973;
                if (!_16960)
                {
                    _16973 = ((!_16948) && (!_16950)) && (_22998 < _21732);
                }
                else
                {
                    _16973 = _16960;
                }
                _23671 = _16973 ? _18749 : _23023;
                bool2 _23672 = _16973.xx;
                _23673 = float2(_23672.x ? _22956.x : _21733.x, _23672.y ? _22956.y : _21733.y);
                _23674 = _16973 ? _22998 : _21732;
            }
            float3 _18758 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21702, 0.0f).xyz;
            float3 _18766 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21733, 0.0f).xyz;
            uint _18773_dummy_parameter;
            uint _18804_dummy_parameter;
            float _14586 = exp((_21701 * (-2.0f)) * (_21701 * 2.0f));
            float _14593 = exp((_21732 * (-2.0f)) * (_21732 * 2.0f));
            float _14606 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21733, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18804_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21702, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18773_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
            float _14620 = ((_14586 * cbFI_Timestep) * ((1.0f - _14593) + ((_14593 * 2.0f) * _14606))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
            float _14630 = 1.0f - _14606;
            float _14637 = ((_14593 * _5587) * ((1.0f - _14586) + ((_14586 * 2.0f) * _14630))) + (9.9999997473787516355514526367188e-05f * _5587);
            float _14646 = (((_14586 * _14593) * 4.0f) * _14606) * _14630;
            _22935 = (_14646 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18766 - _18758, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14646)) * max(_14586, _14593));
            _22859 = ((_18758 * _14620) + (_18766 * _14637)) / (_14620 + _14637).xxx;
        }
        else
        {
            _22935 = 1.0f;
            _22859 = _22860;
        }
        uint _7061 = cbFI_pad0 & 255u;
        bool _22704;
        float3 _22858;
        if (_7061 != 0u)
        {
            float3 _7066 = r_present_backbuffer.Load(int3(_4856, 0)).xyz;
            float3 _7070 = r_current_interpolation_source.Load(int3(_4856, 0)).xyz;
            float3 _7074 = abs(_7066 - _7070);
            float3 _21734;
            if (_7061 == 2u)
            {
                _21734 = (abs(_7070) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21734 = 0.000244140625f.xxx;
            }
            bool _7090 = any(bool3(_7074.x > _21734.x, _7074.y > _21734.y, _7074.z > _21734.z));
            bool3 _23675 = _7090.xxx;
            _22858 = float3(_23675.x ? _7066.x : _22859.x, _23675.y ? _7066.y : _22859.y, _23675.z ? _7066.z : _22859.z);
            _22704 = _7090;
        }
        else
        {
            _22858 = _22859;
            _22704 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18842;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18842);
        }
        float3 _22840;
        if (_6735 == 1u)
        {
            _22840 = lerp(_8587, _8595, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22841;
            if (_6735 == 2u)
            {
                _22841 = lerp(_8603, _8611, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22842;
                if (_6735 == 3u)
                {
                    _22842 = float(_22704).xxx;
                }
                else
                {
                    float3 _22843;
                    if (_6735 == 4u)
                    {
                        _22843 = float3(((_19762 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22844;
                        if (_6735 == 5u)
                        {
                            _22844 = float3(((_7882 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22845;
                            if (_6735 == 6u)
                            {
                                _22845 = float3(_21268.xy, _21268.z + _21268.w);
                            }
                            else
                            {
                                float3 _22846;
                                if (_6735 == 7u)
                                {
                                    _22846 = r_current_interpolation_source.Load(int3(_4856, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22847;
                                    if (_6735 == 8u)
                                    {
                                        _22847 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5362, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22848;
                                        if (_6739)
                                        {
                                            uint _18864_dummy_parameter;
                                            uint _18896_dummy_parameter;
                                            _22848 = float3(log((r_depth_tp1.Load(int3(int2(floor(_5362 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18864_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_5362 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18896_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22849;
                                            if (_6742)
                                            {
                                                _22849 = _8603;
                                            }
                                            else
                                            {
                                                float3 _22850;
                                                if (_6735 == 20u)
                                                {
                                                    _22850 = _8587;
                                                }
                                                else
                                                {
                                                    float3 _22851;
                                                    if (_6735 == 21u)
                                                    {
                                                        _22851 = _8595;
                                                    }
                                                    else
                                                    {
                                                        float3 _22852;
                                                        if (_6735 == 22u)
                                                        {
                                                            _22852 = _8611;
                                                        }
                                                        else
                                                        {
                                                            float3 _22853;
                                                            if (_6735 == 18u)
                                                            {
                                                                _22853 = _22266;
                                                            }
                                                            else
                                                            {
                                                                float3 _22854;
                                                                if (_6735 == 19u)
                                                                {
                                                                    _22854 = _22001;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22855;
                                                                    if (_6735 == 23u)
                                                                    {
                                                                        _22855 = _21742;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22856;
                                                                        if (_6735 == 24u)
                                                                        {
                                                                            uint _7234 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7239 = float(rw_nfru_diagnostics.Load<uint>((_7234 + 35u) * 4 + 0));
                                                                            float _21735;
                                                                            if (_7239 > 0.0f)
                                                                            {
                                                                                _21735 = float(rw_nfru_diagnostics.Load<uint>((_7234 + 34u) * 4 + 0)) / _7239;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21735 = 0.0f;
                                                                            }
                                                                            _22856 = float3(float(rw_nfru_diagnostics.Load<uint>((_7234 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7234 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21735);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22856 = _22858;
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
                                            _22848 = _22849;
                                        }
                                        _22847 = _22848;
                                    }
                                    _22846 = _22847;
                                }
                                _22845 = _22846;
                            }
                            _22844 = _22845;
                        }
                        _22843 = _22844;
                    }
                    _22842 = _22843;
                }
                _22841 = _22842;
            }
            _22840 = _22841;
        }
        float3 _22839;
        if ((_6735 >= 9u) && (_6735 <= 11u))
        {
            uint _7299 = 64u + uint((_19985.y * cbFI_MvDepthLaneSize.x) + _19985.x);
            uint _7303 = rw_nfru_diagnostics.Load<uint>(_7299 * 4 + 0) & 15u;
            float3 _22873;
            if (_6735 == 10u)
            {
                float3 _22838;
                if ((rw_nfru_diagnostics.Load<uint>(_7299 * 4 + 0) & 32u) != 0u)
                {
                    _22838 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22837;
                    if ((rw_nfru_diagnostics.Load<uint>(_7299 * 4 + 0) & 16u) != 0u)
                    {
                        _22837 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7324 = ((rw_nfru_diagnostics.Load<uint>(_7299 * 4 + 0) & 64u) != 0u).xxx;
                        _22837 = float3(_7324.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7324.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7324.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22838 = _22837;
                }
                _22873 = _22838;
            }
            else
            {
                float3 _22874;
                if (_6735 == 11u)
                {
                    uint _7337 = (rw_nfru_diagnostics.Load<uint>(_7299 * 4 + 0) >> 8u) & 15u;
                    uint _7340 = (rw_nfru_diagnostics.Load<uint>(_7299 * 4 + 0) >> 12u) & 15u;
                    float3 _22830;
                    if ((_7303 == 2u) || (_7303 == 3u))
                    {
                        _22830 = _4538[_7303];
                    }
                    else
                    {
                        bool _7352 = _7337 == 3u;
                        bool _7354 = _7340 == 3u;
                        float3 _22831;
                        if (_7352 && _7354)
                        {
                            _22831 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22832;
                            if (_7352)
                            {
                                _22832 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22833;
                                if (_7354)
                                {
                                    _22833 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22834;
                                    if ((_7337 == 4u) || (_7340 == 4u))
                                    {
                                        _22834 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22835;
                                        if ((_7337 == 1u) || (_7340 == 1u))
                                        {
                                            _22835 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23677 = (_7303 == 1u).xxx;
                                            _22835 = float3(_23677.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23677.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23677.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22834 = _22835;
                                    }
                                    _22833 = _22834;
                                }
                                _22832 = _22833;
                            }
                            _22831 = _22832;
                        }
                        _22830 = _22831;
                    }
                    _22874 = _22830;
                }
                else
                {
                    _22874 = _4538[min(_7303, 7u)];
                }
                _22873 = _22874;
            }
            _22839 = _22873;
        }
        else
        {
            _22839 = _22840;
        }
        float4 _22877;
        if ((_6735 >= 14u) && (_6735 <= 16u))
        {
            float2 _22875;
            if (_6735 == 14u)
            {
                uint _7410_dummy_parameter;
                uint _7416_dummy_parameter;
                _22875 = r_flow_tm1.Load(int3(clamp(int2(floor(_5362 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7410_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7416_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22876;
                if (_6735 == 16u)
                {
                    uint _18972 = r_warped_flow_qdata_tm1.Load(int3(_5378, 0)).x & 2147483647u;
                    uint _19004 = uint(max((int((_18972 >> 16u) & 15u) - 6), 0));
                    _22876 = ((float2(float((1 - (2 * int((_18972 >> 15u) & 1u))) * int(((_18972 >> uint(7)) & 127u) << _19004)), float((1 - (2 * int((_18972 >> 14u) & 1u))) * int((_18972 & 127u) << _19004))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22876 = _7882 * float2(cbFI_DisplaySize);
                }
                _22875 = _22876;
            }
            uint2 _7449 = uint2(clamp(round(_22875 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7451 = _7449.x;
            uint _7458 = _7449.y;
            _22877 = float4(float(_7451 & 255u), float((_7451 >> 8u) | ((_7458 & 15u) << 4u)), float(_7458 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22878;
            if (_6735 == 17u)
            {
                _22878 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5378, 0)).x != 0u), _5822, 0.0f, 1.0f);
            }
            else
            {
                _22878 = float4(_22839, 1.0f);
            }
            _22877 = _22878;
        }
        rw_output[_4856] = _22877.xyz;
        if (_7045)
        {
            uint _19049 = uint((_4856.y * cbFI_DisplaySize.x) + _4856.x) * 2u;
            rw_nfru_select.Store<uint>(_19049 * 4 + 0, spvPackHalf2x16(_22877.xy));
            rw_nfru_select.Store<uint>((_19049 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22877.z, (_22704 || (_6735 != 0u)) ? 2.0f : _22935)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7516 = ((uint(_4856.y) * uint(cbFI_DisplaySize.x)) + uint(_4856.x)) * 6u;
            uint _19075 = spvPackHalf2x16(clamp(_8586.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7516 * 4 + 0, (((_19075 & 32767u) >> 4u) | ((((_19075 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8586.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19110 = spvPackHalf2x16(clamp(_8594.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7516 + 1u) * 4 + 0, (((_19110 & 32767u) >> 4u) | ((((_19110 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8594.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19145 = spvPackHalf2x16(clamp(_8602.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7516 + 2u) * 4 + 0, (((_19145 & 32767u) >> 4u) | ((((_19145 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8602.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19180 = spvPackHalf2x16(clamp(_8610.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7516 + 3u) * 4 + 0, (((_19180 & 32767u) >> 4u) | ((((_19180 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8610.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19207 = r_current_interpolation_source.Load(int3(_4856, 0));
            uint _19221 = spvPackHalf2x16(clamp(_19207.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7516 + 4u) * 4 + 0, (((_19221 & 32767u) >> 4u) | ((((_19221 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19207.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _22954;
            if (_22704 || (_6735 != 0u))
            {
                _22954 = 4294967295u;
            }
            else
            {
                uint _19256 = spvPackHalf2x16(clamp(_22877.xy, 0.0f.xx, 65000.0f.xx));
                _22954 = (((_19256 & 32767u) >> 4u) | ((((_19256 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22877.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7516 + 5u) * 4 + 0, _22954);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4856] = float4(r_current_interpolation_source.Load(int3(_4856, 0)).xyz, 1.0f).xyz;
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
