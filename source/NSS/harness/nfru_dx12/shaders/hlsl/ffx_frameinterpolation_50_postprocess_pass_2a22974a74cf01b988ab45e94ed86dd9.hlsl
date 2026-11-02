static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3097[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3384 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3384.x >= cbFI_DisplaySize.x, _3384.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3384] = float4(r_present_backbuffer.Load(int3(_3384, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3746 = (float2(_3384) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3757 = int2(floor(_3746 * float2(cbFI_MvDepthLaneSize)));
        int2 _3762 = int2(floor(_3746 * float2(cbFI_FlowLaneSize)));
        float4 _5492 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3746 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5498 = r_warped_filled_flow_tm1.Load(int3(_3762, 0)).xy;
        float2 _5504 = r_warped_filled_motion_tp1.Load(int3(_3757, 0)).xy;
        bool _5526 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _9048;
        if (_5526)
        {
            float _5539 = ((2.0f * _3746.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _9048 = float2(atan(_5539) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3746.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5539 * _5539))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _9048 = _3746;
        }
        bool _3783 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _9069;
        bool _9090;
        int2 _9101;
        float3 _10168;
        if (_3783)
        {
            float _9050;
            float _9052;
            _9052 = 2.0f;
            _9050 = -1.0f;
            uint _3446[9];
            float _10562;
            float _10565;
            for (int _9049 = 0; _9049 < 9; _9052 = _10565, _9050 = _10562, _9049++)
            {
                _3446[_9049] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3757 + int2((_9049 % 3) - 1, (_9049 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3446[_9049] != 0u)
                {
                    float _10557;
                    if (_3446[_9049] == 0u)
                    {
                        _10557 = -1.0f;
                    }
                    else
                    {
                        _10557 = float((_3446[_9049] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10565 = min(_9052, _10557);
                    _10562 = max(_9050, _10557);
                }
                else
                {
                    _10565 = _9052;
                    _10562 = _9050;
                }
            }
            float _3829 = float(_9050 >= 0.0f);
            float3 _8859 = 0.0f.xxx;
            _8859.y = _3829;
            float2 _9070;
            bool _9091;
            int2 _9102;
            float3 _10169;
            if ((_9050 - _9052) > 0.0199999995529651641845703125f)
            {
                float _9058;
                int2 _9059;
                float2 _9060;
                int2 _9062;
                float2 _9068;
                _9068 = _5504;
                _9062 = _3757;
                _9060 = _5504;
                _9059 = _3757;
                _9058 = -1.0f;
                float _10570;
                int2 _10574;
                float2 _10585;
                int2 _10596;
                float2 _10629;
                float _10675;
                int _9057 = 0;
                float _10538 = 1000000000.0f;
                for (; _9057 < 9; _10538 = _10675, _9068 = _10629, _9062 = _10596, _9060 = _10585, _9059 = _10574, _9058 = _10570, _9057++)
                {
                    if (_3446[_9057] == 0u)
                    {
                        _10675 = _10538;
                        _10629 = _9068;
                        _10596 = _9062;
                        _10585 = _9060;
                        _10574 = _9059;
                        _10570 = _9058;
                        continue;
                    }
                    int2 _3864 = clamp(_3757 + int2((_9057 % 3) - 1, (_9057 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5614 = _3446[_9057] & 2147483647u;
                    uint _5646 = uint(max((int((_5614 >> 16u) & 15u) - 6), 0));
                    float2 _3870 = (float2(float((1 - (2 * int((_5614 >> 15u) & 1u))) * int(((_5614 >> uint(7)) & 127u) << _5646)), float((1 - (2 * int((_5614 >> 14u) & 1u))) * int((_5614 & 127u) << _5646))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10524;
                    if (_3446[_9057] == 0u)
                    {
                        _10524 = -1.0f;
                    }
                    else
                    {
                        _10524 = float((_3446[_9057] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3875 = _10524 - 0.100000001490116119384765625f;
                    float2 _10525;
                    if (_5526)
                    {
                        float2 _5723 = clamp((((_9048 + (_3870 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5726 = tan(_5723.x);
                        _10525 = (float2(_5726 / cbFI_DeviceToViewDepth.z, (tan(_5723.y) * sqrt(1.0f + (_5726 * _5726))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10525 = _9048 + (_3870 * cbFI_Timestep);
                    }
                    float _3882 = cbFI_Timestep - 1.0f;
                    float2 _10526;
                    if (_5526)
                    {
                        float2 _5794 = clamp((((_9048 + (_3870 * _3882)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5797 = tan(_5794.x);
                        _10526 = (float2(_5797 / cbFI_DeviceToViewDepth.z, (tan(_5794.y) * sqrt(1.0f + (_5797 * _5797))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10526 = _9048 + (_3870 * _3882);
                    }
                    bool _5830 = all(bool2(_10525.x > 0.0f.xx.x, _10525.y > 0.0f.xx.y));
                    bool _5836;
                    if (_5830)
                    {
                        _5836 = all(bool2(_10525.x < 1.0f.xx.x, _10525.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5836 = _5830;
                    }
                    float _10529;
                    if (_5836)
                    {
                        uint _5843_dummy_parameter;
                        _10529 = max((_3875 - (log(((r_depth_tm1.Load(int3(int2(floor(_10525 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5843_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10529 = 0.0f;
                    }
                    bool _5873 = all(bool2(_10526.x > 0.0f.xx.x, _10526.y > 0.0f.xx.y));
                    bool _5879;
                    if (_5873)
                    {
                        _5879 = all(bool2(_10526.x < 1.0f.xx.x, _10526.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5879 = _5873;
                    }
                    float _10530;
                    if (_5879)
                    {
                        uint _5886_dummy_parameter;
                        _10530 = _10529 + max((_3875 - (log(((r_depth_tp1.Load(int3(int2(floor(_10526 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5886_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10530 = _10529;
                    }
                    float _10571;
                    int2 _10575;
                    float2 _10586;
                    int2 _10597;
                    float2 _10630;
                    float _10676;
                    if (_10530 == 0.0f)
                    {
                        bool _3917 = _3875 > _9058;
                        bool2 _10684 = _3917.xx;
                        _10676 = _10538;
                        _10630 = float2(_10684.x ? _3870.x : _9068.x, _10684.y ? _3870.y : _9068.y);
                        _10597 = int2(_10684.x ? _3864.x : _9062.x, _10684.y ? _3864.y : _9062.y);
                        _10586 = _9060;
                        _10575 = _9059;
                        _10571 = _3917 ? _3875 : _9058;
                    }
                    else
                    {
                        bool _3926 = _10530 < _10538;
                        bool2 _10680 = _3926.xx;
                        _10676 = _3926 ? _10530 : _10538;
                        _10630 = _9068;
                        _10597 = _9062;
                        _10586 = float2(_10680.x ? _3870.x : _9060.x, _10680.y ? _3870.y : _9060.y);
                        _10575 = int2(_10680.x ? _3864.x : _9059.x, _10680.y ? _3864.y : _9059.y);
                        _10571 = _9058;
                    }
                    _10675 = _10676;
                    _10629 = _10630;
                    _10596 = _10597;
                    _10585 = _10586;
                    _10574 = _10575;
                    _10570 = _10571;
                }
                bool _3938 = _9058 < 0.0f;
                bool2 _10690 = _3938.xx;
                int2 _10693 = int2(_10690.x ? _9059.x : _9062.x, _10690.y ? _9059.y : _9062.y);
                _10169 = float3(1.0f, _3829, float(any(bool2(_10693.x != _3757.x, _10693.y != _3757.y))));
                _9102 = _10693;
                _9091 = _3938 ? false : true;
                _9070 = float2(_10690.x ? _9060.x : _9068.x, _10690.y ? _9060.y : _9068.y);
            }
            else
            {
                _10169 = _8859;
                _9102 = _3757;
                _9091 = false;
                _9070 = _5504;
            }
            _10168 = _10169;
            _9101 = _9102;
            _9090 = _9091;
            _9069 = _9070;
        }
        else
        {
            _10168 = 0.0f.xxx;
            _9101 = _3757;
            _9090 = false;
            _9069 = _5504;
        }
        float2 _9071;
        if (_5526)
        {
            float2 _5951 = clamp((((_9048 + (_9069 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5954 = tan(_5951.x);
            _9071 = (float2(_5954 / cbFI_DeviceToViewDepth.z, (tan(_5951.y) * sqrt(1.0f + (_5954 * _5954))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9071 = _9048 + (_9069 * cbFI_Timestep);
        }
        float _3961 = cbFI_Timestep - 1.0f;
        float2 _9073;
        if (_5526)
        {
            float2 _6022 = clamp((((_9048 + (_9069 * _3961)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6025 = tan(_6022.x);
            _9073 = (float2(_6025 / cbFI_DeviceToViewDepth.z, (tan(_6022.y) * sqrt(1.0f + (_6025 * _6025))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9073 = _9048 + (_9069 * _3961);
        }
        float _3966 = -cbFI_Timestep;
        float2 _9074;
        if (_5526)
        {
            float2 _6093 = clamp((((_9048 + (_5498 * _3966)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6096 = tan(_6093.x);
            _9074 = (float2(_6096 / cbFI_DeviceToViewDepth.z, (tan(_6093.y) * sqrt(1.0f + (_6096 * _6096))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9074 = _9048 + (_5498 * _3966);
        }
        float _3971 = 1.0f - cbFI_Timestep;
        float2 _9075;
        if (_5526)
        {
            float2 _6164 = clamp((((_9048 + (_5498 * _3971)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6167 = tan(_6164.x);
            _9075 = (float2(_6167 / cbFI_DeviceToViewDepth.z, (tan(_6164.y) * sqrt(1.0f + (_6167 * _6167))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _9075 = _9048 + (_5498 * _3971);
        }
        float4 _6202 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9071, 0.0f);
        float3 _6203 = _6202.xyz;
        float4 _6210 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9073, 0.0f);
        float3 _6211 = _6210.xyz;
        float4 _6218 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _9074, 0.0f);
        float3 _6219 = _6218.xyz;
        float4 _6226 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _9075, 0.0f);
        float3 _6227 = _6226.xyz;
        float4 _6241 = exp(_5492 - max(max(max(_5492.x, _5492.y), _5492.z), _5492.w).xxxx);
        float4 _6248 = _6241 / (dot(_6241, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3990 = _3783 && (!_9090);
        bool _3999;
        if (_3990)
        {
            _3999 = (_6248.z + _6248.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3999 = _3990;
        }
        bool _4010;
        if (_3999)
        {
            _4010 = length((_9074 - _9071) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4010 = _3999;
        }
        bool _9114;
        if (_4010)
        {
            uint4 _6267 = r_warped_motion_qdata_tp1.Load(int3(_9101, 0));
            uint _6268 = _6267.x;
            bool _9117;
            if (_6268 != 0u)
            {
                float _9103;
                if (_6268 == 0u)
                {
                    _9103 = -1.0f;
                }
                else
                {
                    _9103 = float((_6268 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4020 = _9103 - 0.12000000476837158203125f;
                bool _6287 = all(bool2(_9074.x > 0.0f.xx.x, _9074.y > 0.0f.xx.y));
                bool _6293;
                if (_6287)
                {
                    _6293 = all(bool2(_9074.x < 1.0f.xx.x, _9074.y < 1.0f.xx.y));
                }
                else
                {
                    _6293 = _6287;
                }
                bool _4030;
                if (_6293)
                {
                    uint _6300_dummy_parameter;
                    _4030 = (log(((r_depth_tm1.Load(int3(int2(floor(_9074 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6300_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4020;
                }
                else
                {
                    _4030 = _6293;
                }
                bool _4044;
                if (!_4030)
                {
                    bool _6330 = all(bool2(_9075.x > 0.0f.xx.x, _9075.y > 0.0f.xx.y));
                    bool _6336;
                    if (_6330)
                    {
                        _6336 = all(bool2(_9075.x < 1.0f.xx.x, _9075.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6336 = _6330;
                    }
                    bool _4042;
                    if (_6336)
                    {
                        uint _6343_dummy_parameter;
                        _4042 = (log(((r_depth_tp1.Load(int3(int2(floor(_9075 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6343_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4020;
                    }
                    else
                    {
                        _4042 = _6336;
                    }
                    _4044 = _4042;
                }
                else
                {
                    _4044 = _4030;
                }
                _9117 = _4044;
            }
            else
            {
                _9117 = false;
            }
            _9114 = _9117;
        }
        else
        {
            _9114 = false;
        }
        bool _4049 = _9090 || _9114;
        bool _4054;
        if (_4049)
        {
            bool _6373 = all(bool2(_9071.x > 0.0f.xx.x, _9071.y > 0.0f.xx.y));
            bool _6379;
            if (_6373)
            {
                _6379 = all(bool2(_9071.x < 1.0f.xx.x, _9071.y < 1.0f.xx.y));
            }
            else
            {
                _6379 = _6373;
            }
            _4054 = _6379;
        }
        else
        {
            _4054 = _4049;
        }
        bool _4059;
        if (_4054)
        {
            bool _6384 = all(bool2(_9073.x > 0.0f.xx.x, _9073.y > 0.0f.xx.y));
            bool _6390;
            if (_6384)
            {
                _6390 = all(bool2(_9073.x < 1.0f.xx.x, _9073.y < 1.0f.xx.y));
            }
            else
            {
                _6390 = _6384;
            }
            _4059 = _6390;
        }
        else
        {
            _4059 = _4054;
        }
        float4 _9211;
        if (_4059)
        {
            float _4062 = _6248.x;
            float _4064 = _6248.y;
            float _4065 = _4062 + _4064;
            float _4070 = _6248.z + _6248.w;
            float _9132;
            if (_4065 > 0.001000000047497451305389404296875f)
            {
                _9132 = _4062 / _4065;
            }
            else
            {
                _9132 = _3971;
            }
            _9211 = float4(_4062 + (_4070 * _9132), _4064 + (_4070 * (1.0f - _9132)), 0.0f, 0.0f);
        }
        else
        {
            _9211 = _6248;
        }
        bool _6418 = (cbFI_pad0 & 1024u) != 0u;
        bool _6394 = !_6418;
        bool _6395 = !_6394;
        bool _6412;
        if (_6395)
        {
            _6412 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9101.y * cbFI_MvDepthLaneSize.x) + _9101.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6412 = _6394;
        }
        bool _6444;
        if (_6395)
        {
            _6444 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3762.y * cbFI_FlowLaneSize.x) + _3762.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6444 = _6394;
        }
        float _4105 = float(_6444);
        bool _9224;
        float4 _9255;
        float3 _10022;
        if (_6418)
        {
            bool _4115;
            if (_6412)
            {
                _4115 = all(bool2(_9071.x > 0.0f.xx.x, _9071.y > 0.0f.xx.y));
            }
            else
            {
                _4115 = _6412;
            }
            bool _4121;
            if (_4115)
            {
                _4121 = all(bool2(_9071.x < 1.0f.xx.x, _9071.y < 1.0f.xx.y));
            }
            else
            {
                _4121 = _4115;
            }
            bool _4128;
            if (_6412)
            {
                _4128 = all(bool2(_9073.x > 0.0f.xx.x, _9073.y > 0.0f.xx.y));
            }
            else
            {
                _4128 = _6412;
            }
            bool _4134;
            if (_4128)
            {
                _4134 = all(bool2(_9073.x < 1.0f.xx.x, _9073.y < 1.0f.xx.y));
            }
            else
            {
                _4134 = _4128;
            }
            bool _4141;
            if (_6444)
            {
                _4141 = all(bool2(_9074.x > 0.0f.xx.x, _9074.y > 0.0f.xx.y));
            }
            else
            {
                _4141 = _6444;
            }
            bool _4147;
            if (_4141)
            {
                _4147 = all(bool2(_9074.x < 1.0f.xx.x, _9074.y < 1.0f.xx.y));
            }
            else
            {
                _4147 = _4141;
            }
            bool _4154;
            if (_6444)
            {
                _4154 = all(bool2(_9075.x > 0.0f.xx.x, _9075.y > 0.0f.xx.y));
            }
            else
            {
                _4154 = _6444;
            }
            bool _4160;
            if (_4154)
            {
                _4160 = all(bool2(_9075.x < 1.0f.xx.x, _9075.y < 1.0f.xx.y));
            }
            else
            {
                _4160 = _4154;
            }
            bool _4162 = !_6412;
            if (_4162)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6486;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6486);
                }
            }
            bool _4167 = !_6444;
            if (_4167)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6496;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6496);
                }
            }
            if (_6412 && _4167)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6506;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6506);
                }
            }
            if (_4162 && _6444)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6516;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6516);
                }
            }
            float _4186 = float(_4121);
            float _4188 = float(_4134);
            bool _4191 = _4147 && _4160;
            float _9166;
            if (_4191)
            {
                _9166 = 1.0f;
            }
            else
            {
                _9166 = (_4147 || _4160) ? 0.5f : 0.0f;
            }
            bool _9171;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4121)) && (!_4134))
            {
                bool _4221;
                if (_4191)
                {
                    float _9169;
                    do
                    {
                        bool _6600 = all(bool2(_9074.x > 0.0f.xx.x, _9074.y > 0.0f.xx.y));
                        bool _6606;
                        if (_6600)
                        {
                            _6606 = all(bool2(_9074.x < 1.0f.xx.x, _9074.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6606 = _6600;
                        }
                        bool _6537 = !_6606;
                        bool _6544;
                        if (!_6537)
                        {
                            bool _6611 = all(bool2(_9075.x > 0.0f.xx.x, _9075.y > 0.0f.xx.y));
                            bool _6617;
                            if (_6611)
                            {
                                _6617 = all(bool2(_9075.x < 1.0f.xx.x, _9075.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6617 = _6611;
                            }
                            _6544 = !_6617;
                        }
                        else
                        {
                            _6544 = _6537;
                        }
                        if (_6544)
                        {
                            _9169 = 0.0f;
                            break;
                        }
                        uint _6624_dummy_parameter;
                        uint _6640_dummy_parameter;
                        float4 _6565 = mul(float4((float2(_9074.x, 1.0f - _9074.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9074 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6624_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6567 = _6565.w;
                        if (abs(_6567) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9169 = 0.0f;
                            break;
                        }
                        float _6578 = abs(cbFI_DeviceToViewDepth.y / ((_6565.z / _6567) - cbFI_DeviceToViewDepth.x));
                        float _6581 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9075 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6640_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9169 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6578 - _6581) / max(max(_6578, _6581), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4221 = _9169 >= 0.5f;
                }
                else
                {
                    _4221 = _4191;
                }
                bool _4229;
                if (_4221)
                {
                    _4229 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4229 = _4221;
                }
                bool _9172;
                if (_4229)
                {
                    uint _6690_dummy_parameter;
                    float2 _9170;
                    do
                    {
                        float _6716 = 1.0f - _9074.y;
                        float4 _6727 = mul(float4((float2(_9074.x, _6716) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9074 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6690_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6729 = _6727.w;
                        if (!(_6729 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9170 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6742 = ((_6727.xy / _6729.xx) + 1.0f.xx) * 0.5f;
                        _9170 = float2(_6742.x - _9074.x, _6716 - _6742.y);
                        break;
                    } while(false);
                    float2 _4242 = float2(cbFI_DisplaySize);
                    _9172 = length(((_9074 + _9170) - _9075) * _4242) <= ((0.100000001490116119384765625f * length(_9170 * _4242)) + 8.0f);
                }
                else
                {
                    _9172 = _4221;
                }
                _9171 = _9172;
            }
            else
            {
                _9171 = true;
            }
            bool _4256 = !_9171;
            bool _10694 = _4256 ? false : _4160;
            bool _10695 = _4256 ? false : _4147;
            bool _9225;
            float4 _9256;
            if (!(((_4121 && _4134) && _10695) && _10694))
            {
                float4 _4278 = _9211 * float4(_4186, _4188, float(_10695), float(_10694));
                float _4280 = dot(_4278, 1.0f.xxxx);
                bool _4283 = !(_4280 > 0.0f);
                float4 _9257;
                if (!_4283)
                {
                    _9257 = _4278 / _4280.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6764;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6764);
                    }
                    _9257 = 0.0f.xxxx;
                }
                _9256 = _9257;
                _9225 = _4283;
            }
            else
            {
                _9256 = _9211;
                _9225 = false;
            }
            _10022 = float3(_4186, _4188, _9166);
            _9255 = _9256;
            _9224 = _9225;
        }
        else
        {
            _10022 = float3(float(_6412), _4105, 0.0f);
            _9255 = _9211;
            _9224 = false;
        }
        float4 _9749;
        bool _9769;
        float3 _9883;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9224))
        {
            bool _4306 = _9255.x > 0.00999999977648258209228515625f;
            bool _4309 = _9255.y > 0.00999999977648258209228515625f;
            bool _4318 = (_9255.z + _9255.w) > 0.0199999995529651641845703125f;
            bool _4324;
            if (_4318)
            {
                bool _6770 = all(bool2(_9074.x > 0.0f.xx.x, _9074.y > 0.0f.xx.y));
                bool _6776;
                if (_6770)
                {
                    _6776 = all(bool2(_9074.x < 1.0f.xx.x, _9074.y < 1.0f.xx.y));
                }
                else
                {
                    _6776 = _6770;
                }
                _4324 = _6776;
            }
            else
            {
                _4324 = _4318;
            }
            bool _4329;
            if (_4324)
            {
                bool _6781 = all(bool2(_9075.x > 0.0f.xx.x, _9075.y > 0.0f.xx.y));
                bool _6787;
                if (_6781)
                {
                    _6787 = all(bool2(_9075.x < 1.0f.xx.x, _9075.y < 1.0f.xx.y));
                }
                else
                {
                    _6787 = _6781;
                }
                _4329 = _6787;
            }
            else
            {
                _4329 = _4324;
            }
            bool _4336;
            if (_4329)
            {
                float _9259;
                do
                {
                    bool _6870 = all(bool2(_9074.x > 0.0f.xx.x, _9074.y > 0.0f.xx.y));
                    bool _6876;
                    if (_6870)
                    {
                        _6876 = all(bool2(_9074.x < 1.0f.xx.x, _9074.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6876 = _6870;
                    }
                    bool _6807 = !_6876;
                    bool _6814;
                    if (!_6807)
                    {
                        bool _6881 = all(bool2(_9075.x > 0.0f.xx.x, _9075.y > 0.0f.xx.y));
                        bool _6887;
                        if (_6881)
                        {
                            _6887 = all(bool2(_9075.x < 1.0f.xx.x, _9075.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6887 = _6881;
                        }
                        _6814 = !_6887;
                    }
                    else
                    {
                        _6814 = _6807;
                    }
                    if (_6814)
                    {
                        _9259 = 0.0f;
                        break;
                    }
                    uint _6894_dummy_parameter;
                    uint _6910_dummy_parameter;
                    float4 _6835 = mul(float4((float2(_9074.x, 1.0f - _9074.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9074 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6894_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6837 = _6835.w;
                    if (abs(_6837) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9259 = 0.0f;
                        break;
                    }
                    float _6848 = abs(cbFI_DeviceToViewDepth.y / ((_6835.z / _6837) - cbFI_DeviceToViewDepth.x));
                    float _6851 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9075 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6910_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9259 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6848 - _6851) / max(max(_6848, _6851), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4336 = _9259 < 0.5f;
            }
            else
            {
                _4336 = _4329;
            }
            float4 _9274;
            if (_4336)
            {
                uint _6960_dummy_parameter;
                uint _6991_dummy_parameter;
                float4 _9275;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_9074 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6960_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9075 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6991_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9275 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9275 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9274 = _9275;
            }
            else
            {
                _9274 = 1.0f.xxxx;
            }
            bool _4360;
            if (_6412)
            {
                bool _7020 = all(bool2(_9071.x > 0.0f.xx.x, _9071.y > 0.0f.xx.y));
                bool _7026;
                if (_7020)
                {
                    _7026 = all(bool2(_9071.x < 1.0f.xx.x, _9071.y < 1.0f.xx.y));
                }
                else
                {
                    _7026 = _7020;
                }
                _4360 = _7026;
            }
            else
            {
                _4360 = _6412;
            }
            bool _4366;
            if (_6412)
            {
                bool _7031 = all(bool2(_9073.x > 0.0f.xx.x, _9073.y > 0.0f.xx.y));
                bool _7037;
                if (_7031)
                {
                    _7037 = all(bool2(_9073.x < 1.0f.xx.x, _9073.y < 1.0f.xx.y));
                }
                else
                {
                    _7037 = _7031;
                }
                _4366 = _7037;
            }
            else
            {
                _4366 = _6412;
            }
            bool _4372;
            if (_6444)
            {
                bool _7042 = all(bool2(_9074.x > 0.0f.xx.x, _9074.y > 0.0f.xx.y));
                bool _7048;
                if (_7042)
                {
                    _7048 = all(bool2(_9074.x < 1.0f.xx.x, _9074.y < 1.0f.xx.y));
                }
                else
                {
                    _7048 = _7042;
                }
                _4372 = _7048;
            }
            else
            {
                _4372 = _6444;
            }
            bool _4378;
            if (_6444)
            {
                bool _7053 = all(bool2(_9075.x > 0.0f.xx.x, _9075.y > 0.0f.xx.y));
                bool _7059;
                if (_7053)
                {
                    _7059 = all(bool2(_9075.x < 1.0f.xx.x, _9075.y < 1.0f.xx.y));
                }
                else
                {
                    _7059 = _7053;
                }
                _4378 = _7059;
            }
            else
            {
                _4378 = _6444;
            }
            bool _4381 = _4372 != _4378;
            bool _4387;
            if (_4381)
            {
                _4387 = _4360 || _4366;
            }
            else
            {
                _4387 = _4381;
            }
            float4 _9357;
            if (_4387)
            {
                float4 _8944 = _9274;
                _8944.z = 0.0f;
                _8944.w = 0.0f;
                _9357 = _8944;
            }
            else
            {
                _9357 = _9274;
            }
            bool _4394 = _4360 && _4306;
            bool _4397 = _4366 && _4309;
            float4 _9462;
            float3 _9922;
            if (_4394 || _4397)
            {
                float _9352;
                do
                {
                    uint4 _7198 = r_warped_motion_qdata_tp1.Load(int3(_9101, 0));
                    uint _7199 = _7198.x;
                    if (_7199 != 0u)
                    {
                        float _9351;
                        if (_7199 == 0u)
                        {
                            _9351 = -1.0f;
                        }
                        else
                        {
                            _9351 = float((_7199 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9352 = _9351;
                        break;
                    }
                    int _9334;
                    uint _9335;
                    _9335 = _7199;
                    _9334 = -1;
                    uint _9350;
                    for (; _9334 <= 1; _9335 = _9350, _9334++)
                    {
                        _9350 = _9335;
                        for (int _9348 = -1; _9348 <= 1; )
                        {
                            _9350 = max(_9350, r_warped_motion_qdata_tp1.Load(int3(clamp(_9101 + int2(_9348, _9334), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9348++;
                            continue;
                        }
                    }
                    if (_9335 != 0u)
                    {
                        float _9347;
                        if (_9335 == 0u)
                        {
                            _9347 = -1.0f;
                        }
                        else
                        {
                            _9347 = float((_9335 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9352 = _9347;
                        break;
                    }
                    uint _9337;
                    _9337 = 4294967295u;
                    uint _10666;
                    for (int _9336 = 0; _9336 < 8; _9337 = _10666, _9336++)
                    {
                        int _9340 = 0;
                        for (;;)
                        {
                            if (_9340 < 5)
                            {
                                int2 _7149 = _9101 + (_1085[_9336] * _1094[_9340].xx);
                                bool _7152 = any(bool2(_7149.x < int2(0, 0).x, _7149.y < int2(0, 0).y));
                                bool _7160;
                                if (!_7152)
                                {
                                    _7160 = any(bool2(_7149.x >= cbFI_MvDepthLaneSize.x, _7149.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7160 = _7152;
                                }
                                if (_7160)
                                {
                                    _10666 = _9337;
                                    break;
                                }
                                uint4 _7238 = r_warped_motion_qdata_tp1.Load(int3(_7149, 0));
                                uint _7239 = _7238.x;
                                if (_7239 != 0u)
                                {
                                    _10666 = min(_9337, _7239);
                                    break;
                                }
                                _9340++;
                                continue;
                            }
                            else
                            {
                                _10666 = _9337;
                                break;
                            }
                        }
                    }
                    float _9339;
                    if (_9337 == 4294967295u)
                    {
                        _9339 = -1.0f;
                    }
                    else
                    {
                        float _9338;
                        if (_9337 == 0u)
                        {
                            _9338 = -1.0f;
                        }
                        else
                        {
                            _9338 = float((_9337 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9339 = _9338;
                    }
                    _9352 = _9339;
                    break;
                } while(false);
                bool _4405 = _9352 < 0.0f;
                float _9353;
                if (_4405)
                {
                    _9353 = 0.0f;
                }
                else
                {
                    _9353 = _9352 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _7260_dummy_parameter;
                uint _7292_dummy_parameter;
                float4 _9390;
                if ((_4405 && _4394) && _4397)
                {
                    uint _7324_dummy_parameter;
                    float _7348 = log(((r_depth_tm1.Load(int3(int2(floor(_9071 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7324_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7356_dummy_parameter;
                    float _7380 = log(((r_depth_tp1.Load(int3(int2(floor(_9073 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7356_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9391;
                    if (_7348 > (_7380 + 0.07999999821186065673828125f))
                    {
                        float4 _8948 = _9357;
                        _8948.x = 0.0f;
                        _9391 = _8948;
                    }
                    else
                    {
                        float4 _9392;
                        if (_7380 > (_7348 + 0.07999999821186065673828125f))
                        {
                            float4 _8950 = _9357;
                            _8950.y = 0.0f;
                            _9392 = _8950;
                        }
                        else
                        {
                            _9392 = _9357;
                        }
                        _9391 = _9392;
                    }
                    _9390 = _9391;
                }
                else
                {
                    _9390 = _9357;
                }
                float _4457 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4459 = _9352 >= 0.0f;
                float _9373;
                if (_4459)
                {
                    _9373 = _9352 - _4457;
                }
                else
                {
                    float _9369;
                    if (_4394)
                    {
                        float _9368;
                        _9368 = 2.0f;
                        float _7438;
                        for (int _9367 = 0; _9367 < 24; _9368 = _7438, _9367++)
                        {
                            float _7402 = float(_9367 & 7) * 0.785398185253143310546875f;
                            int _7404 = _9367 >> 3;
                            int _9370;
                            if (_7404 == 0)
                            {
                                _9370 = 16;
                            }
                            else
                            {
                                _9370 = (_7404 == 1) ? 48 : 96;
                            }
                            uint _7454_dummy_parameter;
                            _7438 = min(_9368, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_9071 + ((cbFI_MvDepthLaneSizeRcp * float(_9370)) * float2(cos(_7402), sin(_7402))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7454_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9369 = _9368;
                    }
                    else
                    {
                        _9369 = 0.0f;
                    }
                    _9373 = _9369;
                }
                float _9380;
                if (_4459)
                {
                    _9380 = _9352 - _4457;
                }
                else
                {
                    float _9376;
                    if (_4397)
                    {
                        float _9375;
                        _9375 = 2.0f;
                        float _7552;
                        for (int _9374 = 0; _9374 < 24; _9375 = _7552, _9374++)
                        {
                            float _7516 = float(_9374 & 7) * 0.785398185253143310546875f;
                            int _7518 = _9374 >> 3;
                            int _9377;
                            if (_7518 == 0)
                            {
                                _9377 = 16;
                            }
                            else
                            {
                                _9377 = (_7518 == 1) ? 48 : 96;
                            }
                            uint _7584_dummy_parameter;
                            _7552 = min(_9375, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_9073 + ((cbFI_MvDepthLaneSizeRcp * float(_9377)) * float2(cos(_7516), sin(_7516))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7584_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9376 = _9375;
                    }
                    else
                    {
                        _9376 = 0.0f;
                    }
                    _9380 = _9376;
                }
                float _9381;
                if (_4394)
                {
                    uint _7616_dummy_parameter;
                    _9381 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_9071 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7616_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9381 = 0.0f;
                }
                float _9382;
                if (_4397)
                {
                    uint _7636_dummy_parameter;
                    _9382 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_9073 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7636_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9382 = 0.0f;
                }
                bool _4514;
                if (_4394)
                {
                    _4514 = _9381 > ((exp((_9373 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4514 = _4394;
                }
                float4 _9398;
                if (_4514)
                {
                    float4 _8952 = _9390;
                    _8952.x = 0.0f;
                    _9398 = _8952;
                }
                else
                {
                    _9398 = _9390;
                }
                bool _4526;
                if (_4397)
                {
                    _4526 = _9382 > ((exp((_9380 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4526 = _4397;
                }
                float4 _9400;
                if (_4526)
                {
                    float4 _8954 = _9398;
                    _8954.y = 0.0f;
                    _9400 = _8954;
                }
                else
                {
                    _9400 = _9398;
                }
                float4 _9463;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4459)
                {
                    bool _4546;
                    if (_4394)
                    {
                        _4546 = _9381 < ((exp((_9373 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4546 = _4394;
                    }
                    float4 _9402;
                    if (_4546)
                    {
                        float4 _8956 = _9400;
                        _8956.x = 0.0f;
                        _9402 = _8956;
                    }
                    else
                    {
                        _9402 = _9400;
                    }
                    bool _4558;
                    if (_4397)
                    {
                        _4558 = _9382 < ((exp((_9380 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4558 = _4397;
                    }
                    float4 _9464;
                    if (_4558)
                    {
                        float4 _8958 = _9402;
                        _8958.y = 0.0f;
                        _9464 = _8958;
                    }
                    else
                    {
                        _9464 = _9402;
                    }
                    _9463 = _9464;
                }
                else
                {
                    _9463 = _9400;
                }
                _9922 = float3(_9353, log(((r_depth_tm1.Load(int3(int2(floor(_9071 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7260_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_9073 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7292_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _9462 = _9463;
            }
            else
            {
                _9922 = float3(0.0f, 0.0f, 0.5f);
                _9462 = _9357;
            }
            bool _4569 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4318;
            bool _4575;
            if (_4569)
            {
                _4575 = _4372 || _4378;
            }
            else
            {
                _4575 = _4569;
            }
            float4 _9485;
            if (_4575)
            {
                float _9457;
                do
                {
                    uint4 _7816 = r_warped_motion_qdata_tp1.Load(int3(_9101, 0));
                    uint _7817 = _7816.x;
                    if (_7817 != 0u)
                    {
                        float _9456;
                        if (_7817 == 0u)
                        {
                            _9456 = -1.0f;
                        }
                        else
                        {
                            _9456 = float((_7817 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9457 = _9456;
                        break;
                    }
                    int _9439;
                    uint _9440;
                    _9440 = _7817;
                    _9439 = -1;
                    uint _9455;
                    for (; _9439 <= 1; _9440 = _9455, _9439++)
                    {
                        _9455 = _9440;
                        for (int _9453 = -1; _9453 <= 1; )
                        {
                            _9455 = max(_9455, r_warped_motion_qdata_tp1.Load(int3(clamp(_9101 + int2(_9453, _9439), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9453++;
                            continue;
                        }
                    }
                    if (_9440 != 0u)
                    {
                        float _9452;
                        if (_9440 == 0u)
                        {
                            _9452 = -1.0f;
                        }
                        else
                        {
                            _9452 = float((_9440 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9457 = _9452;
                        break;
                    }
                    uint _9442;
                    _9442 = 4294967295u;
                    uint _10667;
                    for (int _9441 = 0; _9441 < 8; _9442 = _10667, _9441++)
                    {
                        int _9445 = 0;
                        for (;;)
                        {
                            if (_9445 < 5)
                            {
                                int2 _7767 = _9101 + (_1085[_9441] * _1094[_9445].xx);
                                bool _7770 = any(bool2(_7767.x < int2(0, 0).x, _7767.y < int2(0, 0).y));
                                bool _7778;
                                if (!_7770)
                                {
                                    _7778 = any(bool2(_7767.x >= cbFI_MvDepthLaneSize.x, _7767.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7778 = _7770;
                                }
                                if (_7778)
                                {
                                    _10667 = _9442;
                                    break;
                                }
                                uint4 _7856 = r_warped_motion_qdata_tp1.Load(int3(_7767, 0));
                                uint _7857 = _7856.x;
                                if (_7857 != 0u)
                                {
                                    _10667 = min(_9442, _7857);
                                    break;
                                }
                                _9445++;
                                continue;
                            }
                            else
                            {
                                _10667 = _9442;
                                break;
                            }
                        }
                    }
                    float _9444;
                    if (_9442 == 4294967295u)
                    {
                        _9444 = -1.0f;
                    }
                    else
                    {
                        float _9443;
                        if (_9442 == 0u)
                        {
                            _9443 = -1.0f;
                        }
                        else
                        {
                            _9443 = float((_9442 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9444 = _9443;
                    }
                    _9457 = _9444;
                    break;
                } while(false);
                float4 _9486;
                if (_9457 >= 0.0f)
                {
                    float _7878 = (exp((_9457 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4594;
                    if (_4372)
                    {
                        uint _7885_dummy_parameter;
                        _4594 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_9074 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7885_dummy_parameter))))), 0)).x) > _7878;
                    }
                    else
                    {
                        _4594 = _4372;
                    }
                    float4 _9475;
                    if (_4594)
                    {
                        float4 _8960 = _9462;
                        _8960.z = 0.0f;
                        _9475 = _8960;
                    }
                    else
                    {
                        _9475 = _9462;
                    }
                    bool _4606;
                    if (_4378)
                    {
                        uint _7905_dummy_parameter;
                        _4606 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_9075 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7905_dummy_parameter))))), 0)).x) > _7878;
                    }
                    else
                    {
                        _4606 = _4378;
                    }
                    float4 _9487;
                    if (_4606)
                    {
                        float4 _8962 = _9475;
                        _8962.w = 0.0f;
                        _9487 = _8962;
                    }
                    else
                    {
                        _9487 = _9475;
                    }
                    _9486 = _9487;
                }
                else
                {
                    _9486 = _9462;
                }
                _9485 = _9486;
            }
            else
            {
                _9485 = _9462;
            }
            bool _4614 = _4360 != _4366;
            bool _4621;
            if (_4614)
            {
                _4621 = _4360 ? _4306 : _4309;
            }
            else
            {
                _4621 = _4614;
            }
            bool _4628;
            if (_4621)
            {
                _4628 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _4628 = _4621;
            }
            float4 _9570;
            if (_4628)
            {
                bool2 _4633 = _4360.xx;
                float2 _4634 = float2(_4633.x ? _9071.x : _9073.x, _4633.y ? _9071.y : _9073.y);
                float _9477;
                if (_4360)
                {
                    uint _7925_dummy_parameter;
                    _9477 = r_depth_tm1.Load(int3(int2(floor(_4634 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7925_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7941_dummy_parameter;
                    _9477 = r_depth_tp1.Load(int3(int2(floor(_4634 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7941_dummy_parameter))))), 0)).x;
                }
                float4x4 _9478;
                if (_4360)
                {
                    _9478 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9478 = cbFI_MotionTP1ToTM1;
                }
                float2 _9479;
                do
                {
                    float _7968 = _4634.x;
                    float _7971 = 1.0f - _4634.y;
                    float4 _7982 = mul(float4((float2(_7968, _7971) * 2.0f) - 1.0f.xx, _9477, 1.0f), _9478);
                    float _7984 = _7982.w;
                    if (!(_7984 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9479 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7997 = ((_7982.xy / _7984.xx) + 1.0f.xx) * 0.5f;
                    _9479 = float2(_7997.x - _7968, _7971 - _7997.y);
                    break;
                } while(false);
                float2 _4664 = float2(cbFI_DisplaySize);
                float4 _9571;
                if (!(length(((_4634 + _9479) - float2(_4633.x ? _9073.x : _9071.x, _4633.y ? _9073.y : _9071.y)) * _4664) <= ((0.100000001490116119384765625f * length(_9479 * _4664)) + 8.0f)))
                {
                    float4 _9572;
                    if (_4360)
                    {
                        float4 _8972 = _9485;
                        _8972.x = 0.0f;
                        _9572 = _8972;
                    }
                    else
                    {
                        float4 _8974 = _9485;
                        _8974.y = 0.0f;
                        _9572 = _8974;
                    }
                    _9571 = _9572;
                }
                else
                {
                    _9571 = _9485;
                }
                _9570 = _9571;
            }
            else
            {
                _9570 = _9485;
            }
            float4 _4689 = _9255 * _9570;
            float _4691 = dot(_4689, 1.0f.xxxx);
            float4 _9750;
            bool _9770;
            if (_4691 > 0.0f)
            {
                _9770 = _9224;
                _9750 = _4689 / _4691.xxxx;
            }
            else
            {
                bool _4702 = any(bool4(_9570.x < 1.0f.xxxx.x, _9570.y < 1.0f.xxxx.y, _9570.z < 1.0f.xxxx.z, _9570.w < 1.0f.xxxx.w));
                if (_4702)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8019;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _8019);
                    }
                }
                bool4 _10697 = _4702.xxxx;
                _9770 = _4702 ? true : _9224;
                _9750 = float4(_10697.x ? 0.0f.xxxx.x : _9255.x, _10697.y ? 0.0f.xxxx.y : _9255.y, _10697.z ? 0.0f.xxxx.z : _9255.z, _10697.w ? 0.0f.xxxx.w : _9255.w);
            }
            _9883 = _9922;
            _9769 = _9770;
            _9749 = _9750;
        }
        else
        {
            _9883 = float3(0.0f, 0.0f, 0.5f);
            _9769 = _9224;
            _9749 = _9255;
        }
        uint _4711 = (cbFI_pad0 >> 24u) & 31u;
        uint _4715 = (cbFI_pad0 >> 16u) & 255u;
        bool _4717 = _4711 != 0u;
        bool _4719 = _4715 == 12u;
        bool _4722 = _4715 == 13u;
        float4 _9766;
        if ((_4717 || _4719) || _4722)
        {
            float _9573;
            do
            {
                bool _8103 = all(bool2(_9074.x > 0.0f.xx.x, _9074.y > 0.0f.xx.y));
                bool _8109;
                if (_8103)
                {
                    _8109 = all(bool2(_9074.x < 1.0f.xx.x, _9074.y < 1.0f.xx.y));
                }
                else
                {
                    _8109 = _8103;
                }
                bool _8040 = !_8109;
                bool _8047;
                if (!_8040)
                {
                    bool _8114 = all(bool2(_9075.x > 0.0f.xx.x, _9075.y > 0.0f.xx.y));
                    bool _8120;
                    if (_8114)
                    {
                        _8120 = all(bool2(_9075.x < 1.0f.xx.x, _9075.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8120 = _8114;
                    }
                    _8047 = !_8120;
                }
                else
                {
                    _8047 = _8040;
                }
                if (_8047)
                {
                    _9573 = 0.0f;
                    break;
                }
                uint _8127_dummy_parameter;
                uint _8143_dummy_parameter;
                float4 _8068 = mul(float4((float2(_9074.x, 1.0f - _9074.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_9074 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8127_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _8070 = _8068.w;
                if (abs(_8070) < 9.9999999747524270787835121154785e-07f)
                {
                    _9573 = 0.0f;
                    break;
                }
                float _8081 = abs(cbFI_DeviceToViewDepth.y / ((_8068.z / _8070) - cbFI_DeviceToViewDepth.x));
                float _8084 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_9075 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8143_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9573 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8081 - _8084) / max(max(_8081, _8084), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8191 = all(bool2(_9075.x > 0.0f.xx.x, _9075.y > 0.0f.xx.y));
            bool _8197;
            if (_8191)
            {
                _8197 = all(bool2(_9075.x < 1.0f.xx.x, _9075.y < 1.0f.xx.y));
            }
            else
            {
                _8197 = _8191;
            }
            float _9574;
            if (_8197)
            {
                uint _8204_dummy_parameter;
                _9574 = length((_5498 + (r_motion_tp1.Load(int3(int2(floor(_9075 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8204_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9574 = 1000000.0f;
            }
            float _9585;
            if ((_4711 & 1u) != 0u)
            {
                _9585 = _9573;
            }
            else
            {
                _9585 = 1.0f;
            }
            float _9586;
            if ((_4711 & 2u) != 0u)
            {
                _9586 = _9585 * (1.0f - smoothstep(2.0f, 8.0f, _9574));
            }
            else
            {
                _9586 = _9585;
            }
            float _9587;
            if ((_4711 & 4u) != 0u)
            {
                _9587 = _9586 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6219 - _6227) - length(_6203 - _6211))));
            }
            else
            {
                _9587 = _9586;
            }
            float _9760;
            if ((_4711 & 8u) != 0u)
            {
                _9760 = lerp(1.0f, _9587, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6203 - _6211)));
            }
            else
            {
                _9760 = _9587;
            }
            bool _4797 = (_4711 & 16u) != 0u;
            bool _4806;
            if (_4797)
            {
                _4806 = length(_9069 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4806 = _4797;
            }
            float _10699 = _4806 ? 1.0f : _9760;
            bool _4812 = _4717 && _6412;
            bool _4817;
            if (_4812)
            {
                bool _8229 = all(bool2(_9071.x > 0.0f.xx.x, _9071.y > 0.0f.xx.y));
                bool _8235;
                if (_8229)
                {
                    _8235 = all(bool2(_9071.x < 1.0f.xx.x, _9071.y < 1.0f.xx.y));
                }
                else
                {
                    _8235 = _8229;
                }
                _4817 = _8235;
            }
            else
            {
                _4817 = _4812;
            }
            bool _4822;
            if (_4817)
            {
                bool _8240 = all(bool2(_9073.x > 0.0f.xx.x, _9073.y > 0.0f.xx.y));
                bool _8246;
                if (_8240)
                {
                    _8246 = all(bool2(_9073.x < 1.0f.xx.x, _9073.y < 1.0f.xx.y));
                }
                else
                {
                    _8246 = _8240;
                }
                _4822 = _8246;
            }
            else
            {
                _4822 = _4817;
            }
            float4 _9767;
            if (_4822)
            {
                float _4828 = _9749.x + _9749.y;
                float _4837 = (_9749.z + _9749.w) * (1.0f - _10699);
                float _9763;
                if (_4828 > 9.9999997473787516355514526367188e-06f)
                {
                    _9763 = _9749.x / _4828;
                }
                else
                {
                    _9763 = _3971;
                }
                _9767 = float4(_9749.x + (_4837 * _9763), _9749.y + (_4837 * (1.0f - _9763)), _9749.zw * _10699);
            }
            else
            {
                _9767 = _9749;
            }
            _9766 = _9767;
        }
        else
        {
            _9766 = _9749;
        }
        float3 _10470;
        if (_9769)
        {
            float3 _8252 = r_current_interpolation_source.Load(int3(_3384, 0)).xyz;
            float3 _10471;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6412)
            {
                uint _8259_dummy_parameter;
                float _9874;
                _9874 = r_depth_tm1.Load(int3(int2(floor(_9071 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8259_dummy_parameter))))), 0)).x;
                float _4949;
                for (int _9873 = 0; _9873 < 24; _9874 = _4949, _9873++)
                {
                    float _4921 = float(_9873 & 7) * 0.785398185253143310546875f;
                    int _4923 = _9873 >> 3;
                    int _10521;
                    if (_4923 == 0)
                    {
                        _10521 = 16;
                    }
                    else
                    {
                        _10521 = (_4923 == 1) ? 48 : 96;
                    }
                    uint _8279_dummy_parameter;
                    _4949 = max(_9874, r_depth_tm1.Load(int3(int2(floor(clamp(_9071 + ((cbFI_MvDepthLaneSizeRcp * float(_10521)) * float2(cos(_4921), sin(_4921))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8279_dummy_parameter))))), 0)).x);
                }
                float2 _9875;
                do
                {
                    float _8301 = 1.0f - _9071.y;
                    float4 _8312 = mul(float4((float2(_9071.x, _8301) * 2.0f) - 1.0f.xx, _9874, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8314 = _8312.w;
                    if (!(_8314 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9875 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8327 = ((_8312.xy / _8314.xx) + 1.0f.xx) * 0.5f;
                    _9875 = float2(_8327.x - _9071.x, _8301 - _8327.y);
                    break;
                } while(false);
                float2 _4960 = _9071 + _9875;
                bool _8345 = all(bool2(_4960.x > 0.0f.xx.x, _4960.y > 0.0f.xx.y));
                bool _8351;
                if (_8345)
                {
                    _8351 = all(bool2(_4960.x < 1.0f.xx.x, _4960.y < 1.0f.xx.y));
                }
                else
                {
                    _8351 = _8345;
                }
                float3 _10472;
                if (_8351)
                {
                    float _4966 = abs(cbFI_DeviceToViewDepth.y / (_9874 - cbFI_DeviceToViewDepth.x));
                    uint _8371_dummy_parameter;
                    int2 _8371 = int2(spvTextureSize(r_depth_m2, uint(0), _8371_dummy_parameter));
                    float _4970 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4960 * float2(_8371))), int2(0, 0), _8371 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10477;
                    if (abs(_4970 - _4966) <= (0.20000000298023223876953125f * max(_4970, _4966)))
                    {
                        uint _8405_dummy_parameter;
                        int2 _8405 = int2(spvTextureSize(r_colour_m2, uint(0), _8405_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8428;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8428);
                        }
                        _10477 = r_colour_m2.Load(int3(clamp(int2(floor(_4960 * float2(_8405))), int2(0, 0), _8405 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8438;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8438);
                        }
                        _10477 = _8252;
                    }
                    _10472 = _10477;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8448;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8448);
                    }
                    _10472 = _8252;
                }
                _10471 = _10472;
            }
            else
            {
                _10471 = _8252;
            }
            _10470 = _10471;
        }
        else
        {
            _10470 = (((_6203 * _9766.x) + (_6211 * _9766.y)) + (_6219 * _9766.z)) + (_6227 * _9766.w);
        }
        uint _4998 = cbFI_pad0 & 255u;
        bool _10362;
        float3 _10469;
        if (_4998 != 0u)
        {
            float3 _5003 = r_present_backbuffer.Load(int3(_3384, 0)).xyz;
            float3 _5007 = r_current_interpolation_source.Load(int3(_3384, 0)).xyz;
            float3 _5011 = abs(_5003 - _5007);
            float3 _9878;
            if (_4998 == 2u)
            {
                _9878 = (abs(_5007) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9878 = 0.000244140625f.xxx;
            }
            bool _5027 = any(bool3(_5011.x > _9878.x, _5011.y > _9878.y, _5011.z > _9878.z));
            bool3 _10700 = _5027.xxx;
            _10469 = float3(_10700.x ? _5003.x : _10470.x, _10700.y ? _5003.y : _10470.y, _10700.z ? _5003.z : _10470.z);
            _10362 = _5027;
        }
        else
        {
            _10469 = _10470;
            _10362 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8463;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8463);
        }
        float3 _10452;
        if (_4715 == 1u)
        {
            _10452 = lerp(_6203, _6211, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10453;
            if (_4715 == 2u)
            {
                _10453 = lerp(_6219, _6227, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10454;
                if (_4715 == 3u)
                {
                    _10454 = float(_10362).xxx;
                }
                else
                {
                    float3 _10455;
                    if (_4715 == 4u)
                    {
                        _10455 = float3(((_9069 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10456;
                        if (_4715 == 5u)
                        {
                            _10456 = float3(((_5498 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10457;
                            if (_4715 == 6u)
                            {
                                _10457 = float3(_9766.xy, _9766.z + _9766.w);
                            }
                            else
                            {
                                float3 _10458;
                                if (_4715 == 7u)
                                {
                                    _10458 = r_current_interpolation_source.Load(int3(_3384, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10459;
                                    if (_4715 == 8u)
                                    {
                                        _10459 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3746, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10460;
                                        if (_4719)
                                        {
                                            uint _8485_dummy_parameter;
                                            uint _8517_dummy_parameter;
                                            _10460 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3746 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8485_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3746 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8517_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10461;
                                            if (_4722)
                                            {
                                                _10461 = _6219;
                                            }
                                            else
                                            {
                                                float3 _10462;
                                                if (_4715 == 20u)
                                                {
                                                    _10462 = _6203;
                                                }
                                                else
                                                {
                                                    float3 _10463;
                                                    if (_4715 == 21u)
                                                    {
                                                        _10463 = _6211;
                                                    }
                                                    else
                                                    {
                                                        float3 _10464;
                                                        if (_4715 == 22u)
                                                        {
                                                            _10464 = _6227;
                                                        }
                                                        else
                                                        {
                                                            float3 _10465;
                                                            if (_4715 == 18u)
                                                            {
                                                                _10465 = _10168;
                                                            }
                                                            else
                                                            {
                                                                float3 _10466;
                                                                if (_4715 == 19u)
                                                                {
                                                                    _10466 = _10022;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _10702 = (_4715 == 23u).xxx;
                                                                    _10466 = float3(_10702.x ? _9883.x : _10469.x, _10702.y ? _9883.y : _10469.y, _10702.z ? _9883.z : _10469.z);
                                                                }
                                                                _10465 = _10466;
                                                            }
                                                            _10464 = _10465;
                                                        }
                                                        _10463 = _10464;
                                                    }
                                                    _10462 = _10463;
                                                }
                                                _10461 = _10462;
                                            }
                                            _10460 = _10461;
                                        }
                                        _10459 = _10460;
                                    }
                                    _10458 = _10459;
                                }
                                _10457 = _10458;
                            }
                            _10456 = _10457;
                        }
                        _10455 = _10456;
                    }
                    _10454 = _10455;
                }
                _10453 = _10454;
            }
            _10452 = _10453;
        }
        float3 _10451;
        if ((_4715 >= 9u) && (_4715 <= 11u))
        {
            uint _5191 = 64u + uint((_9101.y * cbFI_MvDepthLaneSize.x) + _9101.x);
            uint _5195 = rw_nfru_diagnostics.Load<uint>(_5191 * 4 + 0) & 15u;
            float3 _10482;
            if (_4715 == 10u)
            {
                float3 _10450;
                if ((rw_nfru_diagnostics.Load<uint>(_5191 * 4 + 0) & 32u) != 0u)
                {
                    _10450 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10449;
                    if ((rw_nfru_diagnostics.Load<uint>(_5191 * 4 + 0) & 16u) != 0u)
                    {
                        _10449 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5216 = ((rw_nfru_diagnostics.Load<uint>(_5191 * 4 + 0) & 64u) != 0u).xxx;
                        _10449 = float3(_5216.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5216.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5216.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10450 = _10449;
                }
                _10482 = _10450;
            }
            else
            {
                float3 _10483;
                if (_4715 == 11u)
                {
                    uint _5229 = (rw_nfru_diagnostics.Load<uint>(_5191 * 4 + 0) >> 8u) & 15u;
                    uint _5232 = (rw_nfru_diagnostics.Load<uint>(_5191 * 4 + 0) >> 12u) & 15u;
                    float3 _10442;
                    if ((_5195 == 2u) || (_5195 == 3u))
                    {
                        _10442 = _3097[_5195];
                    }
                    else
                    {
                        bool _5244 = _5229 == 3u;
                        bool _5246 = _5232 == 3u;
                        float3 _10443;
                        if (_5244 && _5246)
                        {
                            _10443 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10444;
                            if (_5244)
                            {
                                _10444 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10445;
                                if (_5246)
                                {
                                    _10445 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10446;
                                    if ((_5229 == 4u) || (_5232 == 4u))
                                    {
                                        _10446 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10447;
                                        if ((_5229 == 1u) || (_5232 == 1u))
                                        {
                                            _10447 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10704 = (_5195 == 1u).xxx;
                                            _10447 = float3(_10704.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10704.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10704.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10446 = _10447;
                                    }
                                    _10445 = _10446;
                                }
                                _10444 = _10445;
                            }
                            _10443 = _10444;
                        }
                        _10442 = _10443;
                    }
                    _10483 = _10442;
                }
                else
                {
                    _10483 = _3097[min(_5195, 7u)];
                }
                _10482 = _10483;
            }
            _10451 = _10482;
        }
        else
        {
            _10451 = _10452;
        }
        float4 _10486;
        if ((_4715 >= 14u) && (_4715 <= 16u))
        {
            float2 _10484;
            if (_4715 == 14u)
            {
                uint _5302_dummy_parameter;
                uint _5308_dummy_parameter;
                _10484 = r_flow_tm1.Load(int3(clamp(int2(floor(_3746 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5302_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5308_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10485;
                if (_4715 == 16u)
                {
                    uint _8568 = r_warped_flow_qdata_tm1.Load(int3(_3762, 0)).x & 2147483647u;
                    uint _8600 = uint(max((int((_8568 >> 16u) & 15u) - 6), 0));
                    _10485 = ((float2(float((1 - (2 * int((_8568 >> 15u) & 1u))) * int(((_8568 >> uint(7)) & 127u) << _8600)), float((1 - (2 * int((_8568 >> 14u) & 1u))) * int((_8568 & 127u) << _8600))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10485 = _5498 * float2(cbFI_DisplaySize);
                }
                _10484 = _10485;
            }
            uint2 _5341 = uint2(clamp(round(_10484 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5343 = _5341.x;
            uint _5350 = _5341.y;
            _10486 = float4(float(_5343 & 255u), float((_5343 >> 8u) | ((_5350 & 15u) << 4u)), float(_5350 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10487;
            if (_4715 == 17u)
            {
                _10487 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3762, 0)).x != 0u), _4105, 0.0f, 1.0f);
            }
            else
            {
                _10487 = float4(_10451, 1.0f);
            }
            _10486 = _10487;
        }
        rw_output[_3384] = _10486.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5394 = ((uint(_3384.y) * uint(cbFI_DisplaySize.x)) + uint(_3384.x)) * 6u;
            uint _8646 = spvPackHalf2x16(clamp(_6202.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5394 * 4 + 0, (((_8646 & 32767u) >> 4u) | ((((_8646 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6202.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8681 = spvPackHalf2x16(clamp(_6210.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5394 + 1u) * 4 + 0, (((_8681 & 32767u) >> 4u) | ((((_8681 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6210.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8716 = spvPackHalf2x16(clamp(_6218.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5394 + 2u) * 4 + 0, (((_8716 & 32767u) >> 4u) | ((((_8716 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6218.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8751 = spvPackHalf2x16(clamp(_6226.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5394 + 3u) * 4 + 0, (((_8751 & 32767u) >> 4u) | ((((_8751 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6226.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8778 = r_current_interpolation_source.Load(int3(_3384, 0));
            uint _8792 = spvPackHalf2x16(clamp(_8778.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5394 + 4u) * 4 + 0, (((_8792 & 32767u) >> 4u) | ((((_8792 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8778.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10520;
            if (_10362 || (_4715 != 0u))
            {
                _10520 = 4294967295u;
            }
            else
            {
                uint _8827 = spvPackHalf2x16(clamp(_10486.xy, 0.0f.xx, 65000.0f.xx));
                _10520 = (((_8827 & 32767u) >> 4u) | ((((_8827 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10486.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5394 + 5u) * 4 + 0, _10520);
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
