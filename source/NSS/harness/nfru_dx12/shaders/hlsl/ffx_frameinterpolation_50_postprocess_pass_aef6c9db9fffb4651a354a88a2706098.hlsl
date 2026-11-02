static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1090[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1099[5] = { 2, 4, 7, 11, 16 };
static const float3 _3676[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3963 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3963.x >= cbFI_DisplaySize.x, _3963.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3963] = float4(r_present_backbuffer.Load(int3(_3963, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4409 = (float2(_3963) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4411 = float2(cbFI_MvDepthLaneSize);
        int2 _4420 = int2(floor(_4409 * _4411));
        int2 _4425 = int2(floor(_4409 * float2(cbFI_FlowLaneSize)));
        float4 _6589 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4409 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6595 = r_warped_filled_flow_tm1.Load(int3(_4425, 0)).xy;
        float2 _6601 = r_warped_filled_motion_tp1.Load(int3(_4420, 0)).xy;
        bool _6623 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _12491;
        if (_6623)
        {
            float _6636 = ((2.0f * _4409.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _12491 = float2(atan(_6636) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4409.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6636 * _6636))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _12491 = _4409;
        }
        bool _4446 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _12512;
        bool _12582;
        int2 _12631;
        float3 _14492;
        if (_4446)
        {
            float _12493;
            float _12495;
            _12495 = 2.0f;
            _12493 = -1.0f;
            uint _4030[9];
            float _14992;
            float _14995;
            for (int _12492 = 0; _12492 < 9; _12495 = _14995, _12493 = _14992, _12492++)
            {
                _4030[_12492] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4420 + int2((_12492 % 3) - 1, (_12492 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4030[_12492] != 0u)
                {
                    float _14987;
                    if (_4030[_12492] == 0u)
                    {
                        _14987 = -1.0f;
                    }
                    else
                    {
                        _14987 = float((_4030[_12492] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14995 = min(_12495, _14987);
                    _14992 = max(_12493, _14987);
                }
                else
                {
                    _14995 = _12495;
                    _14992 = _12493;
                }
            }
            float _4492 = float(_12493 >= 0.0f);
            float3 _12194 = 0.0f.xxx;
            _12194.y = _4492;
            float2 _12513;
            bool _12583;
            int2 _12632;
            float3 _14493;
            if ((_12493 - _12495) > 0.0199999995529651641845703125f)
            {
                float _12501;
                int2 _12502;
                float2 _12503;
                int2 _12505;
                float2 _12511;
                _12511 = _6601;
                _12505 = _4420;
                _12503 = _6601;
                _12502 = _4420;
                _12501 = -1.0f;
                float _15000;
                int2 _15004;
                float2 _15015;
                int2 _15026;
                float2 _15059;
                float _15106;
                int _12500 = 0;
                float _14968 = 1000000000.0f;
                for (; _12500 < 9; _14968 = _15106, _12511 = _15059, _12505 = _15026, _12503 = _15015, _12502 = _15004, _12501 = _15000, _12500++)
                {
                    if (_4030[_12500] == 0u)
                    {
                        _15106 = _14968;
                        _15059 = _12511;
                        _15026 = _12505;
                        _15015 = _12503;
                        _15004 = _12502;
                        _15000 = _12501;
                        continue;
                    }
                    int2 _4527 = clamp(_4420 + int2((_12500 % 3) - 1, (_12500 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6711 = _4030[_12500] & 2147483647u;
                    uint _6743 = uint(max((int((_6711 >> 16u) & 15u) - 6), 0));
                    float2 _4533 = (float2(float((1 - (2 * int((_6711 >> 15u) & 1u))) * int(((_6711 >> uint(7)) & 127u) << _6743)), float((1 - (2 * int((_6711 >> 14u) & 1u))) * int((_6711 & 127u) << _6743))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _14954;
                    if (_4030[_12500] == 0u)
                    {
                        _14954 = -1.0f;
                    }
                    else
                    {
                        _14954 = float((_4030[_12500] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4538 = _14954 - 0.100000001490116119384765625f;
                    float2 _14955;
                    if (_6623)
                    {
                        float2 _6820 = clamp((((_12491 + (_4533 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6823 = tan(_6820.x);
                        _14955 = (float2(_6823 / cbFI_DeviceToViewDepth.z, (tan(_6820.y) * sqrt(1.0f + (_6823 * _6823))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _14955 = _12491 + (_4533 * cbFI_Timestep);
                    }
                    float _4545 = cbFI_Timestep - 1.0f;
                    float2 _14956;
                    if (_6623)
                    {
                        float2 _6891 = clamp((((_12491 + (_4533 * _4545)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6894 = tan(_6891.x);
                        _14956 = (float2(_6894 / cbFI_DeviceToViewDepth.z, (tan(_6891.y) * sqrt(1.0f + (_6894 * _6894))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _14956 = _12491 + (_4533 * _4545);
                    }
                    bool _6927 = all(bool2(_14955.x > 0.0f.xx.x, _14955.y > 0.0f.xx.y));
                    bool _6933;
                    if (_6927)
                    {
                        _6933 = all(bool2(_14955.x < 1.0f.xx.x, _14955.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6933 = _6927;
                    }
                    float _14959;
                    if (_6933)
                    {
                        uint _6940_dummy_parameter;
                        _14959 = max((_4538 - (log(((r_depth_tm1.Load(int3(int2(floor(_14955 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6940_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _14959 = 0.0f;
                    }
                    bool _6970 = all(bool2(_14956.x > 0.0f.xx.x, _14956.y > 0.0f.xx.y));
                    bool _6976;
                    if (_6970)
                    {
                        _6976 = all(bool2(_14956.x < 1.0f.xx.x, _14956.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6976 = _6970;
                    }
                    float _14960;
                    if (_6976)
                    {
                        uint _6983_dummy_parameter;
                        _14960 = _14959 + max((_4538 - (log(((r_depth_tp1.Load(int3(int2(floor(_14956 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6983_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _14960 = _14959;
                    }
                    float _15001;
                    int2 _15005;
                    float2 _15016;
                    int2 _15027;
                    float2 _15060;
                    float _15107;
                    if (_14960 == 0.0f)
                    {
                        bool _4580 = _4538 > _12501;
                        bool2 _15115 = _4580.xx;
                        _15107 = _14968;
                        _15060 = float2(_15115.x ? _4533.x : _12511.x, _15115.y ? _4533.y : _12511.y);
                        _15027 = int2(_15115.x ? _4527.x : _12505.x, _15115.y ? _4527.y : _12505.y);
                        _15016 = _12503;
                        _15005 = _12502;
                        _15001 = _4580 ? _4538 : _12501;
                    }
                    else
                    {
                        bool _4589 = _14960 < _14968;
                        bool2 _15111 = _4589.xx;
                        _15107 = _4589 ? _14960 : _14968;
                        _15060 = _12511;
                        _15027 = _12505;
                        _15016 = float2(_15111.x ? _4533.x : _12503.x, _15111.y ? _4533.y : _12503.y);
                        _15005 = int2(_15111.x ? _4527.x : _12502.x, _15111.y ? _4527.y : _12502.y);
                        _15001 = _12501;
                    }
                    _15106 = _15107;
                    _15059 = _15060;
                    _15026 = _15027;
                    _15015 = _15016;
                    _15004 = _15005;
                    _15000 = _15001;
                }
                bool _4601 = _12501 < 0.0f;
                bool2 _15121 = _4601.xx;
                int2 _15124 = int2(_15121.x ? _12502.x : _12505.x, _15121.y ? _12502.y : _12505.y);
                _14493 = float3(1.0f, _4492, float(any(bool2(_15124.x != _4420.x, _15124.y != _4420.y))));
                _12632 = _15124;
                _12583 = _4601 ? false : true;
                _12513 = float2(_15121.x ? _12503.x : _12511.x, _15121.y ? _12503.y : _12511.y);
            }
            else
            {
                _14493 = _12194;
                _12632 = _4420;
                _12583 = false;
                _12513 = _6601;
            }
            _14492 = _14493;
            _12631 = _12632;
            _12582 = _12583;
            _12512 = _12513;
        }
        else
        {
            _14492 = 0.0f.xxx;
            _12631 = _4420;
            _12582 = false;
            _12512 = _6601;
        }
        float2 _12514;
        if (_6623)
        {
            float2 _7048 = clamp((((_12491 + (_12512 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7051 = tan(_7048.x);
            _12514 = (float2(_7051 / cbFI_DeviceToViewDepth.z, (tan(_7048.y) * sqrt(1.0f + (_7051 * _7051))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12514 = _12491 + (_12512 * cbFI_Timestep);
        }
        float _4624 = cbFI_Timestep - 1.0f;
        float2 _12516;
        if (_6623)
        {
            float2 _7119 = clamp((((_12491 + (_12512 * _4624)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7122 = tan(_7119.x);
            _12516 = (float2(_7122 / cbFI_DeviceToViewDepth.z, (tan(_7119.y) * sqrt(1.0f + (_7122 * _7122))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12516 = _12491 + (_12512 * _4624);
        }
        float _4629 = -cbFI_Timestep;
        float2 _12517;
        if (_6623)
        {
            float2 _7190 = clamp((((_12491 + (_6595 * _4629)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7193 = tan(_7190.x);
            _12517 = (float2(_7193 / cbFI_DeviceToViewDepth.z, (tan(_7190.y) * sqrt(1.0f + (_7193 * _7193))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12517 = _12491 + (_6595 * _4629);
        }
        float _4634 = 1.0f - cbFI_Timestep;
        float2 _12518;
        if (_6623)
        {
            float2 _7261 = clamp((((_12491 + (_6595 * _4634)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7264 = tan(_7261.x);
            _12518 = (float2(_7264 / cbFI_DeviceToViewDepth.z, (tan(_7261.y) * sqrt(1.0f + (_7264 * _7264))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12518 = _12491 + (_6595 * _4634);
        }
        float4 _7299 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _12514, 0.0f);
        float3 _7300 = _7299.xyz;
        float4 _7307 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _12516, 0.0f);
        float3 _7308 = _7307.xyz;
        float4 _7315 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _12517, 0.0f);
        float3 _7316 = _7315.xyz;
        float4 _7323 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _12518, 0.0f);
        float3 _7324 = _7323.xyz;
        float4 _7338 = exp(_6589 - max(max(max(_6589.x, _6589.y), _6589.z), _6589.w).xxxx);
        float4 _7345 = _7338 / (dot(_7338, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4650 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _12621;
        float _13727;
        if (_4650)
        {
            float2 _4656 = 0.5f.xx / _4411;
            float _4659 = _4656.x;
            float _4660 = -_4659;
            float _4662 = _4656.y;
            float _4663 = -_4662;
            float2 _4665 = _4409 + float2(_4660, _4663);
            float2 _4667 = float2(cbFI_DisplaySize);
            bool _12530;
            do
            {
                bool _7425 = all(bool2(_4665.x > 0.0f.xx.x, _4665.y > 0.0f.xx.y));
                bool _7431;
                if (_7425)
                {
                    _7431 = all(bool2(_4665.x < 1.0f.xx.x, _4665.y < 1.0f.xx.y));
                }
                else
                {
                    _7431 = _7425;
                }
                if (!_7431)
                {
                    _12530 = false;
                    break;
                }
                uint _7438_dummy_parameter;
                float2 _12529;
                do
                {
                    float _7461 = _4665.x;
                    float _7464 = 1.0f - _4665.y;
                    float4 _7475 = mul(float4((float2(_7461, _7464) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4665 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7438_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7477 = _7475.w;
                    if (!(_7477 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12529 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7490 = ((_7475.xy / _7477.xx) + 1.0f.xx) * 0.5f;
                    _12529 = float2(_7490.x - _7461, _7464 - _7490.y);
                    break;
                } while(false);
                float2 _7389 = abs(_12529);
                if (any(bool2(_7389.x > 100000.0f.xx.x, _7389.y > 100000.0f.xx.y)))
                {
                    _12530 = false;
                    break;
                }
                float _7397 = length(_12529 * _4667);
                uint _7510_dummy_parameter;
                bool _7411 = _7397 > ((8.0f * _4667.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7418;
                if (_7411)
                {
                    _7418 = length((r_motion_tp1.Load(int3(int2(floor(_4665 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7510_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4667) < (0.20000000298023223876953125f * _7397);
                }
                else
                {
                    _7418 = _7411;
                }
                _12530 = _7418;
                break;
            } while(false);
            float2 _4677 = _4409 + float2(_4659, _4663);
            bool _12532;
            do
            {
                bool _7596 = all(bool2(_4677.x > 0.0f.xx.x, _4677.y > 0.0f.xx.y));
                bool _7602;
                if (_7596)
                {
                    _7602 = all(bool2(_4677.x < 1.0f.xx.x, _4677.y < 1.0f.xx.y));
                }
                else
                {
                    _7602 = _7596;
                }
                if (!_7602)
                {
                    _12532 = false;
                    break;
                }
                uint _7609_dummy_parameter;
                float2 _12531;
                do
                {
                    float _7632 = _4677.x;
                    float _7635 = 1.0f - _4677.y;
                    float4 _7646 = mul(float4((float2(_7632, _7635) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4677 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7609_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7648 = _7646.w;
                    if (!(_7648 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12531 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7661 = ((_7646.xy / _7648.xx) + 1.0f.xx) * 0.5f;
                    _12531 = float2(_7661.x - _7632, _7635 - _7661.y);
                    break;
                } while(false);
                float2 _7560 = abs(_12531);
                if (any(bool2(_7560.x > 100000.0f.xx.x, _7560.y > 100000.0f.xx.y)))
                {
                    _12532 = false;
                    break;
                }
                float _7568 = length(_12531 * _4667);
                uint _7681_dummy_parameter;
                bool _7582 = _7568 > ((8.0f * _4667.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7589;
                if (_7582)
                {
                    _7589 = length((r_motion_tp1.Load(int3(int2(floor(_4677 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7681_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4667) < (0.20000000298023223876953125f * _7568);
                }
                else
                {
                    _7589 = _7582;
                }
                _12532 = _7589;
                break;
            } while(false);
            float2 _4690 = _4409 + float2(_4660, _4662);
            bool _12534;
            do
            {
                bool _7767 = all(bool2(_4690.x > 0.0f.xx.x, _4690.y > 0.0f.xx.y));
                bool _7773;
                if (_7767)
                {
                    _7773 = all(bool2(_4690.x < 1.0f.xx.x, _4690.y < 1.0f.xx.y));
                }
                else
                {
                    _7773 = _7767;
                }
                if (!_7773)
                {
                    _12534 = false;
                    break;
                }
                uint _7780_dummy_parameter;
                float2 _12533;
                do
                {
                    float _7803 = _4690.x;
                    float _7806 = 1.0f - _4690.y;
                    float4 _7817 = mul(float4((float2(_7803, _7806) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4690 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7780_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7819 = _7817.w;
                    if (!(_7819 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12533 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7832 = ((_7817.xy / _7819.xx) + 1.0f.xx) * 0.5f;
                    _12533 = float2(_7832.x - _7803, _7806 - _7832.y);
                    break;
                } while(false);
                float2 _7731 = abs(_12533);
                if (any(bool2(_7731.x > 100000.0f.xx.x, _7731.y > 100000.0f.xx.y)))
                {
                    _12534 = false;
                    break;
                }
                float _7739 = length(_12533 * _4667);
                uint _7852_dummy_parameter;
                bool _7753 = _7739 > ((8.0f * _4667.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7760;
                if (_7753)
                {
                    _7760 = length((r_motion_tp1.Load(int3(int2(floor(_4690 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7852_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4667) < (0.20000000298023223876953125f * _7739);
                }
                else
                {
                    _7760 = _7753;
                }
                _12534 = _7760;
                break;
            } while(false);
            float2 _4702 = _4409 + _4656;
            bool _12536;
            do
            {
                bool _7938 = all(bool2(_4702.x > 0.0f.xx.x, _4702.y > 0.0f.xx.y));
                bool _7944;
                if (_7938)
                {
                    _7944 = all(bool2(_4702.x < 1.0f.xx.x, _4702.y < 1.0f.xx.y));
                }
                else
                {
                    _7944 = _7938;
                }
                if (!_7944)
                {
                    _12536 = false;
                    break;
                }
                uint _7951_dummy_parameter;
                float2 _12535;
                do
                {
                    float _7974 = _4702.x;
                    float _7977 = 1.0f - _4702.y;
                    float4 _7988 = mul(float4((float2(_7974, _7977) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4702 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7951_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7990 = _7988.w;
                    if (!(_7990 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12535 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8003 = ((_7988.xy / _7990.xx) + 1.0f.xx) * 0.5f;
                    _12535 = float2(_8003.x - _7974, _7977 - _8003.y);
                    break;
                } while(false);
                float2 _7902 = abs(_12535);
                if (any(bool2(_7902.x > 100000.0f.xx.x, _7902.y > 100000.0f.xx.y)))
                {
                    _12536 = false;
                    break;
                }
                float _7910 = length(_12535 * _4667);
                uint _8023_dummy_parameter;
                bool _7924 = _7910 > ((8.0f * _4667.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7931;
                if (_7924)
                {
                    _7931 = length((r_motion_tp1.Load(int3(int2(floor(_4702 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8023_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4667) < (0.20000000298023223876953125f * _7910);
                }
                else
                {
                    _7931 = _7924;
                }
                _12536 = _7931;
                break;
            } while(false);
            float _4708 = 0.25f * (((float(_12530) + float(_12532)) + float(_12534)) + float(_12536));
            float4 _12622;
            if (_4708 < 1.0f)
            {
                bool _12538;
                do
                {
                    bool _8109 = all(bool2(_12514.x > 0.0f.xx.x, _12514.y > 0.0f.xx.y));
                    bool _8115;
                    if (_8109)
                    {
                        _8115 = all(bool2(_12514.x < 1.0f.xx.x, _12514.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8115 = _8109;
                    }
                    if (!_8115)
                    {
                        _12538 = false;
                        break;
                    }
                    uint _8122_dummy_parameter;
                    float2 _12537;
                    do
                    {
                        float _8148 = 1.0f - _12514.y;
                        float4 _8159 = mul(float4((float2(_12514.x, _8148) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12514 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8122_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8161 = _8159.w;
                        if (!(_8161 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12537 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8174 = ((_8159.xy / _8161.xx) + 1.0f.xx) * 0.5f;
                        _12537 = float2(_8174.x - _12514.x, _8148 - _8174.y);
                        break;
                    } while(false);
                    float2 _8073 = abs(_12537);
                    if (any(bool2(_8073.x > 100000.0f.xx.x, _8073.y > 100000.0f.xx.y)))
                    {
                        _12538 = false;
                        break;
                    }
                    float _8081 = length(_12537 * _4667);
                    uint _8194_dummy_parameter;
                    bool _8095 = _8081 > ((8.0f * _4667.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8102;
                    if (_8095)
                    {
                        _8102 = length((r_motion_tp1.Load(int3(int2(floor(_12514 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8194_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4667) < (0.20000000298023223876953125f * _8081);
                    }
                    else
                    {
                        _8102 = _8095;
                    }
                    _12538 = _8102;
                    break;
                } while(false);
                bool _12540;
                do
                {
                    bool _8280 = all(bool2(_12516.x > 0.0f.xx.x, _12516.y > 0.0f.xx.y));
                    bool _8286;
                    if (_8280)
                    {
                        _8286 = all(bool2(_12516.x < 1.0f.xx.x, _12516.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8286 = _8280;
                    }
                    if (!_8286)
                    {
                        _12540 = false;
                        break;
                    }
                    uint _8293_dummy_parameter;
                    float2 _12539;
                    do
                    {
                        float _8319 = 1.0f - _12516.y;
                        float4 _8330 = mul(float4((float2(_12516.x, _8319) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12516 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8293_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8332 = _8330.w;
                        if (!(_8332 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12539 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8345 = ((_8330.xy / _8332.xx) + 1.0f.xx) * 0.5f;
                        _12539 = float2(_8345.x - _12516.x, _8319 - _8345.y);
                        break;
                    } while(false);
                    float2 _8244 = abs(_12539);
                    if (any(bool2(_8244.x > 100000.0f.xx.x, _8244.y > 100000.0f.xx.y)))
                    {
                        _12540 = false;
                        break;
                    }
                    float _8252 = length(_12539 * _4667);
                    uint _8365_dummy_parameter;
                    bool _8266 = _8252 > ((8.0f * _4667.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8273;
                    if (_8266)
                    {
                        _8273 = length((r_motion_tp1.Load(int3(int2(floor(_12516 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8365_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4667) < (0.20000000298023223876953125f * _8252);
                    }
                    else
                    {
                        _8273 = _8266;
                    }
                    _12540 = _8273;
                    break;
                } while(false);
                bool _12542;
                do
                {
                    bool _8451 = all(bool2(_12517.x > 0.0f.xx.x, _12517.y > 0.0f.xx.y));
                    bool _8457;
                    if (_8451)
                    {
                        _8457 = all(bool2(_12517.x < 1.0f.xx.x, _12517.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8457 = _8451;
                    }
                    if (!_8457)
                    {
                        _12542 = false;
                        break;
                    }
                    uint _8464_dummy_parameter;
                    float2 _12541;
                    do
                    {
                        float _8490 = 1.0f - _12517.y;
                        float4 _8501 = mul(float4((float2(_12517.x, _8490) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12517 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8464_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8503 = _8501.w;
                        if (!(_8503 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12541 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8516 = ((_8501.xy / _8503.xx) + 1.0f.xx) * 0.5f;
                        _12541 = float2(_8516.x - _12517.x, _8490 - _8516.y);
                        break;
                    } while(false);
                    float2 _8415 = abs(_12541);
                    if (any(bool2(_8415.x > 100000.0f.xx.x, _8415.y > 100000.0f.xx.y)))
                    {
                        _12542 = false;
                        break;
                    }
                    float _8423 = length(_12541 * _4667);
                    uint _8536_dummy_parameter;
                    bool _8437 = _8423 > ((8.0f * _4667.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8444;
                    if (_8437)
                    {
                        _8444 = length((r_motion_tp1.Load(int3(int2(floor(_12517 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8536_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4667) < (0.20000000298023223876953125f * _8423);
                    }
                    else
                    {
                        _8444 = _8437;
                    }
                    _12542 = _8444;
                    break;
                } while(false);
                bool _12544;
                do
                {
                    bool _8622 = all(bool2(_12518.x > 0.0f.xx.x, _12518.y > 0.0f.xx.y));
                    bool _8628;
                    if (_8622)
                    {
                        _8628 = all(bool2(_12518.x < 1.0f.xx.x, _12518.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8628 = _8622;
                    }
                    if (!_8628)
                    {
                        _12544 = false;
                        break;
                    }
                    uint _8635_dummy_parameter;
                    float2 _12543;
                    do
                    {
                        float _8661 = 1.0f - _12518.y;
                        float4 _8672 = mul(float4((float2(_12518.x, _8661) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8635_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8674 = _8672.w;
                        if (!(_8674 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12543 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8687 = ((_8672.xy / _8674.xx) + 1.0f.xx) * 0.5f;
                        _12543 = float2(_8687.x - _12518.x, _8661 - _8687.y);
                        break;
                    } while(false);
                    float2 _8586 = abs(_12543);
                    if (any(bool2(_8586.x > 100000.0f.xx.x, _8586.y > 100000.0f.xx.y)))
                    {
                        _12544 = false;
                        break;
                    }
                    float _8594 = length(_12543 * _4667);
                    uint _8707_dummy_parameter;
                    bool _8608 = _8594 > ((8.0f * _4667.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8615;
                    if (_8608)
                    {
                        _8615 = length((r_motion_tp1.Load(int3(int2(floor(_12518 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8707_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4667) < (0.20000000298023223876953125f * _8594);
                    }
                    else
                    {
                        _8615 = _8608;
                    }
                    _12544 = _8615;
                    break;
                } while(false);
                float4 _4735 = _7345 * float4(_12538 ? 0.0f : 1.0f, _12540 ? 0.0f : 1.0f, _12542 ? 0.0f : 1.0f, _12544 ? 0.0f : 1.0f);
                float _4737 = dot(_4735, 1.0f.xxxx);
                float4 _12623;
                if (_4737 > 0.001000000047497451305389404296875f)
                {
                    _12623 = _4735 / _4737.xxxx;
                }
                else
                {
                    _12623 = _7345;
                }
                _12622 = _12623;
            }
            else
            {
                _12622 = _7345;
            }
            _13727 = _4708;
            _12621 = _12622;
        }
        else
        {
            _13727 = 0.0f;
            _12621 = _7345;
        }
        bool _4754 = _4446 && (!_12582);
        bool _4763;
        if (_4754)
        {
            _4763 = (_12621.z + _12621.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4763 = _4754;
        }
        bool _4774;
        if (_4763)
        {
            _4774 = length((_12517 - _12514) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4774 = _4763;
        }
        bool _12678;
        if (_4774)
        {
            uint4 _8736 = r_warped_motion_qdata_tp1.Load(int3(_12631, 0));
            uint _8737 = _8736.x;
            bool _12681;
            if (_8737 != 0u)
            {
                float _12667;
                if (_8737 == 0u)
                {
                    _12667 = -1.0f;
                }
                else
                {
                    _12667 = float((_8737 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4784 = _12667 - 0.12000000476837158203125f;
                bool _8756 = all(bool2(_12517.x > 0.0f.xx.x, _12517.y > 0.0f.xx.y));
                bool _8762;
                if (_8756)
                {
                    _8762 = all(bool2(_12517.x < 1.0f.xx.x, _12517.y < 1.0f.xx.y));
                }
                else
                {
                    _8762 = _8756;
                }
                bool _4794;
                if (_8762)
                {
                    uint _8769_dummy_parameter;
                    _4794 = (log(((r_depth_tm1.Load(int3(int2(floor(_12517 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8769_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4784;
                }
                else
                {
                    _4794 = _8762;
                }
                bool _4808;
                if (!_4794)
                {
                    bool _8799 = all(bool2(_12518.x > 0.0f.xx.x, _12518.y > 0.0f.xx.y));
                    bool _8805;
                    if (_8799)
                    {
                        _8805 = all(bool2(_12518.x < 1.0f.xx.x, _12518.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8805 = _8799;
                    }
                    bool _4806;
                    if (_8805)
                    {
                        uint _8812_dummy_parameter;
                        _4806 = (log(((r_depth_tp1.Load(int3(int2(floor(_12518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8812_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4784;
                    }
                    else
                    {
                        _4806 = _8805;
                    }
                    _4808 = _4806;
                }
                else
                {
                    _4808 = _4794;
                }
                _12681 = _4808;
            }
            else
            {
                _12681 = false;
            }
            _12678 = _12681;
        }
        else
        {
            _12678 = false;
        }
        bool _4813 = _12582 || _12678;
        bool _4818;
        if (_4813)
        {
            bool _8842 = all(bool2(_12514.x > 0.0f.xx.x, _12514.y > 0.0f.xx.y));
            bool _8848;
            if (_8842)
            {
                _8848 = all(bool2(_12514.x < 1.0f.xx.x, _12514.y < 1.0f.xx.y));
            }
            else
            {
                _8848 = _8842;
            }
            _4818 = _8848;
        }
        else
        {
            _4818 = _4813;
        }
        bool _4823;
        if (_4818)
        {
            bool _8853 = all(bool2(_12516.x > 0.0f.xx.x, _12516.y > 0.0f.xx.y));
            bool _8859;
            if (_8853)
            {
                _8859 = all(bool2(_12516.x < 1.0f.xx.x, _12516.y < 1.0f.xx.y));
            }
            else
            {
                _8859 = _8853;
            }
            _4823 = _8859;
        }
        else
        {
            _4823 = _4818;
        }
        float4 _12775;
        if (_4823)
        {
            float _4829 = _12621.x + _12621.y;
            float _4834 = _12621.z + _12621.w;
            float _12696;
            if (_4829 > 0.001000000047497451305389404296875f)
            {
                _12696 = _12621.x / _4829;
            }
            else
            {
                _12696 = _4634;
            }
            _12775 = float4(_12621.x + (_4834 * _12696), _12621.y + (_4834 * (1.0f - _12696)), 0.0f, 0.0f);
        }
        else
        {
            _12775 = _12621;
        }
        bool _8887 = (cbFI_pad0 & 1024u) != 0u;
        bool _8863 = !_8887;
        bool _8864 = !_8863;
        bool _8881;
        if (_8864)
        {
            _8881 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_12631.y * cbFI_MvDepthLaneSize.x) + _12631.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _8881 = _8863;
        }
        bool _8913;
        if (_8864)
        {
            _8913 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4425.y * cbFI_FlowLaneSize.x) + _4425.x)) * 4 + 0) != 0u;
        }
        else
        {
            _8913 = _8863;
        }
        float _4869 = float(_8913);
        bool _12788;
        float4 _12819;
        float3 _14280;
        if (_8887)
        {
            bool _4879;
            if (_8881)
            {
                _4879 = all(bool2(_12514.x > 0.0f.xx.x, _12514.y > 0.0f.xx.y));
            }
            else
            {
                _4879 = _8881;
            }
            bool _4885;
            if (_4879)
            {
                _4885 = all(bool2(_12514.x < 1.0f.xx.x, _12514.y < 1.0f.xx.y));
            }
            else
            {
                _4885 = _4879;
            }
            bool _4892;
            if (_8881)
            {
                _4892 = all(bool2(_12516.x > 0.0f.xx.x, _12516.y > 0.0f.xx.y));
            }
            else
            {
                _4892 = _8881;
            }
            bool _4898;
            if (_4892)
            {
                _4898 = all(bool2(_12516.x < 1.0f.xx.x, _12516.y < 1.0f.xx.y));
            }
            else
            {
                _4898 = _4892;
            }
            bool _4905;
            if (_8913)
            {
                _4905 = all(bool2(_12517.x > 0.0f.xx.x, _12517.y > 0.0f.xx.y));
            }
            else
            {
                _4905 = _8913;
            }
            bool _4911;
            if (_4905)
            {
                _4911 = all(bool2(_12517.x < 1.0f.xx.x, _12517.y < 1.0f.xx.y));
            }
            else
            {
                _4911 = _4905;
            }
            bool _4918;
            if (_8913)
            {
                _4918 = all(bool2(_12518.x > 0.0f.xx.x, _12518.y > 0.0f.xx.y));
            }
            else
            {
                _4918 = _8913;
            }
            bool _4924;
            if (_4918)
            {
                _4924 = all(bool2(_12518.x < 1.0f.xx.x, _12518.y < 1.0f.xx.y));
            }
            else
            {
                _4924 = _4918;
            }
            bool _4926 = !_8881;
            if (_4926)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _8955;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _8955);
                }
            }
            bool _4931 = !_8913;
            if (_4931)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _8965;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _8965);
                }
            }
            if (_8881 && _4931)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _8975;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _8975);
                }
            }
            if (_4926 && _8913)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _8985;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _8985);
                }
            }
            float _4950 = float(_4885);
            float _4952 = float(_4898);
            bool _4955 = _4911 && _4924;
            float _12730;
            if (_4955)
            {
                _12730 = 1.0f;
            }
            else
            {
                _12730 = (_4911 || _4924) ? 0.5f : 0.0f;
            }
            bool _12735;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4885)) && (!_4898))
            {
                bool _4985;
                if (_4955)
                {
                    float _12733;
                    do
                    {
                        bool _9069 = all(bool2(_12517.x > 0.0f.xx.x, _12517.y > 0.0f.xx.y));
                        bool _9075;
                        if (_9069)
                        {
                            _9075 = all(bool2(_12517.x < 1.0f.xx.x, _12517.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _9075 = _9069;
                        }
                        bool _9006 = !_9075;
                        bool _9013;
                        if (!_9006)
                        {
                            bool _9080 = all(bool2(_12518.x > 0.0f.xx.x, _12518.y > 0.0f.xx.y));
                            bool _9086;
                            if (_9080)
                            {
                                _9086 = all(bool2(_12518.x < 1.0f.xx.x, _12518.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _9086 = _9080;
                            }
                            _9013 = !_9086;
                        }
                        else
                        {
                            _9013 = _9006;
                        }
                        if (_9013)
                        {
                            _12733 = 0.0f;
                            break;
                        }
                        uint _9093_dummy_parameter;
                        uint _9109_dummy_parameter;
                        float4 _9034 = mul(float4((float2(_12517.x, 1.0f - _12517.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12517 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9093_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _9036 = _9034.w;
                        if (abs(_9036) < 9.9999999747524270787835121154785e-07f)
                        {
                            _12733 = 0.0f;
                            break;
                        }
                        float _9047 = abs(cbFI_DeviceToViewDepth.y / ((_9034.z / _9036) - cbFI_DeviceToViewDepth.x));
                        float _9050 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9109_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _12733 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9047 - _9050) / max(max(_9047, _9050), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4985 = _12733 >= 0.5f;
                }
                else
                {
                    _4985 = _4955;
                }
                bool _4993;
                if (_4985)
                {
                    _4993 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4993 = _4985;
                }
                bool _12736;
                if (_4993)
                {
                    uint _9159_dummy_parameter;
                    float2 _12734;
                    do
                    {
                        float _9185 = 1.0f - _12517.y;
                        float4 _9196 = mul(float4((float2(_12517.x, _9185) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12517 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9159_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _9198 = _9196.w;
                        if (!(_9198 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12734 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9211 = ((_9196.xy / _9198.xx) + 1.0f.xx) * 0.5f;
                        _12734 = float2(_9211.x - _12517.x, _9185 - _9211.y);
                        break;
                    } while(false);
                    float2 _5006 = float2(cbFI_DisplaySize);
                    _12736 = length(((_12517 + _12734) - _12518) * _5006) <= ((0.100000001490116119384765625f * length(_12734 * _5006)) + 8.0f);
                }
                else
                {
                    _12736 = _4985;
                }
                _12735 = _12736;
            }
            else
            {
                _12735 = true;
            }
            bool _5020 = !_12735;
            bool _15125 = _5020 ? false : _4924;
            bool _15126 = _5020 ? false : _4911;
            bool _12789;
            float4 _12820;
            if (!(((_4885 && _4898) && _15126) && _15125))
            {
                float4 _5042 = _12775 * float4(_4950, _4952, float(_15126), float(_15125));
                float _5044 = dot(_5042, 1.0f.xxxx);
                bool _5047 = !(_5044 > 0.0f);
                float4 _12821;
                if (!_5047)
                {
                    _12821 = _5042 / _5044.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9233;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9233);
                    }
                    _12821 = 0.0f.xxxx;
                }
                _12820 = _12821;
                _12789 = _5047;
            }
            else
            {
                _12820 = _12775;
                _12789 = false;
            }
            _14280 = float3(_4950, _4952, _12730);
            _12819 = _12820;
            _12788 = _12789;
        }
        else
        {
            _14280 = float3(float(_8881), _4869, 0.0f);
            _12819 = _12775;
            _12788 = false;
        }
        bool _5065 = !_12788;
        float4 _12904;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5065)
        {
            float _5072 = _12819.x + _12819.y;
            float4 _12905;
            if (_5072 > 0.001000000047497451305389404296875f)
            {
                _12905 = float4(_12819.x / _5072, _12819.y / _5072, 0.0f, 0.0f);
            }
            else
            {
                _12905 = float4(_4634, cbFI_Timestep, 0.0f, 0.0f);
            }
            _12904 = _12905;
        }
        else
        {
            _12904 = _12819;
        }
        float4 _13081;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5065) && _8881)
        {
            float _12878;
            do
            {
                uint4 _9373 = r_warped_motion_qdata_tp1.Load(int3(_12631, 0));
                uint _9374 = _9373.x;
                if (_9374 != 0u)
                {
                    float _12877;
                    if (_9374 == 0u)
                    {
                        _12877 = -1.0f;
                    }
                    else
                    {
                        _12877 = float((_9374 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12878 = _12877;
                    break;
                }
                int _12860;
                uint _12861;
                _12861 = _9374;
                _12860 = -1;
                uint _12876;
                for (; _12860 <= 1; _12861 = _12876, _12860++)
                {
                    _12876 = _12861;
                    for (int _12874 = -1; _12874 <= 1; )
                    {
                        _12876 = max(_12876, r_warped_motion_qdata_tp1.Load(int3(clamp(_12631 + int2(_12874, _12860), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _12874++;
                        continue;
                    }
                }
                if (_12861 != 0u)
                {
                    float _12873;
                    if (_12861 == 0u)
                    {
                        _12873 = -1.0f;
                    }
                    else
                    {
                        _12873 = float((_12861 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12878 = _12873;
                    break;
                }
                uint _12863;
                _12863 = 4294967295u;
                uint _15096;
                for (int _12862 = 0; _12862 < 8; _12863 = _15096, _12862++)
                {
                    int _12866 = 0;
                    for (;;)
                    {
                        if (_12866 < 5)
                        {
                            int2 _9324 = _12631 + (_1090[_12862] * _1099[_12866].xx);
                            bool _9327 = any(bool2(_9324.x < int2(0, 0).x, _9324.y < int2(0, 0).y));
                            bool _9335;
                            if (!_9327)
                            {
                                _9335 = any(bool2(_9324.x >= cbFI_MvDepthLaneSize.x, _9324.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _9335 = _9327;
                            }
                            if (_9335)
                            {
                                _15096 = _12863;
                                break;
                            }
                            uint4 _9413 = r_warped_motion_qdata_tp1.Load(int3(_9324, 0));
                            uint _9414 = _9413.x;
                            if (_9414 != 0u)
                            {
                                _15096 = min(_12863, _9414);
                                break;
                            }
                            _12866++;
                            continue;
                        }
                        else
                        {
                            _15096 = _12863;
                            break;
                        }
                    }
                }
                float _12865;
                if (_12863 == 4294967295u)
                {
                    _12865 = -1.0f;
                }
                else
                {
                    float _12864;
                    if (_12863 == 0u)
                    {
                        _12864 = -1.0f;
                    }
                    else
                    {
                        _12864 = float((_12863 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12865 = _12864;
                }
                _12878 = _12865;
                break;
            } while(false);
            float _5108 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5111 = r_warped_motion_qdata_tp1.Load(int3(_12631, 0)).x == 0u;
            bool _5117;
            if (_5111)
            {
                bool _9439 = all(bool2(_12514.x > 0.0f.xx.x, _12514.y > 0.0f.xx.y));
                bool _9445;
                if (_9439)
                {
                    _9445 = all(bool2(_12514.x < 1.0f.xx.x, _12514.y < 1.0f.xx.y));
                }
                else
                {
                    _9445 = _9439;
                }
                _5117 = _9445;
            }
            else
            {
                _5117 = _5111;
            }
            bool _5122;
            if (_5117)
            {
                bool _9450 = all(bool2(_12516.x > 0.0f.xx.x, _12516.y > 0.0f.xx.y));
                bool _9456;
                if (_9450)
                {
                    _9456 = all(bool2(_12516.x < 1.0f.xx.x, _12516.y < 1.0f.xx.y));
                }
                else
                {
                    _9456 = _9450;
                }
                _5122 = _9456;
            }
            else
            {
                _5122 = _5117;
            }
            bool _12890;
            float4 _12899;
            if (_5122)
            {
                uint _9463_dummy_parameter;
                float _9487 = log(((r_depth_tm1.Load(int3(int2(floor(_12514 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9463_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _9495_dummy_parameter;
                float _9519 = log(((r_depth_tp1.Load(int3(int2(floor(_12516 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9495_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _5133 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5140;
                if (_5133)
                {
                    _5140 = _9519 > (_9487 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5140 = _5133;
                }
                bool _12895;
                float4 _12917;
                if (_5140)
                {
                    _12917 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _12895 = true;
                }
                else
                {
                    bool _5146 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5153;
                    if (_5146)
                    {
                        _5153 = _9487 > (_9519 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5153 = _5146;
                    }
                    bool4 _15127 = _5153.xxxx;
                    _12917 = float4(_15127.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _12904.x, _15127.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _12904.y, _15127.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _12904.z, _15127.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _12904.w);
                    _12895 = _5153 ? true : false;
                }
                _12899 = _12917;
                _12890 = _12895;
            }
            else
            {
                _12899 = _12904;
                _12890 = false;
            }
            float4 _12972;
            if (_12890)
            {
                _12972 = 1.0f.xxxx;
            }
            else
            {
                bool _5164 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5170;
                if (_5164)
                {
                    _5170 = _12899.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5170 = _5164;
                }
                bool _5175;
                if (_5170)
                {
                    bool _9525 = all(bool2(_12516.x > 0.0f.xx.x, _12516.y > 0.0f.xx.y));
                    bool _9531;
                    if (_9525)
                    {
                        _9531 = all(bool2(_12516.x < 1.0f.xx.x, _12516.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9531 = _9525;
                    }
                    _5175 = _9531;
                }
                else
                {
                    _5175 = _5170;
                }
                float4 _12973;
                if (_5175)
                {
                    float _12926;
                    if (_12878 >= 0.0f)
                    {
                        _12926 = _12878 - _5108;
                    }
                    else
                    {
                        float _12922;
                        _12922 = 2.0f;
                        float _9588;
                        for (int _12921 = 0; _12921 < 24; _12922 = _9588, _12921++)
                        {
                            float _9552 = float(_12921 & 7) * 0.785398185253143310546875f;
                            int _9554 = _12921 >> 3;
                            int _12923;
                            if (_9554 == 0)
                            {
                                _12923 = 16;
                            }
                            else
                            {
                                _12923 = (_9554 == 1) ? 48 : 96;
                            }
                            uint _9620_dummy_parameter;
                            _9588 = min(_12922, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_12516 + ((cbFI_MvDepthLaneSizeRcp * float(_12923)) * float2(cos(_9552), sin(_9552))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9620_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _12926 = _12922;
                    }
                    uint _9652_dummy_parameter;
                    float4 _12974;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_12516 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9652_dummy_parameter))))), 0)).x) > ((exp((_12926 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _12974 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _12974 = 1.0f.xxxx;
                    }
                    _12973 = _12974;
                }
                else
                {
                    _12973 = 1.0f.xxxx;
                }
                _12972 = _12973;
            }
            bool _5203 = _12878 >= 0.0f;
            bool _5204 = (!_12890) && _5203;
            bool _5211;
            if (_5204)
            {
                _5211 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5211 = _5204;
            }
            bool _5217;
            if (_5211)
            {
                _5217 = _12899.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5217 = _5211;
            }
            bool _5222;
            if (_5217)
            {
                bool _9677 = all(bool2(_12514.x > 0.0f.xx.x, _12514.y > 0.0f.xx.y));
                bool _9683;
                if (_9677)
                {
                    _9683 = all(bool2(_12514.x < 1.0f.xx.x, _12514.y < 1.0f.xx.y));
                }
                else
                {
                    _9683 = _9677;
                }
                _5222 = _9683;
            }
            else
            {
                _5222 = _5217;
            }
            float4 _12997;
            if (_5222)
            {
                float _12966;
                if (_5203)
                {
                    _12966 = _12878 - _5108;
                }
                else
                {
                    float _12962;
                    _12962 = 2.0f;
                    float _9740;
                    for (int _12961 = 0; _12961 < 24; _12962 = _9740, _12961++)
                    {
                        float _9704 = float(_12961 & 7) * 0.785398185253143310546875f;
                        int _9706 = _12961 >> 3;
                        int _12963;
                        if (_9706 == 0)
                        {
                            _12963 = 16;
                        }
                        else
                        {
                            _12963 = (_9706 == 1) ? 48 : 96;
                        }
                        uint _9756_dummy_parameter;
                        _9740 = min(_12962, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_12514 + ((cbFI_MvDepthLaneSizeRcp * float(_12963)) * float2(cos(_9704), sin(_9704))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9756_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _12966 = _12962;
                }
                uint _9804_dummy_parameter;
                float4 _12998;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_12514 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9804_dummy_parameter))))), 0)).x) > ((exp((_12966 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _12346 = _12972;
                    _12346.x = 0.0f;
                    _12998 = _12346;
                }
                else
                {
                    _12998 = _12972;
                }
                _12997 = _12998;
            }
            else
            {
                _12997 = _12972;
            }
            float4 _13010;
            if (_5204)
            {
                float _9831 = (exp(((_12878 - _5108) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5260 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5266;
                if (_5260)
                {
                    _5266 = _12899.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5266 = _5260;
                }
                bool _5271;
                if (_5266)
                {
                    bool _9836 = all(bool2(_12518.x > 0.0f.xx.x, _12518.y > 0.0f.xx.y));
                    bool _9842;
                    if (_9836)
                    {
                        _9842 = all(bool2(_12518.x < 1.0f.xx.x, _12518.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9842 = _9836;
                    }
                    _5271 = _9842;
                }
                else
                {
                    _5271 = _5266;
                }
                bool _5279;
                if (_5271)
                {
                    uint _9849_dummy_parameter;
                    _5279 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_12518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9849_dummy_parameter))))), 0)).x) > _9831;
                }
                else
                {
                    _5279 = _5271;
                }
                float4 _13008;
                if (_5279)
                {
                    float4 _12349 = _12997;
                    _12349.w = 0.0f;
                    _13008 = _12349;
                }
                else
                {
                    _13008 = _12997;
                }
                bool _5286 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5292;
                if (_5286)
                {
                    _5292 = _12899.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5292 = _5286;
                }
                bool _5297;
                if (_5292)
                {
                    bool _9867 = all(bool2(_12517.x > 0.0f.xx.x, _12517.y > 0.0f.xx.y));
                    bool _9873;
                    if (_9867)
                    {
                        _9873 = all(bool2(_12517.x < 1.0f.xx.x, _12517.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9873 = _9867;
                    }
                    _5297 = _9873;
                }
                else
                {
                    _5297 = _5292;
                }
                bool _5305;
                if (_5297)
                {
                    uint _9880_dummy_parameter;
                    _5305 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_12517 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9880_dummy_parameter))))), 0)).x) > _9831;
                }
                else
                {
                    _5305 = _5297;
                }
                float4 _13011;
                if (_5305)
                {
                    float4 _12352 = _13008;
                    _12352.z = 0.0f;
                    _13011 = _12352;
                }
                else
                {
                    _13011 = _13008;
                }
                _13010 = _13011;
            }
            else
            {
                _13010 = _12997;
            }
            float4 _13082;
            if (any(bool4(_13010.x < 1.0f.xxxx.x, _13010.y < 1.0f.xxxx.y, _13010.z < 1.0f.xxxx.z, _13010.w < 1.0f.xxxx.w)))
            {
                float4 _5316 = _12899 * _13010;
                float _5318 = dot(_5316, 1.0f.xxxx);
                float4 _13083;
                if (_5318 > 0.0f)
                {
                    _13083 = _5316 / _5318.xxxx;
                }
                else
                {
                    bool _5329 = _13010.y == 0.0f;
                    bool _5335;
                    if (_5329)
                    {
                        _5335 = _13010.x > 0.0f;
                    }
                    else
                    {
                        _5335 = _5329;
                    }
                    bool _5340;
                    if (_5335)
                    {
                        bool _9898 = all(bool2(_12514.x > 0.0f.xx.x, _12514.y > 0.0f.xx.y));
                        bool _9904;
                        if (_9898)
                        {
                            _9904 = all(bool2(_12514.x < 1.0f.xx.x, _12514.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _9904 = _9898;
                        }
                        _5340 = _9904;
                    }
                    else
                    {
                        _5340 = _5335;
                    }
                    float4 _13084;
                    if (_5340)
                    {
                        _13084 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5345 = _13010.x == 0.0f;
                        bool _5351;
                        if (_5345)
                        {
                            _5351 = _13010.y > 0.0f;
                        }
                        else
                        {
                            _5351 = _5345;
                        }
                        bool _5356;
                        if (_5351)
                        {
                            bool _9909 = all(bool2(_12516.x > 0.0f.xx.x, _12516.y > 0.0f.xx.y));
                            bool _9915;
                            if (_9909)
                            {
                                _9915 = all(bool2(_12516.x < 1.0f.xx.x, _12516.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _9915 = _9909;
                            }
                            _5356 = _9915;
                        }
                        else
                        {
                            _5356 = _5351;
                        }
                        bool4 _15130 = _5356.xxxx;
                        _13084 = float4(_15130.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _12899.x, _15130.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _12899.y, _15130.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _12899.z, _15130.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _12899.w);
                    }
                    _13083 = _13084;
                }
                _13082 = _13083;
            }
            else
            {
                _13082 = _12899;
            }
            _13081 = _13082;
        }
        else
        {
            _13081 = _12904;
        }
        float4 _13695;
        bool _13957;
        float3 _14074;
        if (((cbFI_pad0 & 32768u) != 0u) && _5065)
        {
            bool _5373 = _13081.x > 0.00999999977648258209228515625f;
            bool _5376 = _13081.y > 0.00999999977648258209228515625f;
            bool _5385 = (_13081.z + _13081.w) > 0.0199999995529651641845703125f;
            bool _5391;
            if (_5385)
            {
                bool _9920 = all(bool2(_12517.x > 0.0f.xx.x, _12517.y > 0.0f.xx.y));
                bool _9926;
                if (_9920)
                {
                    _9926 = all(bool2(_12517.x < 1.0f.xx.x, _12517.y < 1.0f.xx.y));
                }
                else
                {
                    _9926 = _9920;
                }
                _5391 = _9926;
            }
            else
            {
                _5391 = _5385;
            }
            bool _5396;
            if (_5391)
            {
                bool _9931 = all(bool2(_12518.x > 0.0f.xx.x, _12518.y > 0.0f.xx.y));
                bool _9937;
                if (_9931)
                {
                    _9937 = all(bool2(_12518.x < 1.0f.xx.x, _12518.y < 1.0f.xx.y));
                }
                else
                {
                    _9937 = _9931;
                }
                _5396 = _9937;
            }
            else
            {
                _5396 = _5391;
            }
            bool _5403;
            if (_5396)
            {
                float _13092;
                do
                {
                    bool _10020 = all(bool2(_12517.x > 0.0f.xx.x, _12517.y > 0.0f.xx.y));
                    bool _10026;
                    if (_10020)
                    {
                        _10026 = all(bool2(_12517.x < 1.0f.xx.x, _12517.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10026 = _10020;
                    }
                    bool _9957 = !_10026;
                    bool _9964;
                    if (!_9957)
                    {
                        bool _10031 = all(bool2(_12518.x > 0.0f.xx.x, _12518.y > 0.0f.xx.y));
                        bool _10037;
                        if (_10031)
                        {
                            _10037 = all(bool2(_12518.x < 1.0f.xx.x, _12518.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _10037 = _10031;
                        }
                        _9964 = !_10037;
                    }
                    else
                    {
                        _9964 = _9957;
                    }
                    if (_9964)
                    {
                        _13092 = 0.0f;
                        break;
                    }
                    uint _10044_dummy_parameter;
                    uint _10060_dummy_parameter;
                    float4 _9985 = mul(float4((float2(_12517.x, 1.0f - _12517.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12517 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10044_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _9987 = _9985.w;
                    if (abs(_9987) < 9.9999999747524270787835121154785e-07f)
                    {
                        _13092 = 0.0f;
                        break;
                    }
                    float _9998 = abs(cbFI_DeviceToViewDepth.y / ((_9985.z / _9987) - cbFI_DeviceToViewDepth.x));
                    float _10001 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10060_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _13092 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9998 - _10001) / max(max(_9998, _10001), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5403 = _13092 < 0.5f;
            }
            else
            {
                _5403 = _5396;
            }
            float4 _13107;
            if (_5403)
            {
                uint _10110_dummy_parameter;
                uint _10141_dummy_parameter;
                float4 _13108;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_12517 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10110_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10141_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _13108 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _13108 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _13107 = _13108;
            }
            else
            {
                _13107 = 1.0f.xxxx;
            }
            bool _5427;
            if (_8881)
            {
                bool _10170 = all(bool2(_12514.x > 0.0f.xx.x, _12514.y > 0.0f.xx.y));
                bool _10176;
                if (_10170)
                {
                    _10176 = all(bool2(_12514.x < 1.0f.xx.x, _12514.y < 1.0f.xx.y));
                }
                else
                {
                    _10176 = _10170;
                }
                _5427 = _10176;
            }
            else
            {
                _5427 = _8881;
            }
            bool _5433;
            if (_8881)
            {
                bool _10181 = all(bool2(_12516.x > 0.0f.xx.x, _12516.y > 0.0f.xx.y));
                bool _10187;
                if (_10181)
                {
                    _10187 = all(bool2(_12516.x < 1.0f.xx.x, _12516.y < 1.0f.xx.y));
                }
                else
                {
                    _10187 = _10181;
                }
                _5433 = _10187;
            }
            else
            {
                _5433 = _8881;
            }
            bool _5439;
            if (_8913)
            {
                bool _10192 = all(bool2(_12517.x > 0.0f.xx.x, _12517.y > 0.0f.xx.y));
                bool _10198;
                if (_10192)
                {
                    _10198 = all(bool2(_12517.x < 1.0f.xx.x, _12517.y < 1.0f.xx.y));
                }
                else
                {
                    _10198 = _10192;
                }
                _5439 = _10198;
            }
            else
            {
                _5439 = _8913;
            }
            bool _5445;
            if (_8913)
            {
                bool _10203 = all(bool2(_12518.x > 0.0f.xx.x, _12518.y > 0.0f.xx.y));
                bool _10209;
                if (_10203)
                {
                    _10209 = all(bool2(_12518.x < 1.0f.xx.x, _12518.y < 1.0f.xx.y));
                }
                else
                {
                    _10209 = _10203;
                }
                _5445 = _10209;
            }
            else
            {
                _5445 = _8913;
            }
            bool _5448 = _5439 != _5445;
            bool _5454;
            if (_5448)
            {
                _5454 = _5427 || _5433;
            }
            else
            {
                _5454 = _5448;
            }
            float4 _13206;
            if (_5454)
            {
                float4 _12379 = _13107;
                _12379.z = 0.0f;
                _12379.w = 0.0f;
                _13206 = _12379;
            }
            else
            {
                _13206 = _13107;
            }
            bool _5461 = _5427 && _5373;
            bool _5464 = _5433 && _5376;
            float4 _13311;
            float3 _14175;
            if (_5461 || _5464)
            {
                float _13201;
                do
                {
                    uint4 _10348 = r_warped_motion_qdata_tp1.Load(int3(_12631, 0));
                    uint _10349 = _10348.x;
                    if (_10349 != 0u)
                    {
                        float _13200;
                        if (_10349 == 0u)
                        {
                            _13200 = -1.0f;
                        }
                        else
                        {
                            _13200 = float((_10349 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13201 = _13200;
                        break;
                    }
                    int _13183;
                    uint _13184;
                    _13184 = _10349;
                    _13183 = -1;
                    uint _13199;
                    for (; _13183 <= 1; _13184 = _13199, _13183++)
                    {
                        _13199 = _13184;
                        for (int _13197 = -1; _13197 <= 1; )
                        {
                            _13199 = max(_13199, r_warped_motion_qdata_tp1.Load(int3(clamp(_12631 + int2(_13197, _13183), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _13197++;
                            continue;
                        }
                    }
                    if (_13184 != 0u)
                    {
                        float _13196;
                        if (_13184 == 0u)
                        {
                            _13196 = -1.0f;
                        }
                        else
                        {
                            _13196 = float((_13184 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13201 = _13196;
                        break;
                    }
                    uint _13186;
                    _13186 = 4294967295u;
                    uint _15097;
                    for (int _13185 = 0; _13185 < 8; _13186 = _15097, _13185++)
                    {
                        int _13189 = 0;
                        for (;;)
                        {
                            if (_13189 < 5)
                            {
                                int2 _10299 = _12631 + (_1090[_13185] * _1099[_13189].xx);
                                bool _10302 = any(bool2(_10299.x < int2(0, 0).x, _10299.y < int2(0, 0).y));
                                bool _10310;
                                if (!_10302)
                                {
                                    _10310 = any(bool2(_10299.x >= cbFI_MvDepthLaneSize.x, _10299.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _10310 = _10302;
                                }
                                if (_10310)
                                {
                                    _15097 = _13186;
                                    break;
                                }
                                uint4 _10388 = r_warped_motion_qdata_tp1.Load(int3(_10299, 0));
                                uint _10389 = _10388.x;
                                if (_10389 != 0u)
                                {
                                    _15097 = min(_13186, _10389);
                                    break;
                                }
                                _13189++;
                                continue;
                            }
                            else
                            {
                                _15097 = _13186;
                                break;
                            }
                        }
                    }
                    float _13188;
                    if (_13186 == 4294967295u)
                    {
                        _13188 = -1.0f;
                    }
                    else
                    {
                        float _13187;
                        if (_13186 == 0u)
                        {
                            _13187 = -1.0f;
                        }
                        else
                        {
                            _13187 = float((_13186 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13188 = _13187;
                    }
                    _13201 = _13188;
                    break;
                } while(false);
                bool _5472 = _13201 < 0.0f;
                float _13202;
                if (_5472)
                {
                    _13202 = 0.0f;
                }
                else
                {
                    _13202 = _13201 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _10410_dummy_parameter;
                uint _10442_dummy_parameter;
                float4 _13239;
                if ((_5472 && _5461) && _5464)
                {
                    uint _10474_dummy_parameter;
                    float _10498 = log(((r_depth_tm1.Load(int3(int2(floor(_12514 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10474_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _10506_dummy_parameter;
                    float _10530 = log(((r_depth_tp1.Load(int3(int2(floor(_12516 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10506_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _13240;
                    if (_10498 > (_10530 + 0.07999999821186065673828125f))
                    {
                        float4 _12383 = _13206;
                        _12383.x = 0.0f;
                        _13240 = _12383;
                    }
                    else
                    {
                        float4 _13241;
                        if (_10530 > (_10498 + 0.07999999821186065673828125f))
                        {
                            float4 _12385 = _13206;
                            _12385.y = 0.0f;
                            _13241 = _12385;
                        }
                        else
                        {
                            _13241 = _13206;
                        }
                        _13240 = _13241;
                    }
                    _13239 = _13240;
                }
                else
                {
                    _13239 = _13206;
                }
                float _5524 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5526 = _13201 >= 0.0f;
                float _13222;
                if (_5526)
                {
                    _13222 = _13201 - _5524;
                }
                else
                {
                    float _13218;
                    if (_5461)
                    {
                        float _13217;
                        _13217 = 2.0f;
                        float _10588;
                        for (int _13216 = 0; _13216 < 24; _13217 = _10588, _13216++)
                        {
                            float _10552 = float(_13216 & 7) * 0.785398185253143310546875f;
                            int _10554 = _13216 >> 3;
                            int _13219;
                            if (_10554 == 0)
                            {
                                _13219 = 16;
                            }
                            else
                            {
                                _13219 = (_10554 == 1) ? 48 : 96;
                            }
                            uint _10604_dummy_parameter;
                            _10588 = min(_13217, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_12514 + ((cbFI_MvDepthLaneSizeRcp * float(_13219)) * float2(cos(_10552), sin(_10552))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10604_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _13218 = _13217;
                    }
                    else
                    {
                        _13218 = 0.0f;
                    }
                    _13222 = _13218;
                }
                float _13229;
                if (_5526)
                {
                    _13229 = _13201 - _5524;
                }
                else
                {
                    float _13225;
                    if (_5464)
                    {
                        float _13224;
                        _13224 = 2.0f;
                        float _10702;
                        for (int _13223 = 0; _13223 < 24; _13224 = _10702, _13223++)
                        {
                            float _10666 = float(_13223 & 7) * 0.785398185253143310546875f;
                            int _10668 = _13223 >> 3;
                            int _13226;
                            if (_10668 == 0)
                            {
                                _13226 = 16;
                            }
                            else
                            {
                                _13226 = (_10668 == 1) ? 48 : 96;
                            }
                            uint _10734_dummy_parameter;
                            _10702 = min(_13224, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_12516 + ((cbFI_MvDepthLaneSizeRcp * float(_13226)) * float2(cos(_10666), sin(_10666))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10734_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _13225 = _13224;
                    }
                    else
                    {
                        _13225 = 0.0f;
                    }
                    _13229 = _13225;
                }
                float _13230;
                if (_5461)
                {
                    uint _10766_dummy_parameter;
                    _13230 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_12514 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10766_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _13230 = 0.0f;
                }
                float _13231;
                if (_5464)
                {
                    uint _10786_dummy_parameter;
                    _13231 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_12516 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10786_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _13231 = 0.0f;
                }
                bool _5581;
                if (_5461)
                {
                    _5581 = _13230 > ((exp((_13222 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5581 = _5461;
                }
                float4 _13247;
                if (_5581)
                {
                    float4 _12387 = _13239;
                    _12387.x = 0.0f;
                    _13247 = _12387;
                }
                else
                {
                    _13247 = _13239;
                }
                bool _5593;
                if (_5464)
                {
                    _5593 = _13231 > ((exp((_13229 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5593 = _5464;
                }
                float4 _13249;
                if (_5593)
                {
                    float4 _12389 = _13247;
                    _12389.y = 0.0f;
                    _13249 = _12389;
                }
                else
                {
                    _13249 = _13247;
                }
                float4 _13312;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5526)
                {
                    bool _5613;
                    if (_5461)
                    {
                        _5613 = _13230 < ((exp((_13222 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5613 = _5461;
                    }
                    float4 _13251;
                    if (_5613)
                    {
                        float4 _12391 = _13249;
                        _12391.x = 0.0f;
                        _13251 = _12391;
                    }
                    else
                    {
                        _13251 = _13249;
                    }
                    bool _5625;
                    if (_5464)
                    {
                        _5625 = _13231 < ((exp((_13229 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5625 = _5464;
                    }
                    float4 _13313;
                    if (_5625)
                    {
                        float4 _12393 = _13251;
                        _12393.y = 0.0f;
                        _13313 = _12393;
                    }
                    else
                    {
                        _13313 = _13251;
                    }
                    _13312 = _13313;
                }
                else
                {
                    _13312 = _13249;
                }
                _14175 = float3(_13202, log(((r_depth_tm1.Load(int3(int2(floor(_12514 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10410_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_12516 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10442_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _13311 = _13312;
            }
            else
            {
                _14175 = float3(0.0f, 0.0f, 0.5f);
                _13311 = _13206;
            }
            bool _5636 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5385;
            bool _5642;
            if (_5636)
            {
                _5642 = _5439 || _5445;
            }
            else
            {
                _5642 = _5636;
            }
            float4 _13334;
            if (_5642)
            {
                float _13306;
                do
                {
                    uint4 _10966 = r_warped_motion_qdata_tp1.Load(int3(_12631, 0));
                    uint _10967 = _10966.x;
                    if (_10967 != 0u)
                    {
                        float _13305;
                        if (_10967 == 0u)
                        {
                            _13305 = -1.0f;
                        }
                        else
                        {
                            _13305 = float((_10967 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13306 = _13305;
                        break;
                    }
                    int _13288;
                    uint _13289;
                    _13289 = _10967;
                    _13288 = -1;
                    uint _13304;
                    for (; _13288 <= 1; _13289 = _13304, _13288++)
                    {
                        _13304 = _13289;
                        for (int _13302 = -1; _13302 <= 1; )
                        {
                            _13304 = max(_13304, r_warped_motion_qdata_tp1.Load(int3(clamp(_12631 + int2(_13302, _13288), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _13302++;
                            continue;
                        }
                    }
                    if (_13289 != 0u)
                    {
                        float _13301;
                        if (_13289 == 0u)
                        {
                            _13301 = -1.0f;
                        }
                        else
                        {
                            _13301 = float((_13289 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13306 = _13301;
                        break;
                    }
                    uint _13291;
                    _13291 = 4294967295u;
                    uint _15098;
                    for (int _13290 = 0; _13290 < 8; _13291 = _15098, _13290++)
                    {
                        int _13294 = 0;
                        for (;;)
                        {
                            if (_13294 < 5)
                            {
                                int2 _10917 = _12631 + (_1090[_13290] * _1099[_13294].xx);
                                bool _10920 = any(bool2(_10917.x < int2(0, 0).x, _10917.y < int2(0, 0).y));
                                bool _10928;
                                if (!_10920)
                                {
                                    _10928 = any(bool2(_10917.x >= cbFI_MvDepthLaneSize.x, _10917.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _10928 = _10920;
                                }
                                if (_10928)
                                {
                                    _15098 = _13291;
                                    break;
                                }
                                uint4 _11006 = r_warped_motion_qdata_tp1.Load(int3(_10917, 0));
                                uint _11007 = _11006.x;
                                if (_11007 != 0u)
                                {
                                    _15098 = min(_13291, _11007);
                                    break;
                                }
                                _13294++;
                                continue;
                            }
                            else
                            {
                                _15098 = _13291;
                                break;
                            }
                        }
                    }
                    float _13293;
                    if (_13291 == 4294967295u)
                    {
                        _13293 = -1.0f;
                    }
                    else
                    {
                        float _13292;
                        if (_13291 == 0u)
                        {
                            _13292 = -1.0f;
                        }
                        else
                        {
                            _13292 = float((_13291 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13293 = _13292;
                    }
                    _13306 = _13293;
                    break;
                } while(false);
                float4 _13335;
                if (_13306 >= 0.0f)
                {
                    float _11028 = (exp((_13306 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5661;
                    if (_5439)
                    {
                        uint _11035_dummy_parameter;
                        _5661 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_12517 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11035_dummy_parameter))))), 0)).x) > _11028;
                    }
                    else
                    {
                        _5661 = _5439;
                    }
                    float4 _13324;
                    if (_5661)
                    {
                        float4 _12395 = _13311;
                        _12395.z = 0.0f;
                        _13324 = _12395;
                    }
                    else
                    {
                        _13324 = _13311;
                    }
                    bool _5673;
                    if (_5445)
                    {
                        uint _11055_dummy_parameter;
                        _5673 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_12518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11055_dummy_parameter))))), 0)).x) > _11028;
                    }
                    else
                    {
                        _5673 = _5445;
                    }
                    float4 _13336;
                    if (_5673)
                    {
                        float4 _12397 = _13324;
                        _12397.w = 0.0f;
                        _13336 = _12397;
                    }
                    else
                    {
                        _13336 = _13324;
                    }
                    _13335 = _13336;
                }
                else
                {
                    _13335 = _13311;
                }
                _13334 = _13335;
            }
            else
            {
                _13334 = _13311;
            }
            bool _5681 = _5427 != _5433;
            bool _5688;
            if (_5681)
            {
                _5688 = _5427 ? _5373 : _5376;
            }
            else
            {
                _5688 = _5681;
            }
            bool _5695;
            if (_5688)
            {
                _5695 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5695 = _5688;
            }
            float4 _13419;
            if (_5695)
            {
                bool2 _5700 = _5427.xx;
                float2 _5701 = float2(_5700.x ? _12514.x : _12516.x, _5700.y ? _12514.y : _12516.y);
                float _13326;
                if (_5427)
                {
                    uint _11075_dummy_parameter;
                    _13326 = r_depth_tm1.Load(int3(int2(floor(_5701 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11075_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _11091_dummy_parameter;
                    _13326 = r_depth_tp1.Load(int3(int2(floor(_5701 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11091_dummy_parameter))))), 0)).x;
                }
                float4x4 _13327;
                if (_5427)
                {
                    _13327 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _13327 = cbFI_MotionTP1ToTM1;
                }
                float2 _13328;
                do
                {
                    float _11118 = _5701.x;
                    float _11121 = 1.0f - _5701.y;
                    float4 _11132 = mul(float4((float2(_11118, _11121) * 2.0f) - 1.0f.xx, _13326, 1.0f), _13327);
                    float _11134 = _11132.w;
                    if (!(_11134 > 9.9999999747524270787835121154785e-07f))
                    {
                        _13328 = 1000000.0f.xx;
                        break;
                    }
                    float2 _11147 = ((_11132.xy / _11134.xx) + 1.0f.xx) * 0.5f;
                    _13328 = float2(_11147.x - _11118, _11121 - _11147.y);
                    break;
                } while(false);
                float2 _5731 = float2(cbFI_DisplaySize);
                float4 _13420;
                if (!(length(((_5701 + _13328) - float2(_5700.x ? _12516.x : _12514.x, _5700.y ? _12516.y : _12514.y)) * _5731) <= ((0.100000001490116119384765625f * length(_13328 * _5731)) + 8.0f)))
                {
                    float4 _13421;
                    if (_5427)
                    {
                        float4 _12407 = _13334;
                        _12407.x = 0.0f;
                        _13421 = _12407;
                    }
                    else
                    {
                        float4 _12409 = _13334;
                        _12409.y = 0.0f;
                        _13421 = _12409;
                    }
                    _13420 = _13421;
                }
                else
                {
                    _13420 = _13334;
                }
                _13419 = _13420;
            }
            else
            {
                _13419 = _13334;
            }
            float4 _5756 = _13081 * _13419;
            float _5758 = dot(_5756, 1.0f.xxxx);
            float4 _13696;
            bool _13958;
            if (_5758 > 0.0f)
            {
                _13958 = _12788;
                _13696 = _5756 / _5758.xxxx;
            }
            else
            {
                bool _5769 = any(bool4(_13419.x < 1.0f.xxxx.x, _13419.y < 1.0f.xxxx.y, _13419.z < 1.0f.xxxx.z, _13419.w < 1.0f.xxxx.w));
                if (_5769)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11169;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11169);
                    }
                }
                bool4 _15133 = _5769.xxxx;
                _13958 = _5769 ? true : _12788;
                _13696 = float4(_15133.x ? 0.0f.xxxx.x : _13081.x, _15133.y ? 0.0f.xxxx.y : _13081.y, _15133.z ? 0.0f.xxxx.z : _13081.z, _15133.w ? 0.0f.xxxx.w : _13081.w);
            }
            _14074 = _14175;
            _13957 = _13958;
            _13695 = _13696;
        }
        else
        {
            _14074 = float3(0.0f, 0.0f, 0.5f);
            _13957 = _12788;
            _13695 = _13081;
        }
        uint _5778 = (cbFI_pad0 >> 24u) & 31u;
        uint _5782 = (cbFI_pad0 >> 16u) & 255u;
        bool _5784 = _5778 != 0u;
        bool _5786 = _5782 == 12u;
        bool _5789 = _5782 == 13u;
        float4 _13712;
        if ((_5784 || _5786) || _5789)
        {
            float _13422;
            do
            {
                bool _11253 = all(bool2(_12517.x > 0.0f.xx.x, _12517.y > 0.0f.xx.y));
                bool _11259;
                if (_11253)
                {
                    _11259 = all(bool2(_12517.x < 1.0f.xx.x, _12517.y < 1.0f.xx.y));
                }
                else
                {
                    _11259 = _11253;
                }
                bool _11190 = !_11259;
                bool _11197;
                if (!_11190)
                {
                    bool _11264 = all(bool2(_12518.x > 0.0f.xx.x, _12518.y > 0.0f.xx.y));
                    bool _11270;
                    if (_11264)
                    {
                        _11270 = all(bool2(_12518.x < 1.0f.xx.x, _12518.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11270 = _11264;
                    }
                    _11197 = !_11270;
                }
                else
                {
                    _11197 = _11190;
                }
                if (_11197)
                {
                    _13422 = 0.0f;
                    break;
                }
                uint _11277_dummy_parameter;
                uint _11293_dummy_parameter;
                float4 _11218 = mul(float4((float2(_12517.x, 1.0f - _12517.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12517 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11277_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _11220 = _11218.w;
                if (abs(_11220) < 9.9999999747524270787835121154785e-07f)
                {
                    _13422 = 0.0f;
                    break;
                }
                float _11231 = abs(cbFI_DeviceToViewDepth.y / ((_11218.z / _11220) - cbFI_DeviceToViewDepth.x));
                float _11234 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12518 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11293_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _13422 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11231 - _11234) / max(max(_11231, _11234), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _11341 = all(bool2(_12518.x > 0.0f.xx.x, _12518.y > 0.0f.xx.y));
            bool _11347;
            if (_11341)
            {
                _11347 = all(bool2(_12518.x < 1.0f.xx.x, _12518.y < 1.0f.xx.y));
            }
            else
            {
                _11347 = _11341;
            }
            float _13423;
            if (_11347)
            {
                uint _11354_dummy_parameter;
                _13423 = length((_6595 + (r_motion_tp1.Load(int3(int2(floor(_12518 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _11354_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _13423 = 1000000.0f;
            }
            float _13434;
            if ((_5778 & 1u) != 0u)
            {
                _13434 = _13422;
            }
            else
            {
                _13434 = 1.0f;
            }
            float _13435;
            if ((_5778 & 2u) != 0u)
            {
                _13435 = _13434 * (1.0f - smoothstep(2.0f, 8.0f, _13423));
            }
            else
            {
                _13435 = _13434;
            }
            float _13436;
            if ((_5778 & 4u) != 0u)
            {
                _13436 = _13435 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7316 - _7324) - length(_7300 - _7308))));
            }
            else
            {
                _13436 = _13435;
            }
            float _13706;
            if ((_5778 & 8u) != 0u)
            {
                _13706 = lerp(1.0f, _13436, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7300 - _7308)));
            }
            else
            {
                _13706 = _13436;
            }
            bool _5864 = (_5778 & 16u) != 0u;
            bool _5873;
            if (_5864)
            {
                _5873 = length(_12512 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5873 = _5864;
            }
            float _15135 = _5873 ? 1.0f : _13706;
            bool _5879 = _5784 && _8881;
            bool _5884;
            if (_5879)
            {
                bool _11379 = all(bool2(_12514.x > 0.0f.xx.x, _12514.y > 0.0f.xx.y));
                bool _11385;
                if (_11379)
                {
                    _11385 = all(bool2(_12514.x < 1.0f.xx.x, _12514.y < 1.0f.xx.y));
                }
                else
                {
                    _11385 = _11379;
                }
                _5884 = _11385;
            }
            else
            {
                _5884 = _5879;
            }
            bool _5889;
            if (_5884)
            {
                bool _11390 = all(bool2(_12516.x > 0.0f.xx.x, _12516.y > 0.0f.xx.y));
                bool _11396;
                if (_11390)
                {
                    _11396 = all(bool2(_12516.x < 1.0f.xx.x, _12516.y < 1.0f.xx.y));
                }
                else
                {
                    _11396 = _11390;
                }
                _5889 = _11396;
            }
            else
            {
                _5889 = _5884;
            }
            float4 _13713;
            if (_5889)
            {
                float _5895 = _13695.x + _13695.y;
                float _5904 = (_13695.z + _13695.w) * (1.0f - _15135);
                float _13709;
                if (_5895 > 9.9999997473787516355514526367188e-06f)
                {
                    _13709 = _13695.x / _5895;
                }
                else
                {
                    _13709 = _4634;
                }
                _13713 = float4(_13695.x + (_5904 * _13709), _13695.y + (_5904 * (1.0f - _13709)), _13695.zw * _15135);
            }
            else
            {
                _13713 = _13695;
            }
            _13712 = _13713;
        }
        else
        {
            _13712 = _13695;
        }
        float3 _5965 = (((_7300 * _13712.x) + (_7308 * _13712.y)) + (_7316 * _13712.z)) + (_7324 * _13712.w);
        float3 _14900;
        if (_4650 && (_13727 > 0.0f))
        {
            uint _11403_dummy_parameter;
            float2 _11418 = r_motion_tp1.Load(int3(int2(floor(_4409 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _11403_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _13949;
            if (_6623)
            {
                float2 _11463 = clamp((((_12491 + (_11418 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _11466 = tan(_11463.x);
                _13949 = (float2(_11466 / cbFI_DeviceToViewDepth.z, (tan(_11463.y) * sqrt(1.0f + (_11466 * _11466))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _13949 = _12491 + (_11418 * cbFI_Timestep);
            }
            float2 _13950;
            if (_6623)
            {
                float2 _11542 = clamp((((_12491 + (_11418 * _4624)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _11545 = tan(_11542.x);
                _13950 = (float2(_11545 / cbFI_DeviceToViewDepth.z, (tan(_11542.y) * sqrt(1.0f + (_11545 * _11545))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _13950 = _12491 + (_11418 * _4624);
            }
            _14900 = lerp(_5965, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _13949, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _13950, 0.0f).xyz, cbFI_Timestep.xxx), _13727.xxx);
        }
        else
        {
            _14900 = _5965;
        }
        float3 _14899;
        if (_13957)
        {
            float3 _11587 = r_current_interpolation_source.Load(int3(_3963, 0)).xyz;
            float3 _14901;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _8881)
            {
                uint _11594_dummy_parameter;
                float _14064;
                _14064 = r_depth_tm1.Load(int3(int2(floor(_12514 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11594_dummy_parameter))))), 0)).x;
                float _6046;
                for (int _14063 = 0; _14063 < 24; _14064 = _6046, _14063++)
                {
                    float _6018 = float(_14063 & 7) * 0.785398185253143310546875f;
                    int _6020 = _14063 >> 3;
                    int _14951;
                    if (_6020 == 0)
                    {
                        _14951 = 16;
                    }
                    else
                    {
                        _14951 = (_6020 == 1) ? 48 : 96;
                    }
                    uint _11614_dummy_parameter;
                    _6046 = max(_14064, r_depth_tm1.Load(int3(int2(floor(clamp(_12514 + ((cbFI_MvDepthLaneSizeRcp * float(_14951)) * float2(cos(_6018), sin(_6018))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11614_dummy_parameter))))), 0)).x);
                }
                float2 _14065;
                do
                {
                    float _11636 = 1.0f - _12514.y;
                    float4 _11647 = mul(float4((float2(_12514.x, _11636) * 2.0f) - 1.0f.xx, _14064, 1.0f), cbFI_MotionTM1ToTM2);
                    float _11649 = _11647.w;
                    if (!(_11649 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14065 = 1000000.0f.xx;
                        break;
                    }
                    float2 _11662 = ((_11647.xy / _11649.xx) + 1.0f.xx) * 0.5f;
                    _14065 = float2(_11662.x - _12514.x, _11636 - _11662.y);
                    break;
                } while(false);
                float2 _6057 = _12514 + _14065;
                bool _11680 = all(bool2(_6057.x > 0.0f.xx.x, _6057.y > 0.0f.xx.y));
                bool _11686;
                if (_11680)
                {
                    _11686 = all(bool2(_6057.x < 1.0f.xx.x, _6057.y < 1.0f.xx.y));
                }
                else
                {
                    _11686 = _11680;
                }
                float3 _14902;
                if (_11686)
                {
                    float _6063 = abs(cbFI_DeviceToViewDepth.y / (_14064 - cbFI_DeviceToViewDepth.x));
                    uint _11706_dummy_parameter;
                    int2 _11706 = int2(spvTextureSize(r_depth_m2, uint(0), _11706_dummy_parameter));
                    float _6067 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6057 * float2(_11706))), int2(0, 0), _11706 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _14907;
                    if (abs(_6067 - _6063) <= (0.20000000298023223876953125f * max(_6067, _6063)))
                    {
                        uint _11740_dummy_parameter;
                        int2 _11740 = int2(spvTextureSize(r_colour_m2, uint(0), _11740_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _11763;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _11763);
                        }
                        _14907 = r_colour_m2.Load(int3(clamp(int2(floor(_6057 * float2(_11740))), int2(0, 0), _11740 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _11773;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _11773);
                        }
                        _14907 = _11587;
                    }
                    _14902 = _14907;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11783;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _11783);
                    }
                    _14902 = _11587;
                }
                _14901 = _14902;
            }
            else
            {
                _14901 = _11587;
            }
            _14899 = _14901;
        }
        else
        {
            _14899 = _14900;
        }
        uint _6095 = cbFI_pad0 & 255u;
        bool _14788;
        float3 _14898;
        if (_6095 != 0u)
        {
            float3 _6100 = r_present_backbuffer.Load(int3(_3963, 0)).xyz;
            float3 _6104 = r_current_interpolation_source.Load(int3(_3963, 0)).xyz;
            float3 _6108 = abs(_6100 - _6104);
            float3 _14068;
            if (_6095 == 2u)
            {
                _14068 = (abs(_6104) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _14068 = 0.000244140625f.xxx;
            }
            bool _6124 = any(bool3(_6108.x > _14068.x, _6108.y > _14068.y, _6108.z > _14068.z));
            bool3 _15136 = _6124.xxx;
            _14898 = float3(_15136.x ? _6100.x : _14899.x, _15136.y ? _6100.y : _14899.y, _15136.z ? _6100.z : _14899.z);
            _14788 = _6124;
        }
        else
        {
            _14898 = _14899;
            _14788 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _11798;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _11798);
        }
        float3 _14881;
        if (_5782 == 1u)
        {
            _14881 = lerp(_7300, _7308, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _14882;
            if (_5782 == 2u)
            {
                _14882 = lerp(_7316, _7324, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _14883;
                if (_5782 == 3u)
                {
                    _14883 = float(_14788).xxx;
                }
                else
                {
                    float3 _14884;
                    if (_5782 == 4u)
                    {
                        _14884 = float3(((_12512 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _14885;
                        if (_5782 == 5u)
                        {
                            _14885 = float3(((_6595 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _14886;
                            if (_5782 == 6u)
                            {
                                _14886 = float3(_13712.xy, _13712.z + _13712.w);
                            }
                            else
                            {
                                float3 _14887;
                                if (_5782 == 7u)
                                {
                                    _14887 = r_current_interpolation_source.Load(int3(_3963, 0)).xyz;
                                }
                                else
                                {
                                    float3 _14888;
                                    if (_5782 == 8u)
                                    {
                                        _14888 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4409, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _14889;
                                        if (_5786)
                                        {
                                            uint _11820_dummy_parameter;
                                            uint _11852_dummy_parameter;
                                            _14889 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_4409 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11820_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_4409 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11852_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _14890;
                                            if (_5789)
                                            {
                                                _14890 = _7316;
                                            }
                                            else
                                            {
                                                float3 _14891;
                                                if (_5782 == 20u)
                                                {
                                                    _14891 = _7300;
                                                }
                                                else
                                                {
                                                    float3 _14892;
                                                    if (_5782 == 21u)
                                                    {
                                                        _14892 = _7308;
                                                    }
                                                    else
                                                    {
                                                        float3 _14893;
                                                        if (_5782 == 22u)
                                                        {
                                                            _14893 = _7324;
                                                        }
                                                        else
                                                        {
                                                            float3 _14894;
                                                            if (_5782 == 18u)
                                                            {
                                                                _14894 = _14492;
                                                            }
                                                            else
                                                            {
                                                                float3 _14895;
                                                                if (_5782 == 19u)
                                                                {
                                                                    _14895 = _14280;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _15138 = (_5782 == 23u).xxx;
                                                                    _14895 = float3(_15138.x ? _14074.x : _14898.x, _15138.y ? _14074.y : _14898.y, _15138.z ? _14074.z : _14898.z);
                                                                }
                                                                _14894 = _14895;
                                                            }
                                                            _14893 = _14894;
                                                        }
                                                        _14892 = _14893;
                                                    }
                                                    _14891 = _14892;
                                                }
                                                _14890 = _14891;
                                            }
                                            _14889 = _14890;
                                        }
                                        _14888 = _14889;
                                    }
                                    _14887 = _14888;
                                }
                                _14886 = _14887;
                            }
                            _14885 = _14886;
                        }
                        _14884 = _14885;
                    }
                    _14883 = _14884;
                }
                _14882 = _14883;
            }
            _14881 = _14882;
        }
        float3 _14880;
        if ((_5782 >= 9u) && (_5782 <= 11u))
        {
            uint _6288 = 64u + uint((_12631.y * cbFI_MvDepthLaneSize.x) + _12631.x);
            uint _6292 = rw_nfru_diagnostics.Load<uint>(_6288 * 4 + 0) & 15u;
            float3 _14912;
            if (_5782 == 10u)
            {
                float3 _14879;
                if ((rw_nfru_diagnostics.Load<uint>(_6288 * 4 + 0) & 32u) != 0u)
                {
                    _14879 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _14878;
                    if ((rw_nfru_diagnostics.Load<uint>(_6288 * 4 + 0) & 16u) != 0u)
                    {
                        _14878 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6313 = ((rw_nfru_diagnostics.Load<uint>(_6288 * 4 + 0) & 64u) != 0u).xxx;
                        _14878 = float3(_6313.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6313.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6313.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _14879 = _14878;
                }
                _14912 = _14879;
            }
            else
            {
                float3 _14913;
                if (_5782 == 11u)
                {
                    uint _6326 = (rw_nfru_diagnostics.Load<uint>(_6288 * 4 + 0) >> 8u) & 15u;
                    uint _6329 = (rw_nfru_diagnostics.Load<uint>(_6288 * 4 + 0) >> 12u) & 15u;
                    float3 _14871;
                    if ((_6292 == 2u) || (_6292 == 3u))
                    {
                        _14871 = _3676[_6292];
                    }
                    else
                    {
                        bool _6341 = _6326 == 3u;
                        bool _6343 = _6329 == 3u;
                        float3 _14872;
                        if (_6341 && _6343)
                        {
                            _14872 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _14873;
                            if (_6341)
                            {
                                _14873 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _14874;
                                if (_6343)
                                {
                                    _14874 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _14875;
                                    if ((_6326 == 4u) || (_6329 == 4u))
                                    {
                                        _14875 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _14876;
                                        if ((_6326 == 1u) || (_6329 == 1u))
                                        {
                                            _14876 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _15140 = (_6292 == 1u).xxx;
                                            _14876 = float3(_15140.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _15140.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _15140.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _14875 = _14876;
                                    }
                                    _14874 = _14875;
                                }
                                _14873 = _14874;
                            }
                            _14872 = _14873;
                        }
                        _14871 = _14872;
                    }
                    _14913 = _14871;
                }
                else
                {
                    _14913 = _3676[min(_6292, 7u)];
                }
                _14912 = _14913;
            }
            _14880 = _14912;
        }
        else
        {
            _14880 = _14881;
        }
        float4 _14916;
        if ((_5782 >= 14u) && (_5782 <= 16u))
        {
            float2 _14914;
            if (_5782 == 14u)
            {
                uint _6399_dummy_parameter;
                uint _6405_dummy_parameter;
                _14914 = r_flow_tm1.Load(int3(clamp(int2(floor(_4409 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6399_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6405_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _14915;
                if (_5782 == 16u)
                {
                    uint _11903 = r_warped_flow_qdata_tm1.Load(int3(_4425, 0)).x & 2147483647u;
                    uint _11935 = uint(max((int((_11903 >> 16u) & 15u) - 6), 0));
                    _14915 = ((float2(float((1 - (2 * int((_11903 >> 15u) & 1u))) * int(((_11903 >> uint(7)) & 127u) << _11935)), float((1 - (2 * int((_11903 >> 14u) & 1u))) * int((_11903 & 127u) << _11935))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _14915 = _6595 * float2(cbFI_DisplaySize);
                }
                _14914 = _14915;
            }
            uint2 _6438 = uint2(clamp(round(_14914 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6440 = _6438.x;
            uint _6447 = _6438.y;
            _14916 = float4(float(_6440 & 255u), float((_6440 >> 8u) | ((_6447 & 15u) << 4u)), float(_6447 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _14917;
            if (_5782 == 17u)
            {
                _14917 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4425, 0)).x != 0u), _4869, 0.0f, 1.0f);
            }
            else
            {
                _14917 = float4(_14880, 1.0f);
            }
            _14916 = _14917;
        }
        rw_output[_3963] = _14916.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6491 = ((uint(_3963.y) * uint(cbFI_DisplaySize.x)) + uint(_3963.x)) * 6u;
            uint _11981 = spvPackHalf2x16(clamp(_7299.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6491 * 4 + 0, (((_11981 & 32767u) >> 4u) | ((((_11981 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7299.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12016 = spvPackHalf2x16(clamp(_7307.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6491 + 1u) * 4 + 0, (((_12016 & 32767u) >> 4u) | ((((_12016 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7307.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12051 = spvPackHalf2x16(clamp(_7315.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6491 + 2u) * 4 + 0, (((_12051 & 32767u) >> 4u) | ((((_12051 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7315.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12086 = spvPackHalf2x16(clamp(_7323.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6491 + 3u) * 4 + 0, (((_12086 & 32767u) >> 4u) | ((((_12086 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7323.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _12113 = r_current_interpolation_source.Load(int3(_3963, 0));
            uint _12127 = spvPackHalf2x16(clamp(_12113.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6491 + 4u) * 4 + 0, (((_12127 & 32767u) >> 4u) | ((((_12127 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12113.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _14950;
            if (_14788 || (_5782 != 0u))
            {
                _14950 = 4294967295u;
            }
            else
            {
                uint _12162 = spvPackHalf2x16(clamp(_14916.xy, 0.0f.xx, 65000.0f.xx));
                _14950 = (((_12162 & 32767u) >> 4u) | ((((_12162 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_14916.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6491 + 5u) * 4 + 0, _14950);
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
