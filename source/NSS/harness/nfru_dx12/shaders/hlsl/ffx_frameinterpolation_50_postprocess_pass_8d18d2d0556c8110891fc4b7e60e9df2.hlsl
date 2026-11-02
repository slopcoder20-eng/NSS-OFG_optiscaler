static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3365[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3652 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3652.x >= cbFI_DisplaySize.x, _3652.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3652] = float4(r_present_backbuffer.Load(int3(_3652, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4047 = (float2(_3652) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4058 = int2(floor(_4047 * float2(cbFI_MvDepthLaneSize)));
        int2 _4063 = int2(floor(_4047 * float2(cbFI_FlowLaneSize)));
        float4 _6025 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4047 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6031 = r_warped_filled_flow_tm1.Load(int3(_4063, 0)).xy;
        float2 _6037 = r_warped_filled_motion_tp1.Load(int3(_4058, 0)).xy;
        bool _6059 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10199;
        if (_6059)
        {
            float _6072 = ((2.0f * _4047.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10199 = float2(atan(_6072) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4047.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6072 * _6072))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10199 = _4047;
        }
        bool _4084 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10220;
        bool _10241;
        int2 _10252;
        float3 _11681;
        if (_4084)
        {
            float _10201;
            float _10203;
            _10203 = 2.0f;
            _10201 = -1.0f;
            uint _3714[9];
            float _12123;
            float _12126;
            for (int _10200 = 0; _10200 < 9; _10203 = _12126, _10201 = _12123, _10200++)
            {
                _3714[_10200] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4058 + int2((_10200 % 3) - 1, (_10200 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3714[_10200] != 0u)
                {
                    float _12118;
                    if (_3714[_10200] == 0u)
                    {
                        _12118 = -1.0f;
                    }
                    else
                    {
                        _12118 = float((_3714[_10200] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12126 = min(_10203, _12118);
                    _12123 = max(_10201, _12118);
                }
                else
                {
                    _12126 = _10203;
                    _12123 = _10201;
                }
            }
            float _4130 = float(_10201 >= 0.0f);
            float3 _9992 = 0.0f.xxx;
            _9992.y = _4130;
            float2 _10221;
            bool _10242;
            int2 _10253;
            float3 _11682;
            if ((_10201 - _10203) > 0.0199999995529651641845703125f)
            {
                float _10209;
                int2 _10210;
                float2 _10211;
                int2 _10213;
                float2 _10219;
                _10219 = _6037;
                _10213 = _4058;
                _10211 = _6037;
                _10210 = _4058;
                _10209 = -1.0f;
                float _12131;
                int2 _12135;
                float2 _12146;
                int2 _12157;
                float2 _12190;
                float _12237;
                int _10208 = 0;
                float _12099 = 1000000000.0f;
                for (; _10208 < 9; _12099 = _12237, _10219 = _12190, _10213 = _12157, _10211 = _12146, _10210 = _12135, _10209 = _12131, _10208++)
                {
                    if (_3714[_10208] == 0u)
                    {
                        _12237 = _12099;
                        _12190 = _10219;
                        _12157 = _10213;
                        _12146 = _10211;
                        _12135 = _10210;
                        _12131 = _10209;
                        continue;
                    }
                    int2 _4165 = clamp(_4058 + int2((_10208 % 3) - 1, (_10208 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6147 = _3714[_10208] & 2147483647u;
                    uint _6179 = uint(max((int((_6147 >> 16u) & 15u) - 6), 0));
                    float2 _4171 = (float2(float((1 - (2 * int((_6147 >> 15u) & 1u))) * int(((_6147 >> uint(7)) & 127u) << _6179)), float((1 - (2 * int((_6147 >> 14u) & 1u))) * int((_6147 & 127u) << _6179))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12085;
                    if (_3714[_10208] == 0u)
                    {
                        _12085 = -1.0f;
                    }
                    else
                    {
                        _12085 = float((_3714[_10208] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4176 = _12085 - 0.100000001490116119384765625f;
                    float2 _12086;
                    if (_6059)
                    {
                        float2 _6256 = clamp((((_10199 + (_4171 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6259 = tan(_6256.x);
                        _12086 = (float2(_6259 / cbFI_DeviceToViewDepth.z, (tan(_6256.y) * sqrt(1.0f + (_6259 * _6259))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12086 = _10199 + (_4171 * cbFI_Timestep);
                    }
                    float _4183 = cbFI_Timestep - 1.0f;
                    float2 _12087;
                    if (_6059)
                    {
                        float2 _6327 = clamp((((_10199 + (_4171 * _4183)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6330 = tan(_6327.x);
                        _12087 = (float2(_6330 / cbFI_DeviceToViewDepth.z, (tan(_6327.y) * sqrt(1.0f + (_6330 * _6330))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12087 = _10199 + (_4171 * _4183);
                    }
                    bool _6363 = all(bool2(_12086.x > 0.0f.xx.x, _12086.y > 0.0f.xx.y));
                    bool _6369;
                    if (_6363)
                    {
                        _6369 = all(bool2(_12086.x < 1.0f.xx.x, _12086.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6369 = _6363;
                    }
                    float _12090;
                    if (_6369)
                    {
                        uint _6376_dummy_parameter;
                        _12090 = max((_4176 - (log((r_depth_tm1.Load(int3(int2(floor(_12086 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6376_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12090 = 0.0f;
                    }
                    bool _6406 = all(bool2(_12087.x > 0.0f.xx.x, _12087.y > 0.0f.xx.y));
                    bool _6412;
                    if (_6406)
                    {
                        _6412 = all(bool2(_12087.x < 1.0f.xx.x, _12087.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6412 = _6406;
                    }
                    float _12091;
                    if (_6412)
                    {
                        uint _6419_dummy_parameter;
                        _12091 = _12090 + max((_4176 - (log((r_depth_tp1.Load(int3(int2(floor(_12087 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6419_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12091 = _12090;
                    }
                    float _12132;
                    int2 _12136;
                    float2 _12147;
                    int2 _12158;
                    float2 _12191;
                    float _12238;
                    if (_12091 == 0.0f)
                    {
                        bool _4218 = _4176 > _10209;
                        bool2 _12246 = _4218.xx;
                        _12238 = _12099;
                        _12191 = float2(_12246.x ? _4171.x : _10219.x, _12246.y ? _4171.y : _10219.y);
                        _12158 = int2(_12246.x ? _4165.x : _10213.x, _12246.y ? _4165.y : _10213.y);
                        _12147 = _10211;
                        _12136 = _10210;
                        _12132 = _4218 ? _4176 : _10209;
                    }
                    else
                    {
                        bool _4227 = _12091 < _12099;
                        bool2 _12242 = _4227.xx;
                        _12238 = _4227 ? _12091 : _12099;
                        _12191 = _10219;
                        _12158 = _10213;
                        _12147 = float2(_12242.x ? _4171.x : _10211.x, _12242.y ? _4171.y : _10211.y);
                        _12136 = int2(_12242.x ? _4165.x : _10210.x, _12242.y ? _4165.y : _10210.y);
                        _12132 = _10209;
                    }
                    _12237 = _12238;
                    _12190 = _12191;
                    _12157 = _12158;
                    _12146 = _12147;
                    _12135 = _12136;
                    _12131 = _12132;
                }
                bool _4239 = _10209 < 0.0f;
                bool2 _12252 = _4239.xx;
                int2 _12255 = int2(_12252.x ? _10210.x : _10213.x, _12252.y ? _10210.y : _10213.y);
                _11682 = float3(1.0f, _4130, float(any(bool2(_12255.x != _4058.x, _12255.y != _4058.y))));
                _10253 = _12255;
                _10242 = _4239 ? false : true;
                _10221 = float2(_12252.x ? _10211.x : _10219.x, _12252.y ? _10211.y : _10219.y);
            }
            else
            {
                _11682 = _9992;
                _10253 = _4058;
                _10242 = false;
                _10221 = _6037;
            }
            _11681 = _11682;
            _10252 = _10253;
            _10241 = _10242;
            _10220 = _10221;
        }
        else
        {
            _11681 = 0.0f.xxx;
            _10252 = _4058;
            _10241 = false;
            _10220 = _6037;
        }
        float2 _10222;
        if (_6059)
        {
            float2 _6484 = clamp((((_10199 + (_10220 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6487 = tan(_6484.x);
            _10222 = (float2(_6487 / cbFI_DeviceToViewDepth.z, (tan(_6484.y) * sqrt(1.0f + (_6487 * _6487))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10222 = _10199 + (_10220 * cbFI_Timestep);
        }
        float _4262 = cbFI_Timestep - 1.0f;
        float2 _10224;
        if (_6059)
        {
            float2 _6555 = clamp((((_10199 + (_10220 * _4262)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6558 = tan(_6555.x);
            _10224 = (float2(_6558 / cbFI_DeviceToViewDepth.z, (tan(_6555.y) * sqrt(1.0f + (_6558 * _6558))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10224 = _10199 + (_10220 * _4262);
        }
        float _4267 = -cbFI_Timestep;
        float2 _10225;
        if (_6059)
        {
            float2 _6626 = clamp((((_10199 + (_6031 * _4267)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6629 = tan(_6626.x);
            _10225 = (float2(_6629 / cbFI_DeviceToViewDepth.z, (tan(_6626.y) * sqrt(1.0f + (_6629 * _6629))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10225 = _10199 + (_6031 * _4267);
        }
        float _4272 = 1.0f - cbFI_Timestep;
        float2 _10226;
        if (_6059)
        {
            float2 _6697 = clamp((((_10199 + (_6031 * _4272)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6700 = tan(_6697.x);
            _10226 = (float2(_6700 / cbFI_DeviceToViewDepth.z, (tan(_6697.y) * sqrt(1.0f + (_6700 * _6700))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10226 = _10199 + (_6031 * _4272);
        }
        float4 _6735 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10222, 0.0f);
        float3 _6736 = _6735.xyz;
        float4 _6743 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10224, 0.0f);
        float3 _6744 = _6743.xyz;
        float4 _6751 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10225, 0.0f);
        float3 _6752 = _6751.xyz;
        float4 _6759 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10226, 0.0f);
        float3 _6760 = _6759.xyz;
        float4 _6774 = exp(_6025 - max(max(max(_6025.x, _6025.y), _6025.z), _6025.w).xxxx);
        float4 _6781 = _6774 / (dot(_6774, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4291 = _4084 && (!_10241);
        bool _4300;
        if (_4291)
        {
            _4300 = (_6781.z + _6781.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4300 = _4291;
        }
        bool _4311;
        if (_4300)
        {
            _4311 = length((_10225 - _10222) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4311 = _4300;
        }
        bool _10265;
        if (_4311)
        {
            uint4 _6800 = r_warped_motion_qdata_tp1.Load(int3(_10252, 0));
            uint _6801 = _6800.x;
            bool _10268;
            if (_6801 != 0u)
            {
                float _10254;
                if (_6801 == 0u)
                {
                    _10254 = -1.0f;
                }
                else
                {
                    _10254 = float((_6801 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4321 = _10254 - 0.12000000476837158203125f;
                bool _6820 = all(bool2(_10225.x > 0.0f.xx.x, _10225.y > 0.0f.xx.y));
                bool _6826;
                if (_6820)
                {
                    _6826 = all(bool2(_10225.x < 1.0f.xx.x, _10225.y < 1.0f.xx.y));
                }
                else
                {
                    _6826 = _6820;
                }
                bool _4331;
                if (_6826)
                {
                    uint _6833_dummy_parameter;
                    _4331 = (log((r_depth_tm1.Load(int3(int2(floor(_10225 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6833_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4321;
                }
                else
                {
                    _4331 = _6826;
                }
                bool _4345;
                if (!_4331)
                {
                    bool _6863 = all(bool2(_10226.x > 0.0f.xx.x, _10226.y > 0.0f.xx.y));
                    bool _6869;
                    if (_6863)
                    {
                        _6869 = all(bool2(_10226.x < 1.0f.xx.x, _10226.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6869 = _6863;
                    }
                    bool _4343;
                    if (_6869)
                    {
                        uint _6876_dummy_parameter;
                        _4343 = (log((r_depth_tp1.Load(int3(int2(floor(_10226 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6876_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4321;
                    }
                    else
                    {
                        _4343 = _6869;
                    }
                    _4345 = _4343;
                }
                else
                {
                    _4345 = _4331;
                }
                _10268 = _4345;
            }
            else
            {
                _10268 = false;
            }
            _10265 = _10268;
        }
        else
        {
            _10265 = false;
        }
        bool _4350 = _10241 || _10265;
        bool _4355;
        if (_4350)
        {
            bool _6906 = all(bool2(_10222.x > 0.0f.xx.x, _10222.y > 0.0f.xx.y));
            bool _6912;
            if (_6906)
            {
                _6912 = all(bool2(_10222.x < 1.0f.xx.x, _10222.y < 1.0f.xx.y));
            }
            else
            {
                _6912 = _6906;
            }
            _4355 = _6912;
        }
        else
        {
            _4355 = _4350;
        }
        bool _4360;
        if (_4355)
        {
            bool _6917 = all(bool2(_10224.x > 0.0f.xx.x, _10224.y > 0.0f.xx.y));
            bool _6923;
            if (_6917)
            {
                _6923 = all(bool2(_10224.x < 1.0f.xx.x, _10224.y < 1.0f.xx.y));
            }
            else
            {
                _6923 = _6917;
            }
            _4360 = _6923;
        }
        else
        {
            _4360 = _4355;
        }
        float4 _10362;
        if (_4360)
        {
            float _4363 = _6781.x;
            float _4365 = _6781.y;
            float _4366 = _4363 + _4365;
            float _4371 = _6781.z + _6781.w;
            float _10283;
            if (_4366 > 0.001000000047497451305389404296875f)
            {
                _10283 = _4363 / _4366;
            }
            else
            {
                _10283 = _4272;
            }
            _10362 = float4(_4363 + (_4371 * _10283), _4365 + (_4371 * (1.0f - _10283)), 0.0f, 0.0f);
        }
        else
        {
            _10362 = _6781;
        }
        bool _6951 = (cbFI_pad0 & 1024u) != 0u;
        bool _6927 = !_6951;
        bool _6928 = !_6927;
        bool _6945;
        if (_6928)
        {
            _6945 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10252.y * cbFI_MvDepthLaneSize.x) + _10252.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6945 = _6927;
        }
        bool _6977;
        if (_6928)
        {
            _6977 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4063.y * cbFI_FlowLaneSize.x) + _4063.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6977 = _6927;
        }
        float _4406 = float(_6977);
        bool _10375;
        float4 _10406;
        float3 _11485;
        if (_6951)
        {
            bool _4416;
            if (_6945)
            {
                _4416 = all(bool2(_10222.x > 0.0f.xx.x, _10222.y > 0.0f.xx.y));
            }
            else
            {
                _4416 = _6945;
            }
            bool _4422;
            if (_4416)
            {
                _4422 = all(bool2(_10222.x < 1.0f.xx.x, _10222.y < 1.0f.xx.y));
            }
            else
            {
                _4422 = _4416;
            }
            bool _4429;
            if (_6945)
            {
                _4429 = all(bool2(_10224.x > 0.0f.xx.x, _10224.y > 0.0f.xx.y));
            }
            else
            {
                _4429 = _6945;
            }
            bool _4435;
            if (_4429)
            {
                _4435 = all(bool2(_10224.x < 1.0f.xx.x, _10224.y < 1.0f.xx.y));
            }
            else
            {
                _4435 = _4429;
            }
            bool _4442;
            if (_6977)
            {
                _4442 = all(bool2(_10225.x > 0.0f.xx.x, _10225.y > 0.0f.xx.y));
            }
            else
            {
                _4442 = _6977;
            }
            bool _4448;
            if (_4442)
            {
                _4448 = all(bool2(_10225.x < 1.0f.xx.x, _10225.y < 1.0f.xx.y));
            }
            else
            {
                _4448 = _4442;
            }
            bool _4455;
            if (_6977)
            {
                _4455 = all(bool2(_10226.x > 0.0f.xx.x, _10226.y > 0.0f.xx.y));
            }
            else
            {
                _4455 = _6977;
            }
            bool _4461;
            if (_4455)
            {
                _4461 = all(bool2(_10226.x < 1.0f.xx.x, _10226.y < 1.0f.xx.y));
            }
            else
            {
                _4461 = _4455;
            }
            bool _4463 = !_6945;
            if (_4463)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7019;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7019);
                }
            }
            bool _4468 = !_6977;
            if (_4468)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7029;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7029);
                }
            }
            if (_6945 && _4468)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7039;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7039);
                }
            }
            if (_4463 && _6977)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7049;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7049);
                }
            }
            float _4487 = float(_4422);
            float _4489 = float(_4435);
            bool _4492 = _4448 && _4461;
            float _10317;
            if (_4492)
            {
                _10317 = 1.0f;
            }
            else
            {
                _10317 = (_4448 || _4461) ? 0.5f : 0.0f;
            }
            bool _10322;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4422)) && (!_4435))
            {
                bool _4522;
                if (_4492)
                {
                    float _10320;
                    do
                    {
                        bool _7133 = all(bool2(_10225.x > 0.0f.xx.x, _10225.y > 0.0f.xx.y));
                        bool _7139;
                        if (_7133)
                        {
                            _7139 = all(bool2(_10225.x < 1.0f.xx.x, _10225.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7139 = _7133;
                        }
                        bool _7070 = !_7139;
                        bool _7077;
                        if (!_7070)
                        {
                            bool _7144 = all(bool2(_10226.x > 0.0f.xx.x, _10226.y > 0.0f.xx.y));
                            bool _7150;
                            if (_7144)
                            {
                                _7150 = all(bool2(_10226.x < 1.0f.xx.x, _10226.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7150 = _7144;
                            }
                            _7077 = !_7150;
                        }
                        else
                        {
                            _7077 = _7070;
                        }
                        if (_7077)
                        {
                            _10320 = 0.0f;
                            break;
                        }
                        uint _7157_dummy_parameter;
                        uint _7173_dummy_parameter;
                        float4 _7098 = mul(float4((float2(_10225.x, 1.0f - _10225.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10225 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7157_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7100 = _7098.w;
                        if (abs(_7100) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10320 = 0.0f;
                            break;
                        }
                        float _7111 = abs(cbFI_DeviceToViewDepth.y / ((_7098.z / _7100) - cbFI_DeviceToViewDepth.x));
                        float _7114 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10226 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7173_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10320 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7111 - _7114) / max(max(_7111, _7114), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4522 = _10320 >= 0.5f;
                }
                else
                {
                    _4522 = _4492;
                }
                bool _4530;
                if (_4522)
                {
                    _4530 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4530 = _4522;
                }
                bool _10323;
                if (_4530)
                {
                    uint _7223_dummy_parameter;
                    float2 _10321;
                    do
                    {
                        float _7249 = 1.0f - _10225.y;
                        float4 _7260 = mul(float4((float2(_10225.x, _7249) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10225 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7223_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7262 = _7260.w;
                        if (!(_7262 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10321 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7275 = ((_7260.xy / _7262.xx) + 1.0f.xx) * 0.5f;
                        _10321 = float2(_7275.x - _10225.x, _7249 - _7275.y);
                        break;
                    } while(false);
                    float2 _4543 = float2(cbFI_DisplaySize);
                    _10323 = length(((_10225 + _10321) - _10226) * _4543) <= ((0.100000001490116119384765625f * length(_10321 * _4543)) + 8.0f);
                }
                else
                {
                    _10323 = _4522;
                }
                _10322 = _10323;
            }
            else
            {
                _10322 = true;
            }
            bool _4557 = !_10322;
            bool _12256 = _4557 ? false : _4461;
            bool _12257 = _4557 ? false : _4448;
            bool _10376;
            float4 _10407;
            if (!(((_4422 && _4435) && _12257) && _12256))
            {
                float4 _4579 = _10362 * float4(_4487, _4489, float(_12257), float(_12256));
                float _4581 = dot(_4579, 1.0f.xxxx);
                bool _4584 = !(_4581 > 0.0f);
                float4 _10408;
                if (!_4584)
                {
                    _10408 = _4579 / _4581.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7297;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7297);
                    }
                    _10408 = 0.0f.xxxx;
                }
                _10407 = _10408;
                _10376 = _4584;
            }
            else
            {
                _10407 = _10362;
                _10376 = false;
            }
            _11485 = float3(_4487, _4489, _10317);
            _10406 = _10407;
            _10375 = _10376;
        }
        else
        {
            _11485 = float3(float(_6945), _4406, 0.0f);
            _10406 = _10362;
            _10375 = false;
        }
        bool _4602 = !_10375;
        float4 _10470;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4602)
        {
            float _4609 = _10406.x + _10406.y;
            float4 _10471;
            if (_4609 > 0.001000000047497451305389404296875f)
            {
                _10471 = float4(_10406.x / _4609, _10406.y / _4609, 0.0f, 0.0f);
            }
            else
            {
                _10471 = float4(_4272, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10470 = _10471;
        }
        else
        {
            _10470 = _10406;
        }
        float4 _10594;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4602) && _6945)
        {
            float _10465;
            do
            {
                uint4 _7437 = r_warped_motion_qdata_tp1.Load(int3(_10252, 0));
                uint _7438 = _7437.x;
                if (_7438 != 0u)
                {
                    float _10464;
                    if (_7438 == 0u)
                    {
                        _10464 = -1.0f;
                    }
                    else
                    {
                        _10464 = float((_7438 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10465 = _10464;
                    break;
                }
                int _10447;
                uint _10448;
                _10448 = _7438;
                _10447 = -1;
                uint _10463;
                for (; _10447 <= 1; _10448 = _10463, _10447++)
                {
                    _10463 = _10448;
                    for (int _10461 = -1; _10461 <= 1; )
                    {
                        _10463 = max(_10463, r_warped_motion_qdata_tp1.Load(int3(clamp(_10252 + int2(_10461, _10447), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10461++;
                        continue;
                    }
                }
                if (_10448 != 0u)
                {
                    float _10460;
                    if (_10448 == 0u)
                    {
                        _10460 = -1.0f;
                    }
                    else
                    {
                        _10460 = float((_10448 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10465 = _10460;
                    break;
                }
                uint _10450;
                _10450 = 4294967295u;
                uint _12227;
                for (int _10449 = 0; _10449 < 8; _10450 = _12227, _10449++)
                {
                    int _10453 = 0;
                    for (;;)
                    {
                        if (_10453 < 5)
                        {
                            int2 _7388 = _10252 + (_1085[_10449] * _1094[_10453].xx);
                            bool _7391 = any(bool2(_7388.x < int2(0, 0).x, _7388.y < int2(0, 0).y));
                            bool _7399;
                            if (!_7391)
                            {
                                _7399 = any(bool2(_7388.x >= cbFI_MvDepthLaneSize.x, _7388.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7399 = _7391;
                            }
                            if (_7399)
                            {
                                _12227 = _10450;
                                break;
                            }
                            uint4 _7477 = r_warped_motion_qdata_tp1.Load(int3(_7388, 0));
                            uint _7478 = _7477.x;
                            if (_7478 != 0u)
                            {
                                _12227 = min(_10450, _7478);
                                break;
                            }
                            _10453++;
                            continue;
                        }
                        else
                        {
                            _12227 = _10450;
                            break;
                        }
                    }
                }
                float _10452;
                if (_10450 == 4294967295u)
                {
                    _10452 = -1.0f;
                }
                else
                {
                    float _10451;
                    if (_10450 == 0u)
                    {
                        _10451 = -1.0f;
                    }
                    else
                    {
                        _10451 = float((_10450 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10452 = _10451;
                }
                _10465 = _10452;
                break;
            } while(false);
            float _4645 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4647 = _10465 < 0.0f;
            bool _4652;
            if (_4647)
            {
                bool _7497 = all(bool2(_10222.x > 0.0f.xx.x, _10222.y > 0.0f.xx.y));
                bool _7503;
                if (_7497)
                {
                    _7503 = all(bool2(_10222.x < 1.0f.xx.x, _10222.y < 1.0f.xx.y));
                }
                else
                {
                    _7503 = _7497;
                }
                _4652 = _7503;
            }
            else
            {
                _4652 = _4647;
            }
            bool _4657;
            if (_4652)
            {
                bool _7508 = all(bool2(_10224.x > 0.0f.xx.x, _10224.y > 0.0f.xx.y));
                bool _7514;
                if (_7508)
                {
                    _7514 = all(bool2(_10224.x < 1.0f.xx.x, _10224.y < 1.0f.xx.y));
                }
                else
                {
                    _7514 = _7508;
                }
                _4657 = _7514;
            }
            else
            {
                _4657 = _4652;
            }
            float4 _10527;
            if (_4657)
            {
                uint _7521_dummy_parameter;
                float _7545 = log((r_depth_tm1.Load(int3(int2(floor(_10222 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7521_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _7553_dummy_parameter;
                float _7577 = log((r_depth_tp1.Load(int3(int2(floor(_10224 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7553_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _4668 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4675;
                if (_4668)
                {
                    _4675 = _7577 > (_7545 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4675 = _4668;
                }
                float4 _10501;
                if (_4675)
                {
                    _10501 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10501 = 1.0f.xxxx;
                }
                bool _4682 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4689;
                if (_4682)
                {
                    _4689 = _7545 > (_7577 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4689 = _4682;
                }
                float4 _10530;
                if (_4689)
                {
                    float4 _10062 = _10501;
                    _10062.x = 0.0f;
                    _10530 = _10062;
                }
                else
                {
                    _10530 = _10501;
                }
                _10527 = _10530;
            }
            else
            {
                bool _4697 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4703;
                if (_4697)
                {
                    _4703 = _10470.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4703 = _4697;
                }
                bool _4708;
                if (_4703)
                {
                    bool _7583 = all(bool2(_10224.x > 0.0f.xx.x, _10224.y > 0.0f.xx.y));
                    bool _7589;
                    if (_7583)
                    {
                        _7589 = all(bool2(_10224.x < 1.0f.xx.x, _10224.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7589 = _7583;
                    }
                    _4708 = _7589;
                }
                else
                {
                    _4708 = _4703;
                }
                float4 _10528;
                if (_4708)
                {
                    float _10488;
                    if (_10465 >= 0.0f)
                    {
                        _10488 = _10465 - _4645;
                    }
                    else
                    {
                        float _10484;
                        _10484 = 2.0f;
                        float _7646;
                        for (int _10483 = 0; _10483 < 24; _10484 = _7646, _10483++)
                        {
                            float _7610 = float(_10483 & 7) * 0.785398185253143310546875f;
                            int _7612 = _10483 >> 3;
                            int _10485;
                            if (_7612 == 0)
                            {
                                _10485 = 16;
                            }
                            else
                            {
                                _10485 = (_7612 == 1) ? 48 : 96;
                            }
                            uint _7678_dummy_parameter;
                            _7646 = min(_10484, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10224 + ((cbFI_MvDepthLaneSizeRcp * float(_10485)) * float2(cos(_7610), sin(_7610))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7678_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10488 = _10484;
                    }
                    uint _7710_dummy_parameter;
                    float4 _10529;
                    if (r_depth_tp1.Load(int3(int2(floor(_10224 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7710_dummy_parameter))))), 0)).x > ((exp((_10488 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10529 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10529 = 1.0f.xxxx;
                    }
                    _10528 = _10529;
                }
                else
                {
                    _10528 = 1.0f.xxxx;
                }
                _10527 = _10528;
            }
            bool _4734 = _10465 >= 0.0f;
            bool _4741;
            if (_4734)
            {
                _4741 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4741 = _4734;
            }
            bool _4747;
            if (_4741)
            {
                _4747 = _10470.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4747 = _4741;
            }
            bool _4752;
            if (_4747)
            {
                bool _7734 = all(bool2(_10222.x > 0.0f.xx.x, _10222.y > 0.0f.xx.y));
                bool _7740;
                if (_7734)
                {
                    _7740 = all(bool2(_10222.x < 1.0f.xx.x, _10222.y < 1.0f.xx.y));
                }
                else
                {
                    _7740 = _7734;
                }
                _4752 = _7740;
            }
            else
            {
                _4752 = _4747;
            }
            float4 _10533;
            if (_4752)
            {
                float _10521;
                if (_4734)
                {
                    _10521 = _10465 - _4645;
                }
                else
                {
                    float _10517;
                    _10517 = 2.0f;
                    float _7797;
                    for (int _10516 = 0; _10516 < 24; _10517 = _7797, _10516++)
                    {
                        float _7761 = float(_10516 & 7) * 0.785398185253143310546875f;
                        int _7763 = _10516 >> 3;
                        int _10518;
                        if (_7763 == 0)
                        {
                            _10518 = 16;
                        }
                        else
                        {
                            _10518 = (_7763 == 1) ? 48 : 96;
                        }
                        uint _7813_dummy_parameter;
                        _7797 = min(_10517, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10222 + ((cbFI_MvDepthLaneSizeRcp * float(_10518)) * float2(cos(_7761), sin(_7761))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7813_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10521 = _10517;
                }
                uint _7861_dummy_parameter;
                float4 _10534;
                if (r_depth_tm1.Load(int3(int2(floor(_10222 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7861_dummy_parameter))))), 0)).x > ((exp((_10521 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10068 = _10527;
                    _10068.x = 0.0f;
                    _10534 = _10068;
                }
                else
                {
                    _10534 = _10527;
                }
                _10533 = _10534;
            }
            else
            {
                _10533 = _10527;
            }
            float4 _10595;
            if (any(bool4(_10533.x < 1.0f.xxxx.x, _10533.y < 1.0f.xxxx.y, _10533.z < 1.0f.xxxx.z, _10533.w < 1.0f.xxxx.w)))
            {
                float4 _4782 = _10470 * _10533;
                float _4784 = dot(_4782, 1.0f.xxxx);
                float4 _10596;
                if (_4784 > 0.0f)
                {
                    _10596 = _4782 / _4784.xxxx;
                }
                else
                {
                    bool _4795 = _10533.y == 0.0f;
                    bool _4801;
                    if (_4795)
                    {
                        _4801 = _10533.x > 0.0f;
                    }
                    else
                    {
                        _4801 = _4795;
                    }
                    bool _4806;
                    if (_4801)
                    {
                        bool _7885 = all(bool2(_10222.x > 0.0f.xx.x, _10222.y > 0.0f.xx.y));
                        bool _7891;
                        if (_7885)
                        {
                            _7891 = all(bool2(_10222.x < 1.0f.xx.x, _10222.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7891 = _7885;
                        }
                        _4806 = _7891;
                    }
                    else
                    {
                        _4806 = _4801;
                    }
                    float4 _10597;
                    if (_4806)
                    {
                        _10597 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4811 = _10533.x == 0.0f;
                        bool _4817;
                        if (_4811)
                        {
                            _4817 = _10533.y > 0.0f;
                        }
                        else
                        {
                            _4817 = _4811;
                        }
                        bool _4822;
                        if (_4817)
                        {
                            bool _7896 = all(bool2(_10224.x > 0.0f.xx.x, _10224.y > 0.0f.xx.y));
                            bool _7902;
                            if (_7896)
                            {
                                _7902 = all(bool2(_10224.x < 1.0f.xx.x, _10224.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7902 = _7896;
                            }
                            _4822 = _7902;
                        }
                        else
                        {
                            _4822 = _4817;
                        }
                        bool4 _12258 = _4822.xxxx;
                        _10597 = float4(_12258.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10470.x, _12258.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10470.y, _12258.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10470.z, _12258.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10470.w);
                    }
                    _10596 = _10597;
                }
                _10595 = _10596;
            }
            else
            {
                _10595 = _10470;
            }
            _10594 = _10595;
        }
        else
        {
            _10594 = _10470;
        }
        float4 _11160;
        bool _11180;
        float3 _11294;
        if (((cbFI_pad0 & 32768u) != 0u) && _4602)
        {
            bool _4839 = _10594.x > 0.00999999977648258209228515625f;
            bool _4842 = _10594.y > 0.00999999977648258209228515625f;
            bool _4851 = (_10594.z + _10594.w) > 0.0199999995529651641845703125f;
            bool _4857;
            if (_4851)
            {
                bool _7907 = all(bool2(_10225.x > 0.0f.xx.x, _10225.y > 0.0f.xx.y));
                bool _7913;
                if (_7907)
                {
                    _7913 = all(bool2(_10225.x < 1.0f.xx.x, _10225.y < 1.0f.xx.y));
                }
                else
                {
                    _7913 = _7907;
                }
                _4857 = _7913;
            }
            else
            {
                _4857 = _4851;
            }
            bool _4862;
            if (_4857)
            {
                bool _7918 = all(bool2(_10226.x > 0.0f.xx.x, _10226.y > 0.0f.xx.y));
                bool _7924;
                if (_7918)
                {
                    _7924 = all(bool2(_10226.x < 1.0f.xx.x, _10226.y < 1.0f.xx.y));
                }
                else
                {
                    _7924 = _7918;
                }
                _4862 = _7924;
            }
            else
            {
                _4862 = _4857;
            }
            bool _4869;
            if (_4862)
            {
                float _10605;
                do
                {
                    bool _8007 = all(bool2(_10225.x > 0.0f.xx.x, _10225.y > 0.0f.xx.y));
                    bool _8013;
                    if (_8007)
                    {
                        _8013 = all(bool2(_10225.x < 1.0f.xx.x, _10225.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8013 = _8007;
                    }
                    bool _7944 = !_8013;
                    bool _7951;
                    if (!_7944)
                    {
                        bool _8018 = all(bool2(_10226.x > 0.0f.xx.x, _10226.y > 0.0f.xx.y));
                        bool _8024;
                        if (_8018)
                        {
                            _8024 = all(bool2(_10226.x < 1.0f.xx.x, _10226.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8024 = _8018;
                        }
                        _7951 = !_8024;
                    }
                    else
                    {
                        _7951 = _7944;
                    }
                    if (_7951)
                    {
                        _10605 = 0.0f;
                        break;
                    }
                    uint _8031_dummy_parameter;
                    uint _8047_dummy_parameter;
                    float4 _7972 = mul(float4((float2(_10225.x, 1.0f - _10225.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10225 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8031_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _7974 = _7972.w;
                    if (abs(_7974) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10605 = 0.0f;
                        break;
                    }
                    float _7985 = abs(cbFI_DeviceToViewDepth.y / ((_7972.z / _7974) - cbFI_DeviceToViewDepth.x));
                    float _7988 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10226 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8047_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10605 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7985 - _7988) / max(max(_7985, _7988), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4869 = _10605 < 0.5f;
            }
            else
            {
                _4869 = _4862;
            }
            float4 _10620;
            if (_4869)
            {
                uint _8097_dummy_parameter;
                uint _8128_dummy_parameter;
                float4 _10621;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10225 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8097_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10226 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8128_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10621 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10621 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10620 = _10621;
            }
            else
            {
                _10620 = 1.0f.xxxx;
            }
            bool _4893;
            if (_6945)
            {
                bool _8157 = all(bool2(_10222.x > 0.0f.xx.x, _10222.y > 0.0f.xx.y));
                bool _8163;
                if (_8157)
                {
                    _8163 = all(bool2(_10222.x < 1.0f.xx.x, _10222.y < 1.0f.xx.y));
                }
                else
                {
                    _8163 = _8157;
                }
                _4893 = _8163;
            }
            else
            {
                _4893 = _6945;
            }
            bool _4899;
            if (_6945)
            {
                bool _8168 = all(bool2(_10224.x > 0.0f.xx.x, _10224.y > 0.0f.xx.y));
                bool _8174;
                if (_8168)
                {
                    _8174 = all(bool2(_10224.x < 1.0f.xx.x, _10224.y < 1.0f.xx.y));
                }
                else
                {
                    _8174 = _8168;
                }
                _4899 = _8174;
            }
            else
            {
                _4899 = _6945;
            }
            bool _4905;
            if (_6977)
            {
                bool _8179 = all(bool2(_10225.x > 0.0f.xx.x, _10225.y > 0.0f.xx.y));
                bool _8185;
                if (_8179)
                {
                    _8185 = all(bool2(_10225.x < 1.0f.xx.x, _10225.y < 1.0f.xx.y));
                }
                else
                {
                    _8185 = _8179;
                }
                _4905 = _8185;
            }
            else
            {
                _4905 = _6977;
            }
            bool _4911;
            if (_6977)
            {
                bool _8190 = all(bool2(_10226.x > 0.0f.xx.x, _10226.y > 0.0f.xx.y));
                bool _8196;
                if (_8190)
                {
                    _8196 = all(bool2(_10226.x < 1.0f.xx.x, _10226.y < 1.0f.xx.y));
                }
                else
                {
                    _8196 = _8190;
                }
                _4911 = _8196;
            }
            else
            {
                _4911 = _6977;
            }
            bool _4914 = _4905 != _4911;
            bool _4920;
            if (_4914)
            {
                _4920 = _4893 || _4899;
            }
            else
            {
                _4920 = _4914;
            }
            float4 _10718;
            if (_4920)
            {
                float4 _10095 = _10620;
                _10095.z = 0.0f;
                _10095.w = 0.0f;
                _10718 = _10095;
            }
            else
            {
                _10718 = _10620;
            }
            bool _4927 = _4893 && _4839;
            bool _4930 = _4899 && _4842;
            float4 _10823;
            float3 _11383;
            if (_4927 || _4930)
            {
                float _10713;
                do
                {
                    uint4 _8335 = r_warped_motion_qdata_tp1.Load(int3(_10252, 0));
                    uint _8336 = _8335.x;
                    if (_8336 != 0u)
                    {
                        float _10712;
                        if (_8336 == 0u)
                        {
                            _10712 = -1.0f;
                        }
                        else
                        {
                            _10712 = float((_8336 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10713 = _10712;
                        break;
                    }
                    int _10695;
                    uint _10696;
                    _10696 = _8336;
                    _10695 = -1;
                    uint _10711;
                    for (; _10695 <= 1; _10696 = _10711, _10695++)
                    {
                        _10711 = _10696;
                        for (int _10709 = -1; _10709 <= 1; )
                        {
                            _10711 = max(_10711, r_warped_motion_qdata_tp1.Load(int3(clamp(_10252 + int2(_10709, _10695), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
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
                    uint _12228;
                    for (int _10697 = 0; _10697 < 8; _10698 = _12228, _10697++)
                    {
                        int _10701 = 0;
                        for (;;)
                        {
                            if (_10701 < 5)
                            {
                                int2 _8286 = _10252 + (_1085[_10697] * _1094[_10701].xx);
                                bool _8289 = any(bool2(_8286.x < int2(0, 0).x, _8286.y < int2(0, 0).y));
                                bool _8297;
                                if (!_8289)
                                {
                                    _8297 = any(bool2(_8286.x >= cbFI_MvDepthLaneSize.x, _8286.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8297 = _8289;
                                }
                                if (_8297)
                                {
                                    _12228 = _10698;
                                    break;
                                }
                                uint4 _8375 = r_warped_motion_qdata_tp1.Load(int3(_8286, 0));
                                uint _8376 = _8375.x;
                                if (_8376 != 0u)
                                {
                                    _12228 = min(_10698, _8376);
                                    break;
                                }
                                _10701++;
                                continue;
                            }
                            else
                            {
                                _12228 = _10698;
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
                bool _4938 = _10713 < 0.0f;
                float _10714;
                if (_4938)
                {
                    _10714 = 0.0f;
                }
                else
                {
                    _10714 = _10713 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8397_dummy_parameter;
                uint _8429_dummy_parameter;
                float4 _10751;
                if ((_4938 && _4927) && _4930)
                {
                    uint _8461_dummy_parameter;
                    float _8485 = log((r_depth_tm1.Load(int3(int2(floor(_10222 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8461_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8493_dummy_parameter;
                    float _8517 = log((r_depth_tp1.Load(int3(int2(floor(_10224 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8493_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10752;
                    if (_8485 > (_8517 + 0.07999999821186065673828125f))
                    {
                        float4 _10099 = _10718;
                        _10099.x = 0.0f;
                        _10752 = _10099;
                    }
                    else
                    {
                        float4 _10753;
                        if (_8517 > (_8485 + 0.07999999821186065673828125f))
                        {
                            float4 _10101 = _10718;
                            _10101.y = 0.0f;
                            _10753 = _10101;
                        }
                        else
                        {
                            _10753 = _10718;
                        }
                        _10752 = _10753;
                    }
                    _10751 = _10752;
                }
                else
                {
                    _10751 = _10718;
                }
                float _4990 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4992 = _10713 >= 0.0f;
                float _10734;
                if (_4992)
                {
                    _10734 = _10713 - _4990;
                }
                else
                {
                    float _10730;
                    if (_4927)
                    {
                        float _10729;
                        _10729 = 2.0f;
                        float _8575;
                        for (int _10728 = 0; _10728 < 24; _10729 = _8575, _10728++)
                        {
                            float _8539 = float(_10728 & 7) * 0.785398185253143310546875f;
                            int _8541 = _10728 >> 3;
                            int _10731;
                            if (_8541 == 0)
                            {
                                _10731 = 16;
                            }
                            else
                            {
                                _10731 = (_8541 == 1) ? 48 : 96;
                            }
                            uint _8591_dummy_parameter;
                            _8575 = min(_10729, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10222 + ((cbFI_MvDepthLaneSizeRcp * float(_10731)) * float2(cos(_8539), sin(_8539))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8591_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10730 = _10729;
                    }
                    else
                    {
                        _10730 = 0.0f;
                    }
                    _10734 = _10730;
                }
                float _10741;
                if (_4992)
                {
                    _10741 = _10713 - _4990;
                }
                else
                {
                    float _10737;
                    if (_4930)
                    {
                        float _10736;
                        _10736 = 2.0f;
                        float _8689;
                        for (int _10735 = 0; _10735 < 24; _10736 = _8689, _10735++)
                        {
                            float _8653 = float(_10735 & 7) * 0.785398185253143310546875f;
                            int _8655 = _10735 >> 3;
                            int _10738;
                            if (_8655 == 0)
                            {
                                _10738 = 16;
                            }
                            else
                            {
                                _10738 = (_8655 == 1) ? 48 : 96;
                            }
                            uint _8721_dummy_parameter;
                            _8689 = min(_10736, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10224 + ((cbFI_MvDepthLaneSizeRcp * float(_10738)) * float2(cos(_8653), sin(_8653))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8721_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10737 = _10736;
                    }
                    else
                    {
                        _10737 = 0.0f;
                    }
                    _10741 = _10737;
                }
                float _10742;
                if (_4927)
                {
                    uint _8753_dummy_parameter;
                    _10742 = r_depth_tm1.Load(int3(int2(floor(_10222 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8753_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10742 = 0.0f;
                }
                float _10743;
                if (_4930)
                {
                    uint _8772_dummy_parameter;
                    _10743 = r_depth_tp1.Load(int3(int2(floor(_10224 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8772_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10743 = 0.0f;
                }
                bool _5047;
                if (_4927)
                {
                    _5047 = _10742 > ((exp((_10734 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5047 = _4927;
                }
                float4 _10759;
                if (_5047)
                {
                    float4 _10103 = _10751;
                    _10103.x = 0.0f;
                    _10759 = _10103;
                }
                else
                {
                    _10759 = _10751;
                }
                bool _5059;
                if (_4930)
                {
                    _5059 = _10743 > ((exp((_10741 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5059 = _4930;
                }
                float4 _10761;
                if (_5059)
                {
                    float4 _10105 = _10759;
                    _10105.y = 0.0f;
                    _10761 = _10105;
                }
                else
                {
                    _10761 = _10759;
                }
                float4 _10824;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4992)
                {
                    bool _5079;
                    if (_4927)
                    {
                        _5079 = _10742 < ((exp((_10734 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5079 = _4927;
                    }
                    float4 _10763;
                    if (_5079)
                    {
                        float4 _10107 = _10761;
                        _10107.x = 0.0f;
                        _10763 = _10107;
                    }
                    else
                    {
                        _10763 = _10761;
                    }
                    bool _5091;
                    if (_4930)
                    {
                        _5091 = _10743 < ((exp((_10741 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5091 = _4930;
                    }
                    float4 _10825;
                    if (_5091)
                    {
                        float4 _10109 = _10763;
                        _10109.y = 0.0f;
                        _10825 = _10109;
                    }
                    else
                    {
                        _10825 = _10763;
                    }
                    _10824 = _10825;
                }
                else
                {
                    _10824 = _10761;
                }
                _11383 = float3(_10714, log((r_depth_tm1.Load(int3(int2(floor(_10222 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8397_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_10224 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8429_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _10823 = _10824;
            }
            else
            {
                _11383 = float3(0.0f, 0.0f, 0.5f);
                _10823 = _10718;
            }
            bool _5102 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4851;
            bool _5108;
            if (_5102)
            {
                _5108 = _4905 || _4911;
            }
            else
            {
                _5108 = _5102;
            }
            float4 _10846;
            if (_5108)
            {
                float _10818;
                do
                {
                    uint4 _8951 = r_warped_motion_qdata_tp1.Load(int3(_10252, 0));
                    uint _8952 = _8951.x;
                    if (_8952 != 0u)
                    {
                        float _10817;
                        if (_8952 == 0u)
                        {
                            _10817 = -1.0f;
                        }
                        else
                        {
                            _10817 = float((_8952 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10818 = _10817;
                        break;
                    }
                    int _10800;
                    uint _10801;
                    _10801 = _8952;
                    _10800 = -1;
                    uint _10816;
                    for (; _10800 <= 1; _10801 = _10816, _10800++)
                    {
                        _10816 = _10801;
                        for (int _10814 = -1; _10814 <= 1; )
                        {
                            _10816 = max(_10816, r_warped_motion_qdata_tp1.Load(int3(clamp(_10252 + int2(_10814, _10800), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10814++;
                            continue;
                        }
                    }
                    if (_10801 != 0u)
                    {
                        float _10813;
                        if (_10801 == 0u)
                        {
                            _10813 = -1.0f;
                        }
                        else
                        {
                            _10813 = float((_10801 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10818 = _10813;
                        break;
                    }
                    uint _10803;
                    _10803 = 4294967295u;
                    uint _12229;
                    for (int _10802 = 0; _10802 < 8; _10803 = _12229, _10802++)
                    {
                        int _10806 = 0;
                        for (;;)
                        {
                            if (_10806 < 5)
                            {
                                int2 _8902 = _10252 + (_1085[_10802] * _1094[_10806].xx);
                                bool _8905 = any(bool2(_8902.x < int2(0, 0).x, _8902.y < int2(0, 0).y));
                                bool _8913;
                                if (!_8905)
                                {
                                    _8913 = any(bool2(_8902.x >= cbFI_MvDepthLaneSize.x, _8902.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8913 = _8905;
                                }
                                if (_8913)
                                {
                                    _12229 = _10803;
                                    break;
                                }
                                uint4 _8991 = r_warped_motion_qdata_tp1.Load(int3(_8902, 0));
                                uint _8992 = _8991.x;
                                if (_8992 != 0u)
                                {
                                    _12229 = min(_10803, _8992);
                                    break;
                                }
                                _10806++;
                                continue;
                            }
                            else
                            {
                                _12229 = _10803;
                                break;
                            }
                        }
                    }
                    float _10805;
                    if (_10803 == 4294967295u)
                    {
                        _10805 = -1.0f;
                    }
                    else
                    {
                        float _10804;
                        if (_10803 == 0u)
                        {
                            _10804 = -1.0f;
                        }
                        else
                        {
                            _10804 = float((_10803 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10805 = _10804;
                    }
                    _10818 = _10805;
                    break;
                } while(false);
                float4 _10847;
                if (_10818 >= 0.0f)
                {
                    float _9013 = (exp((_10818 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5127;
                    if (_4905)
                    {
                        uint _9020_dummy_parameter;
                        _5127 = r_depth_tm1.Load(int3(int2(floor(_10225 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9020_dummy_parameter))))), 0)).x > _9013;
                    }
                    else
                    {
                        _5127 = _4905;
                    }
                    float4 _10836;
                    if (_5127)
                    {
                        float4 _10111 = _10823;
                        _10111.z = 0.0f;
                        _10836 = _10111;
                    }
                    else
                    {
                        _10836 = _10823;
                    }
                    bool _5139;
                    if (_4911)
                    {
                        uint _9039_dummy_parameter;
                        _5139 = r_depth_tp1.Load(int3(int2(floor(_10226 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9039_dummy_parameter))))), 0)).x > _9013;
                    }
                    else
                    {
                        _5139 = _4911;
                    }
                    float4 _10848;
                    if (_5139)
                    {
                        float4 _10113 = _10836;
                        _10113.w = 0.0f;
                        _10848 = _10113;
                    }
                    else
                    {
                        _10848 = _10836;
                    }
                    _10847 = _10848;
                }
                else
                {
                    _10847 = _10823;
                }
                _10846 = _10847;
            }
            else
            {
                _10846 = _10823;
            }
            bool _5147 = _4893 != _4899;
            bool _5154;
            if (_5147)
            {
                _5154 = _4893 ? _4839 : _4842;
            }
            else
            {
                _5154 = _5147;
            }
            bool _5161;
            if (_5154)
            {
                _5161 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5161 = _5154;
            }
            float4 _10931;
            if (_5161)
            {
                bool2 _5166 = _4893.xx;
                float2 _5167 = float2(_5166.x ? _10222.x : _10224.x, _5166.y ? _10222.y : _10224.y);
                float _10838;
                if (_4893)
                {
                    uint _9058_dummy_parameter;
                    _10838 = r_depth_tm1.Load(int3(int2(floor(_5167 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9058_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9074_dummy_parameter;
                    _10838 = r_depth_tp1.Load(int3(int2(floor(_5167 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9074_dummy_parameter))))), 0)).x;
                }
                float4x4 _10839;
                if (_4893)
                {
                    _10839 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10839 = cbFI_MotionTP1ToTM1;
                }
                float2 _10840;
                do
                {
                    float _9101 = _5167.x;
                    float _9104 = 1.0f - _5167.y;
                    float4 _9115 = mul(float4((float2(_9101, _9104) * 2.0f) - 1.0f.xx, _10838, 1.0f), _10839);
                    float _9117 = _9115.w;
                    if (!(_9117 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10840 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9130 = ((_9115.xy / _9117.xx) + 1.0f.xx) * 0.5f;
                    _10840 = float2(_9130.x - _9101, _9104 - _9130.y);
                    break;
                } while(false);
                float2 _5197 = float2(cbFI_DisplaySize);
                float4 _10932;
                if (!(length(((_5167 + _10840) - float2(_5166.x ? _10224.x : _10222.x, _5166.y ? _10224.y : _10222.y)) * _5197) <= ((0.100000001490116119384765625f * length(_10840 * _5197)) + 8.0f)))
                {
                    float4 _10933;
                    if (_4893)
                    {
                        float4 _10123 = _10846;
                        _10123.x = 0.0f;
                        _10933 = _10123;
                    }
                    else
                    {
                        float4 _10125 = _10846;
                        _10125.y = 0.0f;
                        _10933 = _10125;
                    }
                    _10932 = _10933;
                }
                else
                {
                    _10932 = _10846;
                }
                _10931 = _10932;
            }
            else
            {
                _10931 = _10846;
            }
            float4 _5222 = _10594 * _10931;
            float _5224 = dot(_5222, 1.0f.xxxx);
            float4 _11161;
            bool _11181;
            if (_5224 > 0.0f)
            {
                _11181 = _10375;
                _11161 = _5222 / _5224.xxxx;
            }
            else
            {
                bool _5235 = any(bool4(_10931.x < 1.0f.xxxx.x, _10931.y < 1.0f.xxxx.y, _10931.z < 1.0f.xxxx.z, _10931.w < 1.0f.xxxx.w));
                if (_5235)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9152;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9152);
                    }
                }
                bool4 _12261 = _5235.xxxx;
                _11181 = _5235 ? true : _10375;
                _11161 = float4(_12261.x ? 0.0f.xxxx.x : _10594.x, _12261.y ? 0.0f.xxxx.y : _10594.y, _12261.z ? 0.0f.xxxx.z : _10594.z, _12261.w ? 0.0f.xxxx.w : _10594.w);
            }
            _11294 = _11383;
            _11180 = _11181;
            _11160 = _11161;
        }
        else
        {
            _11294 = float3(0.0f, 0.0f, 0.5f);
            _11180 = _10375;
            _11160 = _10594;
        }
        uint _5244 = (cbFI_pad0 >> 24u) & 31u;
        uint _5248 = (cbFI_pad0 >> 16u) & 255u;
        bool _5250 = _5244 != 0u;
        bool _5252 = _5248 == 12u;
        bool _5255 = _5248 == 13u;
        float4 _11177;
        if ((_5250 || _5252) || _5255)
        {
            float _10934;
            do
            {
                bool _9236 = all(bool2(_10225.x > 0.0f.xx.x, _10225.y > 0.0f.xx.y));
                bool _9242;
                if (_9236)
                {
                    _9242 = all(bool2(_10225.x < 1.0f.xx.x, _10225.y < 1.0f.xx.y));
                }
                else
                {
                    _9242 = _9236;
                }
                bool _9173 = !_9242;
                bool _9180;
                if (!_9173)
                {
                    bool _9247 = all(bool2(_10226.x > 0.0f.xx.x, _10226.y > 0.0f.xx.y));
                    bool _9253;
                    if (_9247)
                    {
                        _9253 = all(bool2(_10226.x < 1.0f.xx.x, _10226.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9253 = _9247;
                    }
                    _9180 = !_9253;
                }
                else
                {
                    _9180 = _9173;
                }
                if (_9180)
                {
                    _10934 = 0.0f;
                    break;
                }
                uint _9260_dummy_parameter;
                uint _9276_dummy_parameter;
                float4 _9201 = mul(float4((float2(_10225.x, 1.0f - _10225.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10225 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9260_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9203 = _9201.w;
                if (abs(_9203) < 9.9999999747524270787835121154785e-07f)
                {
                    _10934 = 0.0f;
                    break;
                }
                float _9214 = abs(cbFI_DeviceToViewDepth.y / ((_9201.z / _9203) - cbFI_DeviceToViewDepth.x));
                float _9217 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10226 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9276_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _10934 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9214 - _9217) / max(max(_9214, _9217), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9324 = all(bool2(_10226.x > 0.0f.xx.x, _10226.y > 0.0f.xx.y));
            bool _9330;
            if (_9324)
            {
                _9330 = all(bool2(_10226.x < 1.0f.xx.x, _10226.y < 1.0f.xx.y));
            }
            else
            {
                _9330 = _9324;
            }
            float _10935;
            if (_9330)
            {
                uint _9337_dummy_parameter;
                _10935 = length((_6031 + (r_motion_tp1.Load(int3(int2(floor(_10226 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9337_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _10935 = 1000000.0f;
            }
            float _10946;
            if ((_5244 & 1u) != 0u)
            {
                _10946 = _10934;
            }
            else
            {
                _10946 = 1.0f;
            }
            float _10947;
            if ((_5244 & 2u) != 0u)
            {
                _10947 = _10946 * (1.0f - smoothstep(2.0f, 8.0f, _10935));
            }
            else
            {
                _10947 = _10946;
            }
            float _10948;
            if ((_5244 & 4u) != 0u)
            {
                _10948 = _10947 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6752 - _6760) - length(_6736 - _6744))));
            }
            else
            {
                _10948 = _10947;
            }
            float _11171;
            if ((_5244 & 8u) != 0u)
            {
                _11171 = lerp(1.0f, _10948, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6736 - _6744)));
            }
            else
            {
                _11171 = _10948;
            }
            bool _5330 = (_5244 & 16u) != 0u;
            bool _5339;
            if (_5330)
            {
                _5339 = length(_10220 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5339 = _5330;
            }
            float _12263 = _5339 ? 1.0f : _11171;
            bool _5345 = _5250 && _6945;
            bool _5350;
            if (_5345)
            {
                bool _9362 = all(bool2(_10222.x > 0.0f.xx.x, _10222.y > 0.0f.xx.y));
                bool _9368;
                if (_9362)
                {
                    _9368 = all(bool2(_10222.x < 1.0f.xx.x, _10222.y < 1.0f.xx.y));
                }
                else
                {
                    _9368 = _9362;
                }
                _5350 = _9368;
            }
            else
            {
                _5350 = _5345;
            }
            bool _5355;
            if (_5350)
            {
                bool _9373 = all(bool2(_10224.x > 0.0f.xx.x, _10224.y > 0.0f.xx.y));
                bool _9379;
                if (_9373)
                {
                    _9379 = all(bool2(_10224.x < 1.0f.xx.x, _10224.y < 1.0f.xx.y));
                }
                else
                {
                    _9379 = _9373;
                }
                _5355 = _9379;
            }
            else
            {
                _5355 = _5350;
            }
            float4 _11178;
            if (_5355)
            {
                float _5361 = _11160.x + _11160.y;
                float _5370 = (_11160.z + _11160.w) * (1.0f - _12263);
                float _11174;
                if (_5361 > 9.9999997473787516355514526367188e-06f)
                {
                    _11174 = _11160.x / _5361;
                }
                else
                {
                    _11174 = _4272;
                }
                _11178 = float4(_11160.x + (_5370 * _11174), _11160.y + (_5370 * (1.0f - _11174)), _11160.zw * _12263);
            }
            else
            {
                _11178 = _11160;
            }
            _11177 = _11178;
        }
        else
        {
            _11177 = _11160;
        }
        float3 _12031;
        if (_11180)
        {
            float3 _9385 = r_current_interpolation_source.Load(int3(_3652, 0)).xyz;
            float3 _12032;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6945)
            {
                uint _9392_dummy_parameter;
                float _11285;
                _11285 = r_depth_tm1.Load(int3(int2(floor(_10222 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9392_dummy_parameter))))), 0)).x;
                float _5482;
                for (int _11284 = 0; _11284 < 24; _11285 = _5482, _11284++)
                {
                    float _5454 = float(_11284 & 7) * 0.785398185253143310546875f;
                    int _5456 = _11284 >> 3;
                    int _12082;
                    if (_5456 == 0)
                    {
                        _12082 = 16;
                    }
                    else
                    {
                        _12082 = (_5456 == 1) ? 48 : 96;
                    }
                    uint _9412_dummy_parameter;
                    _5482 = min(_11285, r_depth_tm1.Load(int3(int2(floor(clamp(_10222 + ((cbFI_MvDepthLaneSizeRcp * float(_12082)) * float2(cos(_5454), sin(_5454))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9412_dummy_parameter))))), 0)).x);
                }
                float2 _11286;
                do
                {
                    float _9434 = 1.0f - _10222.y;
                    float4 _9445 = mul(float4((float2(_10222.x, _9434) * 2.0f) - 1.0f.xx, _11285, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9447 = _9445.w;
                    if (!(_9447 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11286 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9460 = ((_9445.xy / _9447.xx) + 1.0f.xx) * 0.5f;
                    _11286 = float2(_9460.x - _10222.x, _9434 - _9460.y);
                    break;
                } while(false);
                float2 _5493 = _10222 + _11286;
                bool _9478 = all(bool2(_5493.x > 0.0f.xx.x, _5493.y > 0.0f.xx.y));
                bool _9484;
                if (_9478)
                {
                    _9484 = all(bool2(_5493.x < 1.0f.xx.x, _5493.y < 1.0f.xx.y));
                }
                else
                {
                    _9484 = _9478;
                }
                float3 _12033;
                if (_9484)
                {
                    float _5499 = abs(cbFI_DeviceToViewDepth.y / (_11285 - cbFI_DeviceToViewDepth.x));
                    uint _9504_dummy_parameter;
                    int2 _9504 = int2(spvTextureSize(r_depth_m2, uint(0), _9504_dummy_parameter));
                    float _5503 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5493 * float2(_9504))), int2(0, 0), _9504 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12038;
                    if (abs(_5503 - _5499) <= (0.20000000298023223876953125f * max(_5503, _5499)))
                    {
                        uint _9538_dummy_parameter;
                        int2 _9538 = int2(spvTextureSize(r_colour_m2, uint(0), _9538_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9561;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9561);
                        }
                        _12038 = r_colour_m2.Load(int3(clamp(int2(floor(_5493 * float2(_9538))), int2(0, 0), _9538 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9571;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9571);
                        }
                        _12038 = _9385;
                    }
                    _12033 = _12038;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9581;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9581);
                    }
                    _12033 = _9385;
                }
                _12032 = _12033;
            }
            else
            {
                _12032 = _9385;
            }
            _12031 = _12032;
        }
        else
        {
            _12031 = (((_6736 * _11177.x) + (_6744 * _11177.y)) + (_6752 * _11177.z)) + (_6760 * _11177.w);
        }
        uint _5531 = cbFI_pad0 & 255u;
        bool _11923;
        float3 _12030;
        if (_5531 != 0u)
        {
            float3 _5536 = r_present_backbuffer.Load(int3(_3652, 0)).xyz;
            float3 _5540 = r_current_interpolation_source.Load(int3(_3652, 0)).xyz;
            float3 _5544 = abs(_5536 - _5540);
            float3 _11289;
            if (_5531 == 2u)
            {
                _11289 = (abs(_5540) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11289 = 0.000244140625f.xxx;
            }
            bool _5560 = any(bool3(_5544.x > _11289.x, _5544.y > _11289.y, _5544.z > _11289.z));
            bool3 _12264 = _5560.xxx;
            _12030 = float3(_12264.x ? _5536.x : _12031.x, _12264.y ? _5536.y : _12031.y, _12264.z ? _5536.z : _12031.z);
            _11923 = _5560;
        }
        else
        {
            _12030 = _12031;
            _11923 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9596;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9596);
        }
        float3 _12013;
        if (_5248 == 1u)
        {
            _12013 = lerp(_6736, _6744, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12014;
            if (_5248 == 2u)
            {
                _12014 = lerp(_6752, _6760, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12015;
                if (_5248 == 3u)
                {
                    _12015 = float(_11923).xxx;
                }
                else
                {
                    float3 _12016;
                    if (_5248 == 4u)
                    {
                        _12016 = float3(((_10220 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12017;
                        if (_5248 == 5u)
                        {
                            _12017 = float3(((_6031 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12018;
                            if (_5248 == 6u)
                            {
                                _12018 = float3(_11177.xy, _11177.z + _11177.w);
                            }
                            else
                            {
                                float3 _12019;
                                if (_5248 == 7u)
                                {
                                    _12019 = r_current_interpolation_source.Load(int3(_3652, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12020;
                                    if (_5248 == 8u)
                                    {
                                        _12020 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4047, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12021;
                                        if (_5252)
                                        {
                                            uint _9618_dummy_parameter;
                                            uint _9650_dummy_parameter;
                                            _12021 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4047 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9618_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4047 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9650_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12022;
                                            if (_5255)
                                            {
                                                _12022 = _6752;
                                            }
                                            else
                                            {
                                                float3 _12023;
                                                if (_5248 == 20u)
                                                {
                                                    _12023 = _6736;
                                                }
                                                else
                                                {
                                                    float3 _12024;
                                                    if (_5248 == 21u)
                                                    {
                                                        _12024 = _6744;
                                                    }
                                                    else
                                                    {
                                                        float3 _12025;
                                                        if (_5248 == 22u)
                                                        {
                                                            _12025 = _6760;
                                                        }
                                                        else
                                                        {
                                                            float3 _12026;
                                                            if (_5248 == 18u)
                                                            {
                                                                _12026 = _11681;
                                                            }
                                                            else
                                                            {
                                                                float3 _12027;
                                                                if (_5248 == 19u)
                                                                {
                                                                    _12027 = _11485;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12266 = (_5248 == 23u).xxx;
                                                                    _12027 = float3(_12266.x ? _11294.x : _12030.x, _12266.y ? _11294.y : _12030.y, _12266.z ? _11294.z : _12030.z);
                                                                }
                                                                _12026 = _12027;
                                                            }
                                                            _12025 = _12026;
                                                        }
                                                        _12024 = _12025;
                                                    }
                                                    _12023 = _12024;
                                                }
                                                _12022 = _12023;
                                            }
                                            _12021 = _12022;
                                        }
                                        _12020 = _12021;
                                    }
                                    _12019 = _12020;
                                }
                                _12018 = _12019;
                            }
                            _12017 = _12018;
                        }
                        _12016 = _12017;
                    }
                    _12015 = _12016;
                }
                _12014 = _12015;
            }
            _12013 = _12014;
        }
        float3 _12012;
        if ((_5248 >= 9u) && (_5248 <= 11u))
        {
            uint _5724 = 64u + uint((_10252.y * cbFI_MvDepthLaneSize.x) + _10252.x);
            uint _5728 = rw_nfru_diagnostics.Load<uint>(_5724 * 4 + 0) & 15u;
            float3 _12043;
            if (_5248 == 10u)
            {
                float3 _12011;
                if ((rw_nfru_diagnostics.Load<uint>(_5724 * 4 + 0) & 32u) != 0u)
                {
                    _12011 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12010;
                    if ((rw_nfru_diagnostics.Load<uint>(_5724 * 4 + 0) & 16u) != 0u)
                    {
                        _12010 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5749 = ((rw_nfru_diagnostics.Load<uint>(_5724 * 4 + 0) & 64u) != 0u).xxx;
                        _12010 = float3(_5749.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5749.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5749.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12011 = _12010;
                }
                _12043 = _12011;
            }
            else
            {
                float3 _12044;
                if (_5248 == 11u)
                {
                    uint _5762 = (rw_nfru_diagnostics.Load<uint>(_5724 * 4 + 0) >> 8u) & 15u;
                    uint _5765 = (rw_nfru_diagnostics.Load<uint>(_5724 * 4 + 0) >> 12u) & 15u;
                    float3 _12003;
                    if ((_5728 == 2u) || (_5728 == 3u))
                    {
                        _12003 = _3365[_5728];
                    }
                    else
                    {
                        bool _5777 = _5762 == 3u;
                        bool _5779 = _5765 == 3u;
                        float3 _12004;
                        if (_5777 && _5779)
                        {
                            _12004 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12005;
                            if (_5777)
                            {
                                _12005 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12006;
                                if (_5779)
                                {
                                    _12006 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12007;
                                    if ((_5762 == 4u) || (_5765 == 4u))
                                    {
                                        _12007 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12008;
                                        if ((_5762 == 1u) || (_5765 == 1u))
                                        {
                                            _12008 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12268 = (_5728 == 1u).xxx;
                                            _12008 = float3(_12268.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12268.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12268.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12007 = _12008;
                                    }
                                    _12006 = _12007;
                                }
                                _12005 = _12006;
                            }
                            _12004 = _12005;
                        }
                        _12003 = _12004;
                    }
                    _12044 = _12003;
                }
                else
                {
                    _12044 = _3365[min(_5728, 7u)];
                }
                _12043 = _12044;
            }
            _12012 = _12043;
        }
        else
        {
            _12012 = _12013;
        }
        float4 _12047;
        if ((_5248 >= 14u) && (_5248 <= 16u))
        {
            float2 _12045;
            if (_5248 == 14u)
            {
                uint _5835_dummy_parameter;
                uint _5841_dummy_parameter;
                _12045 = r_flow_tm1.Load(int3(clamp(int2(floor(_4047 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5835_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5841_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12046;
                if (_5248 == 16u)
                {
                    uint _9701 = r_warped_flow_qdata_tm1.Load(int3(_4063, 0)).x & 2147483647u;
                    uint _9733 = uint(max((int((_9701 >> 16u) & 15u) - 6), 0));
                    _12046 = ((float2(float((1 - (2 * int((_9701 >> 15u) & 1u))) * int(((_9701 >> uint(7)) & 127u) << _9733)), float((1 - (2 * int((_9701 >> 14u) & 1u))) * int((_9701 & 127u) << _9733))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12046 = _6031 * float2(cbFI_DisplaySize);
                }
                _12045 = _12046;
            }
            uint2 _5874 = uint2(clamp(round(_12045 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5876 = _5874.x;
            uint _5883 = _5874.y;
            _12047 = float4(float(_5876 & 255u), float((_5876 >> 8u) | ((_5883 & 15u) << 4u)), float(_5883 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12048;
            if (_5248 == 17u)
            {
                _12048 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4063, 0)).x != 0u), _4406, 0.0f, 1.0f);
            }
            else
            {
                _12048 = float4(_12012, 1.0f);
            }
            _12047 = _12048;
        }
        rw_output[_3652] = _12047.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5927 = ((uint(_3652.y) * uint(cbFI_DisplaySize.x)) + uint(_3652.x)) * 6u;
            uint _9779 = spvPackHalf2x16(clamp(_6735.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5927 * 4 + 0, (((_9779 & 32767u) >> 4u) | ((((_9779 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6735.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9814 = spvPackHalf2x16(clamp(_6743.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5927 + 1u) * 4 + 0, (((_9814 & 32767u) >> 4u) | ((((_9814 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6743.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9849 = spvPackHalf2x16(clamp(_6751.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5927 + 2u) * 4 + 0, (((_9849 & 32767u) >> 4u) | ((((_9849 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6751.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9884 = spvPackHalf2x16(clamp(_6759.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5927 + 3u) * 4 + 0, (((_9884 & 32767u) >> 4u) | ((((_9884 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6759.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9911 = r_current_interpolation_source.Load(int3(_3652, 0));
            uint _9925 = spvPackHalf2x16(clamp(_9911.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5927 + 4u) * 4 + 0, (((_9925 & 32767u) >> 4u) | ((((_9925 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9911.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12081;
            if (_11923 || (_5248 != 0u))
            {
                _12081 = 4294967295u;
            }
            else
            {
                uint _9960 = spvPackHalf2x16(clamp(_12047.xy, 0.0f.xx, 65000.0f.xx));
                _12081 = (((_9960 & 32767u) >> 4u) | ((((_9960 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12047.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5927 + 5u) * 4 + 0, _12081);
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
