static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3067[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3371 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3371.x >= cbFI_DisplaySize.x, _3371.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3371] = float4(r_present_backbuffer.Load(int3(_3371, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3371] = float4(r_current_interpolation_source.Load(int3(_3371, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _3740 = (float2(_3371) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _3751 = int2(floor(_3740 * float2(cbFI_MvDepthLaneSize)));
        int2 _3756 = int2(floor(_3740 * float2(cbFI_FlowLaneSize)));
        float4 _5470 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_3740 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _5476 = r_warped_filled_flow_tm1.Load(int3(_3756, 0)).xy;
        float2 _5482 = r_warped_filled_motion_tp1.Load(int3(_3751, 0)).xy;
        bool _5504 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _8972;
        if (_5504)
        {
            float _5517 = ((2.0f * _3740.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _8972 = float2(atan(_5517) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3740.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_5517 * _5517))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _8972 = _3740;
        }
        bool _3777 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _8993;
        bool _9014;
        int2 _9025;
        float3 _9934;
        if (_3777)
        {
            float _8974;
            float _8976;
            _8976 = 2.0f;
            _8974 = -1.0f;
            uint _3435[9];
            float _10321;
            float _10324;
            for (int _8973 = 0; _8973 < 9; _8976 = _10324, _8974 = _10321, _8973++)
            {
                _3435[_8973] = r_warped_motion_qdata_tp1.Load(int3(clamp(_3751 + int2((_8973 % 3) - 1, (_8973 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3435[_8973] != 0u)
                {
                    float _10316;
                    if (_3435[_8973] == 0u)
                    {
                        _10316 = -1.0f;
                    }
                    else
                    {
                        _10316 = float((_3435[_8973] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10324 = min(_8976, _10316);
                    _10321 = max(_8974, _10316);
                }
                else
                {
                    _10324 = _8976;
                    _10321 = _8974;
                }
            }
            float _3823 = float(_8974 >= 0.0f);
            float3 _8783 = 0.0f.xxx;
            _8783.y = _3823;
            float2 _8994;
            bool _9015;
            int2 _9026;
            float3 _9935;
            if ((_8974 - _8976) > 0.0199999995529651641845703125f)
            {
                float _8982;
                int2 _8983;
                float2 _8984;
                int2 _8986;
                float2 _8992;
                _8992 = _5482;
                _8986 = _3751;
                _8984 = _5482;
                _8983 = _3751;
                _8982 = -1.0f;
                float _10329;
                int2 _10333;
                float2 _10344;
                int2 _10355;
                float2 _10388;
                float _10433;
                int _8981 = 0;
                float _10297 = 1000000000.0f;
                for (; _8981 < 9; _10297 = _10433, _8992 = _10388, _8986 = _10355, _8984 = _10344, _8983 = _10333, _8982 = _10329, _8981++)
                {
                    if (_3435[_8981] == 0u)
                    {
                        _10433 = _10297;
                        _10388 = _8992;
                        _10355 = _8986;
                        _10344 = _8984;
                        _10333 = _8983;
                        _10329 = _8982;
                        continue;
                    }
                    int2 _3858 = clamp(_3751 + int2((_8981 % 3) - 1, (_8981 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _5592 = _3435[_8981] & 2147483647u;
                    uint _5624 = uint(max((int((_5592 >> 16u) & 15u) - 6), 0));
                    float2 _3864 = (float2(float((1 - (2 * int((_5592 >> 15u) & 1u))) * int(((_5592 >> uint(7)) & 127u) << _5624)), float((1 - (2 * int((_5592 >> 14u) & 1u))) * int((_5592 & 127u) << _5624))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _10283;
                    if (_3435[_8981] == 0u)
                    {
                        _10283 = -1.0f;
                    }
                    else
                    {
                        _10283 = float((_3435[_8981] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _3869 = _10283 - 0.100000001490116119384765625f;
                    float2 _10284;
                    if (_5504)
                    {
                        float2 _5701 = clamp((((_8972 + (_3864 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5704 = tan(_5701.x);
                        _10284 = (float2(_5704 / cbFI_DeviceToViewDepth.z, (tan(_5701.y) * sqrt(1.0f + (_5704 * _5704))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10284 = _8972 + (_3864 * cbFI_Timestep);
                    }
                    float _3876 = cbFI_Timestep - 1.0f;
                    float2 _10285;
                    if (_5504)
                    {
                        float2 _5772 = clamp((((_8972 + (_3864 * _3876)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _5775 = tan(_5772.x);
                        _10285 = (float2(_5775 / cbFI_DeviceToViewDepth.z, (tan(_5772.y) * sqrt(1.0f + (_5775 * _5775))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _10285 = _8972 + (_3864 * _3876);
                    }
                    bool _5808 = all(bool2(_10284.x > 0.0f.xx.x, _10284.y > 0.0f.xx.y));
                    bool _5814;
                    if (_5808)
                    {
                        _5814 = all(bool2(_10284.x < 1.0f.xx.x, _10284.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5814 = _5808;
                    }
                    float _10288;
                    if (_5814)
                    {
                        uint _5821_dummy_parameter;
                        _10288 = max((_3869 - (log(((r_depth_tm1.Load(int3(int2(floor(_10284 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _5821_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10288 = 0.0f;
                    }
                    bool _5851 = all(bool2(_10285.x > 0.0f.xx.x, _10285.y > 0.0f.xx.y));
                    bool _5857;
                    if (_5851)
                    {
                        _5857 = all(bool2(_10285.x < 1.0f.xx.x, _10285.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _5857 = _5851;
                    }
                    float _10289;
                    if (_5857)
                    {
                        uint _5864_dummy_parameter;
                        _10289 = _10288 + max((_3869 - (log(((r_depth_tp1.Load(int3(int2(floor(_10285 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _5864_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _10289 = _10288;
                    }
                    float _10330;
                    int2 _10334;
                    float2 _10345;
                    int2 _10356;
                    float2 _10389;
                    float _10434;
                    if (_10289 == 0.0f)
                    {
                        bool _3911 = _3869 > _8982;
                        bool2 _10442 = _3911.xx;
                        _10434 = _10297;
                        _10389 = float2(_10442.x ? _3864.x : _8992.x, _10442.y ? _3864.y : _8992.y);
                        _10356 = int2(_10442.x ? _3858.x : _8986.x, _10442.y ? _3858.y : _8986.y);
                        _10345 = _8984;
                        _10334 = _8983;
                        _10330 = _3911 ? _3869 : _8982;
                    }
                    else
                    {
                        bool _3920 = _10289 < _10297;
                        bool2 _10438 = _3920.xx;
                        _10434 = _3920 ? _10289 : _10297;
                        _10389 = _8992;
                        _10356 = _8986;
                        _10345 = float2(_10438.x ? _3864.x : _8984.x, _10438.y ? _3864.y : _8984.y);
                        _10334 = int2(_10438.x ? _3858.x : _8983.x, _10438.y ? _3858.y : _8983.y);
                        _10330 = _8982;
                    }
                    _10433 = _10434;
                    _10388 = _10389;
                    _10355 = _10356;
                    _10344 = _10345;
                    _10333 = _10334;
                    _10329 = _10330;
                }
                bool _3932 = _8982 < 0.0f;
                bool2 _10448 = _3932.xx;
                int2 _10451 = int2(_10448.x ? _8983.x : _8986.x, _10448.y ? _8983.y : _8986.y);
                _9935 = float3(1.0f, _3823, float(any(bool2(_10451.x != _3751.x, _10451.y != _3751.y))));
                _9026 = _10451;
                _9015 = _3932 ? false : true;
                _8994 = float2(_10448.x ? _8984.x : _8992.x, _10448.y ? _8984.y : _8992.y);
            }
            else
            {
                _9935 = _8783;
                _9026 = _3751;
                _9015 = false;
                _8994 = _5482;
            }
            _9934 = _9935;
            _9025 = _9026;
            _9014 = _9015;
            _8993 = _8994;
        }
        else
        {
            _9934 = 0.0f.xxx;
            _9025 = _3751;
            _9014 = false;
            _8993 = _5482;
        }
        float2 _8995;
        if (_5504)
        {
            float2 _5929 = clamp((((_8972 + (_8993 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _5932 = tan(_5929.x);
            _8995 = (float2(_5932 / cbFI_DeviceToViewDepth.z, (tan(_5929.y) * sqrt(1.0f + (_5932 * _5932))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8995 = _8972 + (_8993 * cbFI_Timestep);
        }
        float _3955 = cbFI_Timestep - 1.0f;
        float2 _8997;
        if (_5504)
        {
            float2 _6000 = clamp((((_8972 + (_8993 * _3955)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6003 = tan(_6000.x);
            _8997 = (float2(_6003 / cbFI_DeviceToViewDepth.z, (tan(_6000.y) * sqrt(1.0f + (_6003 * _6003))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8997 = _8972 + (_8993 * _3955);
        }
        float _3960 = -cbFI_Timestep;
        float2 _8998;
        if (_5504)
        {
            float2 _6071 = clamp((((_8972 + (_5476 * _3960)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6074 = tan(_6071.x);
            _8998 = (float2(_6074 / cbFI_DeviceToViewDepth.z, (tan(_6071.y) * sqrt(1.0f + (_6074 * _6074))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8998 = _8972 + (_5476 * _3960);
        }
        float _3965 = 1.0f - cbFI_Timestep;
        float2 _8999;
        if (_5504)
        {
            float2 _6142 = clamp((((_8972 + (_5476 * _3965)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6145 = tan(_6142.x);
            _8999 = (float2(_6145 / cbFI_DeviceToViewDepth.z, (tan(_6142.y) * sqrt(1.0f + (_6145 * _6145))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _8999 = _8972 + (_5476 * _3965);
        }
        float4 _6180 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8995, 0.0f);
        float3 _6181 = _6180.xyz;
        float4 _6188 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8997, 0.0f);
        float3 _6189 = _6188.xyz;
        float4 _6196 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _8998, 0.0f);
        float3 _6197 = _6196.xyz;
        float4 _6204 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _8999, 0.0f);
        float3 _6205 = _6204.xyz;
        float4 _6219 = exp(_5470 - max(max(max(_5470.x, _5470.y), _5470.z), _5470.w).xxxx);
        float4 _6226 = _6219 / (dot(_6219, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _3984 = _3777 && (!_9014);
        bool _3993;
        if (_3984)
        {
            _3993 = (_6226.z + _6226.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _3993 = _3984;
        }
        bool _4004;
        if (_3993)
        {
            _4004 = length((_8998 - _8995) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4004 = _3993;
        }
        bool _9038;
        if (_4004)
        {
            uint4 _6245 = r_warped_motion_qdata_tp1.Load(int3(_9025, 0));
            uint _6246 = _6245.x;
            bool _9041;
            if (_6246 != 0u)
            {
                float _9027;
                if (_6246 == 0u)
                {
                    _9027 = -1.0f;
                }
                else
                {
                    _9027 = float((_6246 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4014 = _9027 - 0.12000000476837158203125f;
                bool _6265 = all(bool2(_8998.x > 0.0f.xx.x, _8998.y > 0.0f.xx.y));
                bool _6271;
                if (_6265)
                {
                    _6271 = all(bool2(_8998.x < 1.0f.xx.x, _8998.y < 1.0f.xx.y));
                }
                else
                {
                    _6271 = _6265;
                }
                bool _4024;
                if (_6271)
                {
                    uint _6278_dummy_parameter;
                    _4024 = (log(((r_depth_tm1.Load(int3(int2(floor(_8998 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6278_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4014;
                }
                else
                {
                    _4024 = _6271;
                }
                bool _4038;
                if (!_4024)
                {
                    bool _6308 = all(bool2(_8999.x > 0.0f.xx.x, _8999.y > 0.0f.xx.y));
                    bool _6314;
                    if (_6308)
                    {
                        _6314 = all(bool2(_8999.x < 1.0f.xx.x, _8999.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6314 = _6308;
                    }
                    bool _4036;
                    if (_6314)
                    {
                        uint _6321_dummy_parameter;
                        _4036 = (log(((r_depth_tp1.Load(int3(int2(floor(_8999 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6321_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _4014;
                    }
                    else
                    {
                        _4036 = _6314;
                    }
                    _4038 = _4036;
                }
                else
                {
                    _4038 = _4024;
                }
                _9041 = _4038;
            }
            else
            {
                _9041 = false;
            }
            _9038 = _9041;
        }
        else
        {
            _9038 = false;
        }
        bool _4043 = _9014 || _9038;
        bool _4048;
        if (_4043)
        {
            bool _6351 = all(bool2(_8995.x > 0.0f.xx.x, _8995.y > 0.0f.xx.y));
            bool _6357;
            if (_6351)
            {
                _6357 = all(bool2(_8995.x < 1.0f.xx.x, _8995.y < 1.0f.xx.y));
            }
            else
            {
                _6357 = _6351;
            }
            _4048 = _6357;
        }
        else
        {
            _4048 = _4043;
        }
        bool _4053;
        if (_4048)
        {
            bool _6362 = all(bool2(_8997.x > 0.0f.xx.x, _8997.y > 0.0f.xx.y));
            bool _6368;
            if (_6362)
            {
                _6368 = all(bool2(_8997.x < 1.0f.xx.x, _8997.y < 1.0f.xx.y));
            }
            else
            {
                _6368 = _6362;
            }
            _4053 = _6368;
        }
        else
        {
            _4053 = _4048;
        }
        float4 _9132;
        if (_4053)
        {
            float _4056 = _6226.x;
            float _4058 = _6226.y;
            float _4059 = _4056 + _4058;
            float _4064 = _6226.z + _6226.w;
            float _9056;
            if (_4059 > 0.001000000047497451305389404296875f)
            {
                _9056 = _4056 / _4059;
            }
            else
            {
                _9056 = _3965;
            }
            _9132 = float4(_4056 + (_4064 * _9056), _4058 + (_4064 * (1.0f - _9056)), 0.0f, 0.0f);
        }
        else
        {
            _9132 = _6226;
        }
        bool _6396 = (cbFI_pad0 & 1024u) != 0u;
        bool _6372 = !_6396;
        bool _6373 = !_6372;
        bool _6390;
        if (_6373)
        {
            _6390 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_9025.y * cbFI_MvDepthLaneSize.x) + _9025.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _6390 = _6372;
        }
        bool _6422;
        if (_6373)
        {
            _6422 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_3756.y * cbFI_FlowLaneSize.x) + _3756.x)) * 4 + 0) != 0u;
        }
        else
        {
            _6422 = _6372;
        }
        float _4099 = float(_6422);
        bool _9144;
        float4 _9174;
        float3 _9791;
        if (_6396)
        {
            bool _4109;
            if (_6390)
            {
                _4109 = all(bool2(_8995.x > 0.0f.xx.x, _8995.y > 0.0f.xx.y));
            }
            else
            {
                _4109 = _6390;
            }
            bool _4115;
            if (_4109)
            {
                _4115 = all(bool2(_8995.x < 1.0f.xx.x, _8995.y < 1.0f.xx.y));
            }
            else
            {
                _4115 = _4109;
            }
            bool _4122;
            if (_6390)
            {
                _4122 = all(bool2(_8997.x > 0.0f.xx.x, _8997.y > 0.0f.xx.y));
            }
            else
            {
                _4122 = _6390;
            }
            bool _4128;
            if (_4122)
            {
                _4128 = all(bool2(_8997.x < 1.0f.xx.x, _8997.y < 1.0f.xx.y));
            }
            else
            {
                _4128 = _4122;
            }
            bool _4135;
            if (_6422)
            {
                _4135 = all(bool2(_8998.x > 0.0f.xx.x, _8998.y > 0.0f.xx.y));
            }
            else
            {
                _4135 = _6422;
            }
            bool _4141;
            if (_4135)
            {
                _4141 = all(bool2(_8998.x < 1.0f.xx.x, _8998.y < 1.0f.xx.y));
            }
            else
            {
                _4141 = _4135;
            }
            bool _4148;
            if (_6422)
            {
                _4148 = all(bool2(_8999.x > 0.0f.xx.x, _8999.y > 0.0f.xx.y));
            }
            else
            {
                _4148 = _6422;
            }
            bool _4154;
            if (_4148)
            {
                _4154 = all(bool2(_8999.x < 1.0f.xx.x, _8999.y < 1.0f.xx.y));
            }
            else
            {
                _4154 = _4148;
            }
            bool _4156 = !_6390;
            if (_4156)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6464;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _6464);
                }
            }
            bool _4161 = !_6422;
            if (_4161)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6474;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _6474);
                }
            }
            if (_6390 && _4161)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6484;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _6484);
                }
            }
            if (_4156 && _6422)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _6494;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _6494);
                }
            }
            float _4180 = float(_4115);
            float _4182 = float(_4128);
            bool _4185 = _4141 && _4154;
            float _9090;
            if (_4185)
            {
                _9090 = 1.0f;
            }
            else
            {
                _9090 = (_4141 || _4154) ? 0.5f : 0.0f;
            }
            bool _9095;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4115)) && (!_4128))
            {
                bool _4215;
                if (_4185)
                {
                    float _9093;
                    do
                    {
                        bool _6578 = all(bool2(_8998.x > 0.0f.xx.x, _8998.y > 0.0f.xx.y));
                        bool _6584;
                        if (_6578)
                        {
                            _6584 = all(bool2(_8998.x < 1.0f.xx.x, _8998.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6584 = _6578;
                        }
                        bool _6515 = !_6584;
                        bool _6522;
                        if (!_6515)
                        {
                            bool _6589 = all(bool2(_8999.x > 0.0f.xx.x, _8999.y > 0.0f.xx.y));
                            bool _6595;
                            if (_6589)
                            {
                                _6595 = all(bool2(_8999.x < 1.0f.xx.x, _8999.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _6595 = _6589;
                            }
                            _6522 = !_6595;
                        }
                        else
                        {
                            _6522 = _6515;
                        }
                        if (_6522)
                        {
                            _9093 = 0.0f;
                            break;
                        }
                        uint _6602_dummy_parameter;
                        uint _6618_dummy_parameter;
                        float4 _6543 = mul(float4((float2(_8998.x, 1.0f - _8998.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8998 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6602_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6545 = _6543.w;
                        if (abs(_6545) < 9.9999999747524270787835121154785e-07f)
                        {
                            _9093 = 0.0f;
                            break;
                        }
                        float _6556 = abs(cbFI_DeviceToViewDepth.y / ((_6543.z / _6545) - cbFI_DeviceToViewDepth.x));
                        float _6559 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8999 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6618_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _9093 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6556 - _6559) / max(max(_6556, _6559), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4215 = _9093 >= 0.5f;
                }
                else
                {
                    _4215 = _4185;
                }
                bool _9096;
                if (_4215)
                {
                    uint _6668_dummy_parameter;
                    float2 _9094;
                    do
                    {
                        float _6694 = 1.0f - _8998.y;
                        float4 _6705 = mul(float4((float2(_8998.x, _6694) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8998 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6668_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _6707 = _6705.w;
                        if (!(_6707 > 9.9999999747524270787835121154785e-07f))
                        {
                            _9094 = 1000000.0f.xx;
                            break;
                        }
                        float2 _6720 = ((_6705.xy / _6707.xx) + 1.0f.xx) * 0.5f;
                        _9094 = float2(_6720.x - _8998.x, _6694 - _6720.y);
                        break;
                    } while(false);
                    float2 _4229 = float2(cbFI_DisplaySize);
                    _9096 = length(((_8998 + _9094) - _8999) * _4229) <= ((0.100000001490116119384765625f * length(_9094 * _4229)) + 8.0f);
                }
                else
                {
                    _9096 = _4215;
                }
                _9095 = _9096;
            }
            else
            {
                _9095 = true;
            }
            bool _4243 = !_9095;
            bool _10452 = _4243 ? false : _4154;
            bool _10453 = _4243 ? false : _4141;
            bool _9145;
            float4 _9175;
            if (!(((_4115 && _4128) && _10453) && _10452))
            {
                float4 _4265 = _9132 * float4(_4180, _4182, float(_10453), float(_10452));
                float _4267 = dot(_4265, 1.0f.xxxx);
                bool _4270 = !(_4267 > 0.0f);
                float4 _9176;
                if (!_4270)
                {
                    _9176 = _4265 / _4267.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _6742;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _6742);
                    }
                    _9176 = 0.0f.xxxx;
                }
                _9175 = _9176;
                _9145 = _4270;
            }
            else
            {
                _9175 = _9132;
                _9145 = false;
            }
            _9791 = float3(_4180, _4182, _9090);
            _9174 = _9175;
            _9144 = _9145;
        }
        else
        {
            _9791 = float3(float(_6390), _4099, 0.0f);
            _9174 = _9132;
            _9144 = false;
        }
        float4 _9658;
        bool _9678;
        if (((cbFI_pad0 & 32768u) != 0u) && (!_9144))
        {
            bool _4293 = _9174.x > 0.00999999977648258209228515625f;
            bool _4296 = _9174.y > 0.00999999977648258209228515625f;
            bool _4305 = (_9174.z + _9174.w) > 0.0199999995529651641845703125f;
            bool _4311;
            if (_4305)
            {
                bool _6748 = all(bool2(_8998.x > 0.0f.xx.x, _8998.y > 0.0f.xx.y));
                bool _6754;
                if (_6748)
                {
                    _6754 = all(bool2(_8998.x < 1.0f.xx.x, _8998.y < 1.0f.xx.y));
                }
                else
                {
                    _6754 = _6748;
                }
                _4311 = _6754;
            }
            else
            {
                _4311 = _4305;
            }
            bool _4316;
            if (_4311)
            {
                bool _6759 = all(bool2(_8999.x > 0.0f.xx.x, _8999.y > 0.0f.xx.y));
                bool _6765;
                if (_6759)
                {
                    _6765 = all(bool2(_8999.x < 1.0f.xx.x, _8999.y < 1.0f.xx.y));
                }
                else
                {
                    _6765 = _6759;
                }
                _4316 = _6765;
            }
            else
            {
                _4316 = _4311;
            }
            bool _4323;
            if (_4316)
            {
                float _9178;
                do
                {
                    bool _6848 = all(bool2(_8998.x > 0.0f.xx.x, _8998.y > 0.0f.xx.y));
                    bool _6854;
                    if (_6848)
                    {
                        _6854 = all(bool2(_8998.x < 1.0f.xx.x, _8998.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6854 = _6848;
                    }
                    bool _6785 = !_6854;
                    bool _6792;
                    if (!_6785)
                    {
                        bool _6859 = all(bool2(_8999.x > 0.0f.xx.x, _8999.y > 0.0f.xx.y));
                        bool _6865;
                        if (_6859)
                        {
                            _6865 = all(bool2(_8999.x < 1.0f.xx.x, _8999.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _6865 = _6859;
                        }
                        _6792 = !_6865;
                    }
                    else
                    {
                        _6792 = _6785;
                    }
                    if (_6792)
                    {
                        _9178 = 0.0f;
                        break;
                    }
                    uint _6872_dummy_parameter;
                    uint _6888_dummy_parameter;
                    float4 _6813 = mul(float4((float2(_8998.x, 1.0f - _8998.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8998 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6872_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _6815 = _6813.w;
                    if (abs(_6815) < 9.9999999747524270787835121154785e-07f)
                    {
                        _9178 = 0.0f;
                        break;
                    }
                    float _6826 = abs(cbFI_DeviceToViewDepth.y / ((_6813.z / _6815) - cbFI_DeviceToViewDepth.x));
                    float _6829 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8999 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6888_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _9178 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_6826 - _6829) / max(max(_6826, _6829), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4323 = _9178 < 0.5f;
            }
            else
            {
                _4323 = _4316;
            }
            float4 _9193;
            if (_4323)
            {
                uint _6938_dummy_parameter;
                uint _6969_dummy_parameter;
                float4 _9194;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_8998 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6938_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8999 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6969_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _9194 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _9194 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _9193 = _9194;
            }
            else
            {
                _9193 = 1.0f.xxxx;
            }
            bool _4347;
            if (_6390)
            {
                bool _6998 = all(bool2(_8995.x > 0.0f.xx.x, _8995.y > 0.0f.xx.y));
                bool _7004;
                if (_6998)
                {
                    _7004 = all(bool2(_8995.x < 1.0f.xx.x, _8995.y < 1.0f.xx.y));
                }
                else
                {
                    _7004 = _6998;
                }
                _4347 = _7004;
            }
            else
            {
                _4347 = _6390;
            }
            bool _4353;
            if (_6390)
            {
                bool _7009 = all(bool2(_8997.x > 0.0f.xx.x, _8997.y > 0.0f.xx.y));
                bool _7015;
                if (_7009)
                {
                    _7015 = all(bool2(_8997.x < 1.0f.xx.x, _8997.y < 1.0f.xx.y));
                }
                else
                {
                    _7015 = _7009;
                }
                _4353 = _7015;
            }
            else
            {
                _4353 = _6390;
            }
            bool _4359;
            if (_6422)
            {
                bool _7020 = all(bool2(_8998.x > 0.0f.xx.x, _8998.y > 0.0f.xx.y));
                bool _7026;
                if (_7020)
                {
                    _7026 = all(bool2(_8998.x < 1.0f.xx.x, _8998.y < 1.0f.xx.y));
                }
                else
                {
                    _7026 = _7020;
                }
                _4359 = _7026;
            }
            else
            {
                _4359 = _6422;
            }
            bool _4365;
            if (_6422)
            {
                bool _7031 = all(bool2(_8999.x > 0.0f.xx.x, _8999.y > 0.0f.xx.y));
                bool _7037;
                if (_7031)
                {
                    _7037 = all(bool2(_8999.x < 1.0f.xx.x, _8999.y < 1.0f.xx.y));
                }
                else
                {
                    _7037 = _7031;
                }
                _4365 = _7037;
            }
            else
            {
                _4365 = _6422;
            }
            bool _4368 = _4359 != _4365;
            bool _4374;
            if (_4368)
            {
                _4374 = _4347 || _4353;
            }
            else
            {
                _4374 = _4368;
            }
            float4 _9273;
            if (_4374)
            {
                float4 _8868 = _9193;
                _8868.z = 0.0f;
                _8868.w = 0.0f;
                _9273 = _8868;
            }
            else
            {
                _9273 = _9193;
            }
            bool _4381 = _4347 && _4293;
            bool _4384 = _4353 && _4296;
            float4 _9377;
            if (_4381 || _4384)
            {
                float _9270;
                do
                {
                    uint4 _7176 = r_warped_motion_qdata_tp1.Load(int3(_9025, 0));
                    uint _7177 = _7176.x;
                    if (_7177 != 0u)
                    {
                        float _9269;
                        if (_7177 == 0u)
                        {
                            _9269 = -1.0f;
                        }
                        else
                        {
                            _9269 = float((_7177 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9270 = _9269;
                        break;
                    }
                    int _9252;
                    uint _9253;
                    _9253 = _7177;
                    _9252 = -1;
                    uint _9268;
                    for (; _9252 <= 1; _9253 = _9268, _9252++)
                    {
                        _9268 = _9253;
                        for (int _9266 = -1; _9266 <= 1; )
                        {
                            _9268 = max(_9268, r_warped_motion_qdata_tp1.Load(int3(clamp(_9025 + int2(_9266, _9252), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9266++;
                            continue;
                        }
                    }
                    if (_9253 != 0u)
                    {
                        float _9265;
                        if (_9253 == 0u)
                        {
                            _9265 = -1.0f;
                        }
                        else
                        {
                            _9265 = float((_9253 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9270 = _9265;
                        break;
                    }
                    uint _9255;
                    _9255 = 4294967295u;
                    uint _10425;
                    for (int _9254 = 0; _9254 < 8; _9255 = _10425, _9254++)
                    {
                        int _9258 = 0;
                        for (;;)
                        {
                            if (_9258 < 5)
                            {
                                int2 _7127 = _9025 + (_1093[_9254] * _1102[_9258].xx);
                                bool _7130 = any(bool2(_7127.x < int2(0, 0).x, _7127.y < int2(0, 0).y));
                                bool _7138;
                                if (!_7130)
                                {
                                    _7138 = any(bool2(_7127.x >= cbFI_MvDepthLaneSize.x, _7127.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7138 = _7130;
                                }
                                if (_7138)
                                {
                                    _10425 = _9255;
                                    break;
                                }
                                uint4 _7216 = r_warped_motion_qdata_tp1.Load(int3(_7127, 0));
                                uint _7217 = _7216.x;
                                if (_7217 != 0u)
                                {
                                    _10425 = min(_9255, _7217);
                                    break;
                                }
                                _9258++;
                                continue;
                            }
                            else
                            {
                                _10425 = _9255;
                                break;
                            }
                        }
                    }
                    float _9257;
                    if (_9255 == 4294967295u)
                    {
                        _9257 = -1.0f;
                    }
                    else
                    {
                        float _9256;
                        if (_9255 == 0u)
                        {
                            _9256 = -1.0f;
                        }
                        else
                        {
                            _9256 = float((_9255 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9257 = _9256;
                    }
                    _9270 = _9257;
                    break;
                } while(false);
                float4 _9306;
                if (((_9270 < 0.0f) && _4381) && _4384)
                {
                    uint _7238_dummy_parameter;
                    float _7262 = log(((r_depth_tm1.Load(int3(int2(floor(_8995 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7238_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _7270_dummy_parameter;
                    float _7294 = log(((r_depth_tp1.Load(int3(int2(floor(_8997 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7270_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _9307;
                    if (_7262 > (_7294 + 0.07999999821186065673828125f))
                    {
                        float4 _8872 = _9273;
                        _8872.x = 0.0f;
                        _9307 = _8872;
                    }
                    else
                    {
                        float4 _9308;
                        if (_7294 > (_7262 + 0.07999999821186065673828125f))
                        {
                            float4 _8874 = _9273;
                            _8874.y = 0.0f;
                            _9308 = _8874;
                        }
                        else
                        {
                            _9308 = _9273;
                        }
                        _9307 = _9308;
                    }
                    _9306 = _9307;
                }
                else
                {
                    _9306 = _9273;
                }
                float _4424 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _4426 = _9270 >= 0.0f;
                float _9289;
                if (_4426)
                {
                    _9289 = _9270 - _4424;
                }
                else
                {
                    float _9285;
                    if (_4381)
                    {
                        float _9284;
                        _9284 = 2.0f;
                        float _7352;
                        for (int _9283 = 0; _9283 < 24; _9284 = _7352, _9283++)
                        {
                            float _7316 = float(_9283 & 7) * 0.785398185253143310546875f;
                            int _7318 = _9283 >> 3;
                            int _9286;
                            if (_7318 == 0)
                            {
                                _9286 = 16;
                            }
                            else
                            {
                                _9286 = (_7318 == 1) ? 48 : 96;
                            }
                            uint _7368_dummy_parameter;
                            _7352 = min(_9284, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_8995 + ((cbFI_MvDepthLaneSizeRcp * float(_9286)) * float2(cos(_7316), sin(_7316))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7368_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9285 = _9284;
                    }
                    else
                    {
                        _9285 = 0.0f;
                    }
                    _9289 = _9285;
                }
                float _9296;
                if (_4426)
                {
                    _9296 = _9270 - _4424;
                }
                else
                {
                    float _9292;
                    if (_4384)
                    {
                        float _9291;
                        _9291 = 2.0f;
                        float _7466;
                        for (int _9290 = 0; _9290 < 24; _9291 = _7466, _9290++)
                        {
                            float _7430 = float(_9290 & 7) * 0.785398185253143310546875f;
                            int _7432 = _9290 >> 3;
                            int _9293;
                            if (_7432 == 0)
                            {
                                _9293 = 16;
                            }
                            else
                            {
                                _9293 = (_7432 == 1) ? 48 : 96;
                            }
                            uint _7498_dummy_parameter;
                            _7466 = min(_9291, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_8997 + ((cbFI_MvDepthLaneSizeRcp * float(_9293)) * float2(cos(_7430), sin(_7430))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7498_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _9292 = _9291;
                    }
                    else
                    {
                        _9292 = 0.0f;
                    }
                    _9296 = _9292;
                }
                float _9297;
                if (_4381)
                {
                    uint _7530_dummy_parameter;
                    _9297 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_8995 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7530_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9297 = 0.0f;
                }
                float _9298;
                if (_4384)
                {
                    uint _7550_dummy_parameter;
                    _9298 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_8997 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7550_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _9298 = 0.0f;
                }
                bool _4481;
                if (_4381)
                {
                    _4481 = _9297 > ((exp((_9289 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4481 = _4381;
                }
                float4 _9314;
                if (_4481)
                {
                    float4 _8876 = _9306;
                    _8876.x = 0.0f;
                    _9314 = _8876;
                }
                else
                {
                    _9314 = _9306;
                }
                bool _4493;
                if (_4384)
                {
                    _4493 = _9298 > ((exp((_9296 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _4493 = _4384;
                }
                float4 _9316;
                if (_4493)
                {
                    float4 _8878 = _9314;
                    _8878.y = 0.0f;
                    _9316 = _8878;
                }
                else
                {
                    _9316 = _9314;
                }
                float4 _9378;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _4426)
                {
                    bool _4513;
                    if (_4381)
                    {
                        _4513 = _9297 < ((exp((_9289 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4513 = _4381;
                    }
                    float4 _9318;
                    if (_4513)
                    {
                        float4 _8880 = _9316;
                        _8880.x = 0.0f;
                        _9318 = _8880;
                    }
                    else
                    {
                        _9318 = _9316;
                    }
                    bool _4525;
                    if (_4384)
                    {
                        _4525 = _9298 < ((exp((_9296 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _4525 = _4384;
                    }
                    float4 _9379;
                    if (_4525)
                    {
                        float4 _8882 = _9318;
                        _8882.y = 0.0f;
                        _9379 = _8882;
                    }
                    else
                    {
                        _9379 = _9318;
                    }
                    _9378 = _9379;
                }
                else
                {
                    _9378 = _9316;
                }
                _9377 = _9378;
            }
            else
            {
                _9377 = _9273;
            }
            bool _4536 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4305;
            bool _4542;
            if (_4536)
            {
                _4542 = _4359 || _4365;
            }
            else
            {
                _4542 = _4536;
            }
            float4 _9399;
            if (_4542)
            {
                float _9372;
                do
                {
                    uint4 _7730 = r_warped_motion_qdata_tp1.Load(int3(_9025, 0));
                    uint _7731 = _7730.x;
                    if (_7731 != 0u)
                    {
                        float _9371;
                        if (_7731 == 0u)
                        {
                            _9371 = -1.0f;
                        }
                        else
                        {
                            _9371 = float((_7731 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9372 = _9371;
                        break;
                    }
                    int _9354;
                    uint _9355;
                    _9355 = _7731;
                    _9354 = -1;
                    uint _9370;
                    for (; _9354 <= 1; _9355 = _9370, _9354++)
                    {
                        _9370 = _9355;
                        for (int _9368 = -1; _9368 <= 1; )
                        {
                            _9370 = max(_9370, r_warped_motion_qdata_tp1.Load(int3(clamp(_9025 + int2(_9368, _9354), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _9368++;
                            continue;
                        }
                    }
                    if (_9355 != 0u)
                    {
                        float _9367;
                        if (_9355 == 0u)
                        {
                            _9367 = -1.0f;
                        }
                        else
                        {
                            _9367 = float((_9355 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9372 = _9367;
                        break;
                    }
                    uint _9357;
                    _9357 = 4294967295u;
                    uint _10426;
                    for (int _9356 = 0; _9356 < 8; _9357 = _10426, _9356++)
                    {
                        int _9360 = 0;
                        for (;;)
                        {
                            if (_9360 < 5)
                            {
                                int2 _7681 = _9025 + (_1093[_9356] * _1102[_9360].xx);
                                bool _7684 = any(bool2(_7681.x < int2(0, 0).x, _7681.y < int2(0, 0).y));
                                bool _7692;
                                if (!_7684)
                                {
                                    _7692 = any(bool2(_7681.x >= cbFI_MvDepthLaneSize.x, _7681.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _7692 = _7684;
                                }
                                if (_7692)
                                {
                                    _10426 = _9357;
                                    break;
                                }
                                uint4 _7770 = r_warped_motion_qdata_tp1.Load(int3(_7681, 0));
                                uint _7771 = _7770.x;
                                if (_7771 != 0u)
                                {
                                    _10426 = min(_9357, _7771);
                                    break;
                                }
                                _9360++;
                                continue;
                            }
                            else
                            {
                                _10426 = _9357;
                                break;
                            }
                        }
                    }
                    float _9359;
                    if (_9357 == 4294967295u)
                    {
                        _9359 = -1.0f;
                    }
                    else
                    {
                        float _9358;
                        if (_9357 == 0u)
                        {
                            _9358 = -1.0f;
                        }
                        else
                        {
                            _9358 = float((_9357 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _9359 = _9358;
                    }
                    _9372 = _9359;
                    break;
                } while(false);
                float4 _9400;
                if (_9372 >= 0.0f)
                {
                    float _7792 = (exp((_9372 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _4561;
                    if (_4359)
                    {
                        uint _7799_dummy_parameter;
                        _4561 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_8998 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7799_dummy_parameter))))), 0)).x) > _7792;
                    }
                    else
                    {
                        _4561 = _4359;
                    }
                    float4 _9390;
                    if (_4561)
                    {
                        float4 _8884 = _9377;
                        _8884.z = 0.0f;
                        _9390 = _8884;
                    }
                    else
                    {
                        _9390 = _9377;
                    }
                    bool _4573;
                    if (_4365)
                    {
                        uint _7819_dummy_parameter;
                        _4573 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_8999 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7819_dummy_parameter))))), 0)).x) > _7792;
                    }
                    else
                    {
                        _4573 = _4365;
                    }
                    float4 _9401;
                    if (_4573)
                    {
                        float4 _8886 = _9390;
                        _8886.w = 0.0f;
                        _9401 = _8886;
                    }
                    else
                    {
                        _9401 = _9390;
                    }
                    _9400 = _9401;
                }
                else
                {
                    _9400 = _9377;
                }
                _9399 = _9400;
            }
            else
            {
                _9399 = _9377;
            }
            bool _4581 = _4347 != _4353;
            bool _4588;
            if (_4581)
            {
                _4588 = _4347 ? _4293 : _4296;
            }
            else
            {
                _4588 = _4581;
            }
            float4 _9482;
            if (_4588)
            {
                bool2 _4593 = _4347.xx;
                float2 _4594 = float2(_4593.x ? _8995.x : _8997.x, _4593.y ? _8995.y : _8997.y);
                float _9392;
                if (_4347)
                {
                    uint _7839_dummy_parameter;
                    _9392 = r_depth_tm1.Load(int3(int2(floor(_4594 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7839_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _7855_dummy_parameter;
                    _9392 = r_depth_tp1.Load(int3(int2(floor(_4594 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7855_dummy_parameter))))), 0)).x;
                }
                float4x4 _9393;
                if (_4347)
                {
                    _9393 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _9393 = cbFI_MotionTP1ToTM1;
                }
                float2 _9394;
                do
                {
                    float _7882 = _4594.x;
                    float _7885 = 1.0f - _4594.y;
                    float4 _7896 = mul(float4((float2(_7882, _7885) * 2.0f) - 1.0f.xx, _9392, 1.0f), _9393);
                    float _7898 = _7896.w;
                    if (!(_7898 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9394 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7911 = ((_7896.xy / _7898.xx) + 1.0f.xx) * 0.5f;
                    _9394 = float2(_7911.x - _7882, _7885 - _7911.y);
                    break;
                } while(false);
                float2 _4624 = float2(cbFI_DisplaySize);
                float4 _9483;
                if (!(length(((_4594 + _9394) - float2(_4593.x ? _8997.x : _8995.x, _4593.y ? _8997.y : _8995.y)) * _4624) <= ((0.100000001490116119384765625f * length(_9394 * _4624)) + 8.0f)))
                {
                    float4 _9484;
                    if (_4347)
                    {
                        float4 _8896 = _9399;
                        _8896.x = 0.0f;
                        _9484 = _8896;
                    }
                    else
                    {
                        float4 _8898 = _9399;
                        _8898.y = 0.0f;
                        _9484 = _8898;
                    }
                    _9483 = _9484;
                }
                else
                {
                    _9483 = _9399;
                }
                _9482 = _9483;
            }
            else
            {
                _9482 = _9399;
            }
            float4 _4649 = _9174 * _9482;
            float _4651 = dot(_4649, 1.0f.xxxx);
            float4 _9659;
            bool _9679;
            if (_4651 > 0.0f)
            {
                _9679 = _9144;
                _9659 = _4649 / _4651.xxxx;
            }
            else
            {
                bool _4662 = any(bool4(_9482.x < 1.0f.xxxx.x, _9482.y < 1.0f.xxxx.y, _9482.z < 1.0f.xxxx.z, _9482.w < 1.0f.xxxx.w));
                if (_4662)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7933;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7933);
                    }
                }
                bool4 _10455 = _4662.xxxx;
                _9679 = _4662 ? true : _9144;
                _9659 = float4(_10455.x ? 0.0f.xxxx.x : _9174.x, _10455.y ? 0.0f.xxxx.y : _9174.y, _10455.z ? 0.0f.xxxx.z : _9174.z, _10455.w ? 0.0f.xxxx.w : _9174.w);
            }
            _9678 = _9679;
            _9658 = _9659;
        }
        else
        {
            _9678 = _9144;
            _9658 = _9174;
        }
        uint _4671 = (cbFI_pad0 >> 24u) & 31u;
        uint _4675 = (cbFI_pad0 >> 16u) & 255u;
        bool _4677 = _4671 != 0u;
        bool _4679 = _4675 == 12u;
        bool _4682 = _4675 == 13u;
        float4 _9675;
        if ((_4677 || _4679) || _4682)
        {
            float _9485;
            do
            {
                bool _8017 = all(bool2(_8998.x > 0.0f.xx.x, _8998.y > 0.0f.xx.y));
                bool _8023;
                if (_8017)
                {
                    _8023 = all(bool2(_8998.x < 1.0f.xx.x, _8998.y < 1.0f.xx.y));
                }
                else
                {
                    _8023 = _8017;
                }
                bool _7954 = !_8023;
                bool _7961;
                if (!_7954)
                {
                    bool _8028 = all(bool2(_8999.x > 0.0f.xx.x, _8999.y > 0.0f.xx.y));
                    bool _8034;
                    if (_8028)
                    {
                        _8034 = all(bool2(_8999.x < 1.0f.xx.x, _8999.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8034 = _8028;
                    }
                    _7961 = !_8034;
                }
                else
                {
                    _7961 = _7954;
                }
                if (_7961)
                {
                    _9485 = 0.0f;
                    break;
                }
                uint _8041_dummy_parameter;
                uint _8057_dummy_parameter;
                float4 _7982 = mul(float4((float2(_8998.x, 1.0f - _8998.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_8998 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8041_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _7984 = _7982.w;
                if (abs(_7984) < 9.9999999747524270787835121154785e-07f)
                {
                    _9485 = 0.0f;
                    break;
                }
                float _7995 = abs(cbFI_DeviceToViewDepth.y / ((_7982.z / _7984) - cbFI_DeviceToViewDepth.x));
                float _7998 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_8999 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8057_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _9485 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7995 - _7998) / max(max(_7995, _7998), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _8105 = all(bool2(_8999.x > 0.0f.xx.x, _8999.y > 0.0f.xx.y));
            bool _8111;
            if (_8105)
            {
                _8111 = all(bool2(_8999.x < 1.0f.xx.x, _8999.y < 1.0f.xx.y));
            }
            else
            {
                _8111 = _8105;
            }
            float _9486;
            if (_8111)
            {
                uint _8118_dummy_parameter;
                _9486 = length((_5476 + (r_motion_tp1.Load(int3(int2(floor(_8999 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8118_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _9486 = 1000000.0f;
            }
            float _9497;
            if ((_4671 & 1u) != 0u)
            {
                _9497 = _9485;
            }
            else
            {
                _9497 = 1.0f;
            }
            float _9498;
            if ((_4671 & 2u) != 0u)
            {
                _9498 = _9497 * (1.0f - smoothstep(2.0f, 8.0f, _9486));
            }
            else
            {
                _9498 = _9497;
            }
            float _9499;
            if ((_4671 & 4u) != 0u)
            {
                _9499 = _9498 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6197 - _6205) - length(_6181 - _6189))));
            }
            else
            {
                _9499 = _9498;
            }
            float _9669;
            if ((_4671 & 8u) != 0u)
            {
                _9669 = lerp(1.0f, _9499, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6181 - _6189)));
            }
            else
            {
                _9669 = _9499;
            }
            bool _4757 = (_4671 & 16u) != 0u;
            bool _4766;
            if (_4757)
            {
                _4766 = length(_8993 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _4766 = _4757;
            }
            float _10457 = _4766 ? 1.0f : _9669;
            bool _4772 = _4677 && _6390;
            bool _4777;
            if (_4772)
            {
                bool _8143 = all(bool2(_8995.x > 0.0f.xx.x, _8995.y > 0.0f.xx.y));
                bool _8149;
                if (_8143)
                {
                    _8149 = all(bool2(_8995.x < 1.0f.xx.x, _8995.y < 1.0f.xx.y));
                }
                else
                {
                    _8149 = _8143;
                }
                _4777 = _8149;
            }
            else
            {
                _4777 = _4772;
            }
            bool _4782;
            if (_4777)
            {
                bool _8154 = all(bool2(_8997.x > 0.0f.xx.x, _8997.y > 0.0f.xx.y));
                bool _8160;
                if (_8154)
                {
                    _8160 = all(bool2(_8997.x < 1.0f.xx.x, _8997.y < 1.0f.xx.y));
                }
                else
                {
                    _8160 = _8154;
                }
                _4782 = _8160;
            }
            else
            {
                _4782 = _4777;
            }
            float4 _9676;
            if (_4782)
            {
                float _4788 = _9658.x + _9658.y;
                float _4797 = (_9658.z + _9658.w) * (1.0f - _10457);
                float _9672;
                if (_4788 > 9.9999997473787516355514526367188e-06f)
                {
                    _9672 = _9658.x / _4788;
                }
                else
                {
                    _9672 = _3965;
                }
                _9676 = float4(_9658.x + (_4797 * _9672), _9658.y + (_4797 * (1.0f - _9672)), _9658.zw * _10457);
            }
            else
            {
                _9676 = _9658;
            }
            _9675 = _9676;
        }
        else
        {
            _9675 = _9658;
        }
        float3 _10230;
        if (_9678)
        {
            float3 _8166 = r_current_interpolation_source.Load(int3(_3371, 0)).xyz;
            float3 _10231;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _6390)
            {
                uint _8173_dummy_parameter;
                float _9781;
                _9781 = r_depth_tm1.Load(int3(int2(floor(_8995 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8173_dummy_parameter))))), 0)).x;
                float _4909;
                for (int _9780 = 0; _9780 < 24; _9781 = _4909, _9780++)
                {
                    float _4881 = float(_9780 & 7) * 0.785398185253143310546875f;
                    int _4883 = _9780 >> 3;
                    int _10280;
                    if (_4883 == 0)
                    {
                        _10280 = 16;
                    }
                    else
                    {
                        _10280 = (_4883 == 1) ? 48 : 96;
                    }
                    uint _8193_dummy_parameter;
                    _4909 = max(_9781, r_depth_tm1.Load(int3(int2(floor(clamp(_8995 + ((cbFI_MvDepthLaneSizeRcp * float(_10280)) * float2(cos(_4881), sin(_4881))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8193_dummy_parameter))))), 0)).x);
                }
                float2 _9782;
                do
                {
                    float _8215 = 1.0f - _8995.y;
                    float4 _8226 = mul(float4((float2(_8995.x, _8215) * 2.0f) - 1.0f.xx, _9781, 1.0f), cbFI_MotionTM1ToTM2);
                    float _8228 = _8226.w;
                    if (!(_8228 > 9.9999999747524270787835121154785e-07f))
                    {
                        _9782 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8241 = ((_8226.xy / _8228.xx) + 1.0f.xx) * 0.5f;
                    _9782 = float2(_8241.x - _8995.x, _8215 - _8241.y);
                    break;
                } while(false);
                float2 _4920 = _8995 + _9782;
                bool _8259 = all(bool2(_4920.x > 0.0f.xx.x, _4920.y > 0.0f.xx.y));
                bool _8265;
                if (_8259)
                {
                    _8265 = all(bool2(_4920.x < 1.0f.xx.x, _4920.y < 1.0f.xx.y));
                }
                else
                {
                    _8265 = _8259;
                }
                float3 _10232;
                if (_8265)
                {
                    float _4926 = abs(cbFI_DeviceToViewDepth.y / (_9781 - cbFI_DeviceToViewDepth.x));
                    uint _8285_dummy_parameter;
                    int2 _8285 = int2(spvTextureSize(r_depth_m2, uint(0), _8285_dummy_parameter));
                    float _4930 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_4920 * float2(_8285))), int2(0, 0), _8285 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _10237;
                    if (abs(_4930 - _4926) <= (0.20000000298023223876953125f * max(_4930, _4926)))
                    {
                        uint _8319_dummy_parameter;
                        int2 _8319 = int2(spvTextureSize(r_colour_m2, uint(0), _8319_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8342;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _8342);
                        }
                        _10237 = r_colour_m2.Load(int3(clamp(int2(floor(_4920 * float2(_8319))), int2(0, 0), _8319 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _8352;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8352);
                        }
                        _10237 = _8166;
                    }
                    _10232 = _10237;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _8362;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _8362);
                    }
                    _10232 = _8166;
                }
                _10231 = _10232;
            }
            else
            {
                _10231 = _8166;
            }
            _10230 = _10231;
        }
        else
        {
            _10230 = (((_6181 * _9675.x) + (_6189 * _9675.y)) + (_6197 * _9675.z)) + (_6205 * _9675.w);
        }
        uint _4958 = cbFI_pad0 & 255u;
        bool _10125;
        float3 _10229;
        if (_4958 != 0u)
        {
            float3 _4963 = r_present_backbuffer.Load(int3(_3371, 0)).xyz;
            float3 _4967 = r_current_interpolation_source.Load(int3(_3371, 0)).xyz;
            float3 _4971 = abs(_4963 - _4967);
            float3 _9785;
            if (_4958 == 2u)
            {
                _9785 = (abs(_4967) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _9785 = 0.000244140625f.xxx;
            }
            bool _4987 = any(bool3(_4971.x > _9785.x, _4971.y > _9785.y, _4971.z > _9785.z));
            bool3 _10458 = _4987.xxx;
            _10229 = float3(_10458.x ? _4963.x : _10230.x, _10458.y ? _4963.y : _10230.y, _10458.z ? _4963.z : _10230.z);
            _10125 = _4987;
        }
        else
        {
            _10229 = _10230;
            _10125 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _8377;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _8377);
        }
        float3 _10213;
        if (_4675 == 1u)
        {
            _10213 = lerp(_6181, _6189, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _10214;
            if (_4675 == 2u)
            {
                _10214 = lerp(_6197, _6205, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _10215;
                if (_4675 == 3u)
                {
                    _10215 = float(_10125).xxx;
                }
                else
                {
                    float3 _10216;
                    if (_4675 == 4u)
                    {
                        _10216 = float3(((_8993 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _10217;
                        if (_4675 == 5u)
                        {
                            _10217 = float3(((_5476 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _10218;
                            if (_4675 == 6u)
                            {
                                _10218 = float3(_9675.xy, _9675.z + _9675.w);
                            }
                            else
                            {
                                float3 _10219;
                                if (_4675 == 7u)
                                {
                                    _10219 = r_current_interpolation_source.Load(int3(_3371, 0)).xyz;
                                }
                                else
                                {
                                    float3 _10220;
                                    if (_4675 == 8u)
                                    {
                                        _10220 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _3740, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _10221;
                                        if (_4679)
                                        {
                                            uint _8399_dummy_parameter;
                                            uint _8431_dummy_parameter;
                                            _10221 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_3740 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8399_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_3740 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8431_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _10222;
                                            if (_4682)
                                            {
                                                _10222 = _6197;
                                            }
                                            else
                                            {
                                                float3 _10223;
                                                if (_4675 == 20u)
                                                {
                                                    _10223 = _6181;
                                                }
                                                else
                                                {
                                                    float3 _10224;
                                                    if (_4675 == 21u)
                                                    {
                                                        _10224 = _6189;
                                                    }
                                                    else
                                                    {
                                                        float3 _10225;
                                                        if (_4675 == 22u)
                                                        {
                                                            _10225 = _6205;
                                                        }
                                                        else
                                                        {
                                                            float3 _10226;
                                                            if (_4675 == 18u)
                                                            {
                                                                _10226 = _9934;
                                                            }
                                                            else
                                                            {
                                                                bool3 _10460 = (_4675 == 19u).xxx;
                                                                _10226 = float3(_10460.x ? _9791.x : _10229.x, _10460.y ? _9791.y : _10229.y, _10460.z ? _9791.z : _10229.z);
                                                            }
                                                            _10225 = _10226;
                                                        }
                                                        _10224 = _10225;
                                                    }
                                                    _10223 = _10224;
                                                }
                                                _10222 = _10223;
                                            }
                                            _10221 = _10222;
                                        }
                                        _10220 = _10221;
                                    }
                                    _10219 = _10220;
                                }
                                _10218 = _10219;
                            }
                            _10217 = _10218;
                        }
                        _10216 = _10217;
                    }
                    _10215 = _10216;
                }
                _10214 = _10215;
            }
            _10213 = _10214;
        }
        float3 _10212;
        if ((_4675 >= 9u) && (_4675 <= 11u))
        {
            uint _5145 = 64u + uint((_9025.y * cbFI_MvDepthLaneSize.x) + _9025.x);
            uint _5149 = rw_nfru_diagnostics.Load<uint>(_5145 * 4 + 0) & 15u;
            float3 _10242;
            if (_4675 == 10u)
            {
                float3 _10211;
                if ((rw_nfru_diagnostics.Load<uint>(_5145 * 4 + 0) & 32u) != 0u)
                {
                    _10211 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _10210;
                    if ((rw_nfru_diagnostics.Load<uint>(_5145 * 4 + 0) & 16u) != 0u)
                    {
                        _10210 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5170 = ((rw_nfru_diagnostics.Load<uint>(_5145 * 4 + 0) & 64u) != 0u).xxx;
                        _10210 = float3(_5170.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5170.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5170.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _10211 = _10210;
                }
                _10242 = _10211;
            }
            else
            {
                float3 _10243;
                if (_4675 == 11u)
                {
                    uint _5183 = (rw_nfru_diagnostics.Load<uint>(_5145 * 4 + 0) >> 8u) & 15u;
                    uint _5186 = (rw_nfru_diagnostics.Load<uint>(_5145 * 4 + 0) >> 12u) & 15u;
                    float3 _10203;
                    if ((_5149 == 2u) || (_5149 == 3u))
                    {
                        _10203 = _3067[_5149];
                    }
                    else
                    {
                        bool _5198 = _5183 == 3u;
                        bool _5200 = _5186 == 3u;
                        float3 _10204;
                        if (_5198 && _5200)
                        {
                            _10204 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _10205;
                            if (_5198)
                            {
                                _10205 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _10206;
                                if (_5200)
                                {
                                    _10206 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _10207;
                                    if ((_5183 == 4u) || (_5186 == 4u))
                                    {
                                        _10207 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _10208;
                                        if ((_5183 == 1u) || (_5186 == 1u))
                                        {
                                            _10208 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _10462 = (_5149 == 1u).xxx;
                                            _10208 = float3(_10462.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _10462.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _10462.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _10207 = _10208;
                                    }
                                    _10206 = _10207;
                                }
                                _10205 = _10206;
                            }
                            _10204 = _10205;
                        }
                        _10203 = _10204;
                    }
                    _10243 = _10203;
                }
                else
                {
                    _10243 = _3067[min(_5149, 7u)];
                }
                _10242 = _10243;
            }
            _10212 = _10242;
        }
        else
        {
            _10212 = _10213;
        }
        float4 _10246;
        if ((_4675 >= 14u) && (_4675 <= 16u))
        {
            float2 _10244;
            if (_4675 == 14u)
            {
                uint _5256_dummy_parameter;
                uint _5262_dummy_parameter;
                _10244 = r_flow_tm1.Load(int3(clamp(int2(floor(_3740 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5256_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5262_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _10245;
                if (_4675 == 16u)
                {
                    uint _8482 = r_warped_flow_qdata_tm1.Load(int3(_3756, 0)).x & 2147483647u;
                    uint _8514 = uint(max((int((_8482 >> 16u) & 15u) - 6), 0));
                    _10245 = ((float2(float((1 - (2 * int((_8482 >> 15u) & 1u))) * int(((_8482 >> uint(7)) & 127u) << _8514)), float((1 - (2 * int((_8482 >> 14u) & 1u))) * int((_8482 & 127u) << _8514))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _10245 = _5476 * float2(cbFI_DisplaySize);
                }
                _10244 = _10245;
            }
            uint2 _5295 = uint2(clamp(round(_10244 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5297 = _5295.x;
            uint _5304 = _5295.y;
            _10246 = float4(float(_5297 & 255u), float((_5297 >> 8u) | ((_5304 & 15u) << 4u)), float(_5304 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _10247;
            if (_4675 == 17u)
            {
                _10247 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_3756, 0)).x != 0u), _4099, 0.0f, 1.0f);
            }
            else
            {
                _10247 = float4(_10212, 1.0f);
            }
            _10246 = _10247;
        }
        rw_output[_3371] = _10246.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5348 = ((uint(_3371.y) * uint(cbFI_DisplaySize.x)) + uint(_3371.x)) * 6u;
            uint _8560 = spvPackHalf2x16(clamp(_6180.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5348 * 4 + 0, (((_8560 & 32767u) >> 4u) | ((((_8560 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6180.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8595 = spvPackHalf2x16(clamp(_6188.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5348 + 1u) * 4 + 0, (((_8595 & 32767u) >> 4u) | ((((_8595 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6188.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8630 = spvPackHalf2x16(clamp(_6196.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5348 + 2u) * 4 + 0, (((_8630 & 32767u) >> 4u) | ((((_8630 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6196.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _8665 = spvPackHalf2x16(clamp(_6204.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5348 + 3u) * 4 + 0, (((_8665 & 32767u) >> 4u) | ((((_8665 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6204.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _8692 = r_current_interpolation_source.Load(int3(_3371, 0));
            uint _8706 = spvPackHalf2x16(clamp(_8692.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5348 + 4u) * 4 + 0, (((_8706 & 32767u) >> 4u) | ((((_8706 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8692.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10279;
            if (_10125 || (_4675 != 0u))
            {
                _10279 = 4294967295u;
            }
            else
            {
                uint _8741 = spvPackHalf2x16(clamp(_10246.xy, 0.0f.xx, 65000.0f.xx));
                _10279 = (((_8741 & 32767u) >> 4u) | ((((_8741 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10246.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5348 + 5u) * 4 + 0, _10279);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3371] = float4(r_current_interpolation_source.Load(int3(_3371, 0)).xyz, 1.0f).xyz;
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
