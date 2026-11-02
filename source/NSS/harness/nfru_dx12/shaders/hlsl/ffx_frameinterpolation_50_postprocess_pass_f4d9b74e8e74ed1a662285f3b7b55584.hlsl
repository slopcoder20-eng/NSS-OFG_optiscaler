static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1090[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1099[5] = { 2, 4, 7, 11, 16 };
static const float3 _3675[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3962 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3962.x >= cbFI_DisplaySize.x, _3962.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3962] = float4(r_present_backbuffer.Load(int3(_3962, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4408 = (float2(_3962) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _4410 = float2(cbFI_MvDepthLaneSize);
        int2 _4419 = int2(floor(_4408 * _4410));
        int2 _4424 = int2(floor(_4408 * float2(cbFI_FlowLaneSize)));
        float4 _6588 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4408 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6594 = r_warped_filled_flow_tm1.Load(int3(_4424, 0)).xy;
        float2 _6600 = r_warped_filled_motion_tp1.Load(int3(_4419, 0)).xy;
        bool _6622 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _12482;
        if (_6622)
        {
            float _6635 = ((2.0f * _4408.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _12482 = float2(atan(_6635) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4408.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6635 * _6635))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _12482 = _4408;
        }
        bool _4445 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _12503;
        bool _12573;
        int2 _12622;
        float3 _14483;
        if (_4445)
        {
            float _12484;
            float _12486;
            _12486 = 2.0f;
            _12484 = -1.0f;
            uint _4029[9];
            float _14983;
            float _14986;
            for (int _12483 = 0; _12483 < 9; _12486 = _14986, _12484 = _14983, _12483++)
            {
                _4029[_12483] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4419 + int2((_12483 % 3) - 1, (_12483 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_4029[_12483] != 0u)
                {
                    float _14978;
                    if (_4029[_12483] == 0u)
                    {
                        _14978 = -1.0f;
                    }
                    else
                    {
                        _14978 = float((_4029[_12483] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _14986 = min(_12486, _14978);
                    _14983 = max(_12484, _14978);
                }
                else
                {
                    _14986 = _12486;
                    _14983 = _12484;
                }
            }
            float _4491 = float(_12484 >= 0.0f);
            float3 _12185 = 0.0f.xxx;
            _12185.y = _4491;
            float2 _12504;
            bool _12574;
            int2 _12623;
            float3 _14484;
            if ((_12484 - _12486) > 0.0199999995529651641845703125f)
            {
                float _12492;
                int2 _12493;
                float2 _12494;
                int2 _12496;
                float2 _12502;
                _12502 = _6600;
                _12496 = _4419;
                _12494 = _6600;
                _12493 = _4419;
                _12492 = -1.0f;
                float _14991;
                int2 _14995;
                float2 _15006;
                int2 _15017;
                float2 _15050;
                float _15097;
                int _12491 = 0;
                float _14959 = 1000000000.0f;
                for (; _12491 < 9; _14959 = _15097, _12502 = _15050, _12496 = _15017, _12494 = _15006, _12493 = _14995, _12492 = _14991, _12491++)
                {
                    if (_4029[_12491] == 0u)
                    {
                        _15097 = _14959;
                        _15050 = _12502;
                        _15017 = _12496;
                        _15006 = _12494;
                        _14995 = _12493;
                        _14991 = _12492;
                        continue;
                    }
                    int2 _4526 = clamp(_4419 + int2((_12491 % 3) - 1, (_12491 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6710 = _4029[_12491] & 2147483647u;
                    uint _6742 = uint(max((int((_6710 >> 16u) & 15u) - 6), 0));
                    float2 _4532 = (float2(float((1 - (2 * int((_6710 >> 15u) & 1u))) * int(((_6710 >> uint(7)) & 127u) << _6742)), float((1 - (2 * int((_6710 >> 14u) & 1u))) * int((_6710 & 127u) << _6742))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _14945;
                    if (_4029[_12491] == 0u)
                    {
                        _14945 = -1.0f;
                    }
                    else
                    {
                        _14945 = float((_4029[_12491] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4537 = _14945 - 0.100000001490116119384765625f;
                    float2 _14946;
                    if (_6622)
                    {
                        float2 _6819 = clamp((((_12482 + (_4532 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6822 = tan(_6819.x);
                        _14946 = (float2(_6822 / cbFI_DeviceToViewDepth.z, (tan(_6819.y) * sqrt(1.0f + (_6822 * _6822))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _14946 = _12482 + (_4532 * cbFI_Timestep);
                    }
                    float _4544 = cbFI_Timestep - 1.0f;
                    float2 _14947;
                    if (_6622)
                    {
                        float2 _6890 = clamp((((_12482 + (_4532 * _4544)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6893 = tan(_6890.x);
                        _14947 = (float2(_6893 / cbFI_DeviceToViewDepth.z, (tan(_6890.y) * sqrt(1.0f + (_6893 * _6893))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _14947 = _12482 + (_4532 * _4544);
                    }
                    bool _6926 = all(bool2(_14946.x > 0.0f.xx.x, _14946.y > 0.0f.xx.y));
                    bool _6932;
                    if (_6926)
                    {
                        _6932 = all(bool2(_14946.x < 1.0f.xx.x, _14946.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6932 = _6926;
                    }
                    float _14950;
                    if (_6932)
                    {
                        uint _6939_dummy_parameter;
                        _14950 = max((_4537 - (log((r_depth_tm1.Load(int3(int2(floor(_14946 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6939_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _14950 = 0.0f;
                    }
                    bool _6969 = all(bool2(_14947.x > 0.0f.xx.x, _14947.y > 0.0f.xx.y));
                    bool _6975;
                    if (_6969)
                    {
                        _6975 = all(bool2(_14947.x < 1.0f.xx.x, _14947.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6975 = _6969;
                    }
                    float _14951;
                    if (_6975)
                    {
                        uint _6982_dummy_parameter;
                        _14951 = _14950 + max((_4537 - (log((r_depth_tp1.Load(int3(int2(floor(_14947 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6982_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _14951 = _14950;
                    }
                    float _14992;
                    int2 _14996;
                    float2 _15007;
                    int2 _15018;
                    float2 _15051;
                    float _15098;
                    if (_14951 == 0.0f)
                    {
                        bool _4579 = _4537 > _12492;
                        bool2 _15106 = _4579.xx;
                        _15098 = _14959;
                        _15051 = float2(_15106.x ? _4532.x : _12502.x, _15106.y ? _4532.y : _12502.y);
                        _15018 = int2(_15106.x ? _4526.x : _12496.x, _15106.y ? _4526.y : _12496.y);
                        _15007 = _12494;
                        _14996 = _12493;
                        _14992 = _4579 ? _4537 : _12492;
                    }
                    else
                    {
                        bool _4588 = _14951 < _14959;
                        bool2 _15102 = _4588.xx;
                        _15098 = _4588 ? _14951 : _14959;
                        _15051 = _12502;
                        _15018 = _12496;
                        _15007 = float2(_15102.x ? _4532.x : _12494.x, _15102.y ? _4532.y : _12494.y);
                        _14996 = int2(_15102.x ? _4526.x : _12493.x, _15102.y ? _4526.y : _12493.y);
                        _14992 = _12492;
                    }
                    _15097 = _15098;
                    _15050 = _15051;
                    _15017 = _15018;
                    _15006 = _15007;
                    _14995 = _14996;
                    _14991 = _14992;
                }
                bool _4600 = _12492 < 0.0f;
                bool2 _15112 = _4600.xx;
                int2 _15115 = int2(_15112.x ? _12493.x : _12496.x, _15112.y ? _12493.y : _12496.y);
                _14484 = float3(1.0f, _4491, float(any(bool2(_15115.x != _4419.x, _15115.y != _4419.y))));
                _12623 = _15115;
                _12574 = _4600 ? false : true;
                _12504 = float2(_15112.x ? _12494.x : _12502.x, _15112.y ? _12494.y : _12502.y);
            }
            else
            {
                _14484 = _12185;
                _12623 = _4419;
                _12574 = false;
                _12504 = _6600;
            }
            _14483 = _14484;
            _12622 = _12623;
            _12573 = _12574;
            _12503 = _12504;
        }
        else
        {
            _14483 = 0.0f.xxx;
            _12622 = _4419;
            _12573 = false;
            _12503 = _6600;
        }
        float2 _12505;
        if (_6622)
        {
            float2 _7047 = clamp((((_12482 + (_12503 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7050 = tan(_7047.x);
            _12505 = (float2(_7050 / cbFI_DeviceToViewDepth.z, (tan(_7047.y) * sqrt(1.0f + (_7050 * _7050))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12505 = _12482 + (_12503 * cbFI_Timestep);
        }
        float _4623 = cbFI_Timestep - 1.0f;
        float2 _12507;
        if (_6622)
        {
            float2 _7118 = clamp((((_12482 + (_12503 * _4623)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7121 = tan(_7118.x);
            _12507 = (float2(_7121 / cbFI_DeviceToViewDepth.z, (tan(_7118.y) * sqrt(1.0f + (_7121 * _7121))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12507 = _12482 + (_12503 * _4623);
        }
        float _4628 = -cbFI_Timestep;
        float2 _12508;
        if (_6622)
        {
            float2 _7189 = clamp((((_12482 + (_6594 * _4628)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7192 = tan(_7189.x);
            _12508 = (float2(_7192 / cbFI_DeviceToViewDepth.z, (tan(_7189.y) * sqrt(1.0f + (_7192 * _7192))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12508 = _12482 + (_6594 * _4628);
        }
        float _4633 = 1.0f - cbFI_Timestep;
        float2 _12509;
        if (_6622)
        {
            float2 _7260 = clamp((((_12482 + (_6594 * _4633)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _7263 = tan(_7260.x);
            _12509 = (float2(_7263 / cbFI_DeviceToViewDepth.z, (tan(_7260.y) * sqrt(1.0f + (_7263 * _7263))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _12509 = _12482 + (_6594 * _4633);
        }
        float4 _7298 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _12505, 0.0f);
        float3 _7299 = _7298.xyz;
        float4 _7306 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _12507, 0.0f);
        float3 _7307 = _7306.xyz;
        float4 _7314 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _12508, 0.0f);
        float3 _7315 = _7314.xyz;
        float4 _7322 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _12509, 0.0f);
        float3 _7323 = _7322.xyz;
        float4 _7337 = exp(_6588 - max(max(max(_6588.x, _6588.y), _6588.z), _6588.w).xxxx);
        float4 _7344 = _7337 / (dot(_7337, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4649 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _12612;
        float _13718;
        if (_4649)
        {
            float2 _4655 = 0.5f.xx / _4410;
            float _4658 = _4655.x;
            float _4659 = -_4658;
            float _4661 = _4655.y;
            float _4662 = -_4661;
            float2 _4664 = _4408 + float2(_4659, _4662);
            float2 _4666 = float2(cbFI_DisplaySize);
            bool _12521;
            do
            {
                bool _7424 = all(bool2(_4664.x > 0.0f.xx.x, _4664.y > 0.0f.xx.y));
                bool _7430;
                if (_7424)
                {
                    _7430 = all(bool2(_4664.x < 1.0f.xx.x, _4664.y < 1.0f.xx.y));
                }
                else
                {
                    _7430 = _7424;
                }
                if (!_7430)
                {
                    _12521 = false;
                    break;
                }
                uint _7437_dummy_parameter;
                float2 _12520;
                do
                {
                    float _7460 = _4664.x;
                    float _7463 = 1.0f - _4664.y;
                    float4 _7474 = mul(float4((float2(_7460, _7463) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4664 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7437_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7476 = _7474.w;
                    if (!(_7476 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12520 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7489 = ((_7474.xy / _7476.xx) + 1.0f.xx) * 0.5f;
                    _12520 = float2(_7489.x - _7460, _7463 - _7489.y);
                    break;
                } while(false);
                float2 _7388 = abs(_12520);
                if (any(bool2(_7388.x > 100000.0f.xx.x, _7388.y > 100000.0f.xx.y)))
                {
                    _12521 = false;
                    break;
                }
                float _7396 = length(_12520 * _4666);
                uint _7509_dummy_parameter;
                bool _7410 = _7396 > ((8.0f * _4666.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7417;
                if (_7410)
                {
                    _7417 = length((r_motion_tp1.Load(int3(int2(floor(_4664 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7509_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4666) < (0.20000000298023223876953125f * _7396);
                }
                else
                {
                    _7417 = _7410;
                }
                _12521 = _7417;
                break;
            } while(false);
            float2 _4676 = _4408 + float2(_4658, _4662);
            bool _12523;
            do
            {
                bool _7595 = all(bool2(_4676.x > 0.0f.xx.x, _4676.y > 0.0f.xx.y));
                bool _7601;
                if (_7595)
                {
                    _7601 = all(bool2(_4676.x < 1.0f.xx.x, _4676.y < 1.0f.xx.y));
                }
                else
                {
                    _7601 = _7595;
                }
                if (!_7601)
                {
                    _12523 = false;
                    break;
                }
                uint _7608_dummy_parameter;
                float2 _12522;
                do
                {
                    float _7631 = _4676.x;
                    float _7634 = 1.0f - _4676.y;
                    float4 _7645 = mul(float4((float2(_7631, _7634) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4676 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7608_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7647 = _7645.w;
                    if (!(_7647 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12522 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7660 = ((_7645.xy / _7647.xx) + 1.0f.xx) * 0.5f;
                    _12522 = float2(_7660.x - _7631, _7634 - _7660.y);
                    break;
                } while(false);
                float2 _7559 = abs(_12522);
                if (any(bool2(_7559.x > 100000.0f.xx.x, _7559.y > 100000.0f.xx.y)))
                {
                    _12523 = false;
                    break;
                }
                float _7567 = length(_12522 * _4666);
                uint _7680_dummy_parameter;
                bool _7581 = _7567 > ((8.0f * _4666.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7588;
                if (_7581)
                {
                    _7588 = length((r_motion_tp1.Load(int3(int2(floor(_4676 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7680_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4666) < (0.20000000298023223876953125f * _7567);
                }
                else
                {
                    _7588 = _7581;
                }
                _12523 = _7588;
                break;
            } while(false);
            float2 _4689 = _4408 + float2(_4659, _4661);
            bool _12525;
            do
            {
                bool _7766 = all(bool2(_4689.x > 0.0f.xx.x, _4689.y > 0.0f.xx.y));
                bool _7772;
                if (_7766)
                {
                    _7772 = all(bool2(_4689.x < 1.0f.xx.x, _4689.y < 1.0f.xx.y));
                }
                else
                {
                    _7772 = _7766;
                }
                if (!_7772)
                {
                    _12525 = false;
                    break;
                }
                uint _7779_dummy_parameter;
                float2 _12524;
                do
                {
                    float _7802 = _4689.x;
                    float _7805 = 1.0f - _4689.y;
                    float4 _7816 = mul(float4((float2(_7802, _7805) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4689 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7779_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7818 = _7816.w;
                    if (!(_7818 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12524 = 1000000.0f.xx;
                        break;
                    }
                    float2 _7831 = ((_7816.xy / _7818.xx) + 1.0f.xx) * 0.5f;
                    _12524 = float2(_7831.x - _7802, _7805 - _7831.y);
                    break;
                } while(false);
                float2 _7730 = abs(_12524);
                if (any(bool2(_7730.x > 100000.0f.xx.x, _7730.y > 100000.0f.xx.y)))
                {
                    _12525 = false;
                    break;
                }
                float _7738 = length(_12524 * _4666);
                uint _7851_dummy_parameter;
                bool _7752 = _7738 > ((8.0f * _4666.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7759;
                if (_7752)
                {
                    _7759 = length((r_motion_tp1.Load(int3(int2(floor(_4689 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _7851_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4666) < (0.20000000298023223876953125f * _7738);
                }
                else
                {
                    _7759 = _7752;
                }
                _12525 = _7759;
                break;
            } while(false);
            float2 _4701 = _4408 + _4655;
            bool _12527;
            do
            {
                bool _7937 = all(bool2(_4701.x > 0.0f.xx.x, _4701.y > 0.0f.xx.y));
                bool _7943;
                if (_7937)
                {
                    _7943 = all(bool2(_4701.x < 1.0f.xx.x, _4701.y < 1.0f.xx.y));
                }
                else
                {
                    _7943 = _7937;
                }
                if (!_7943)
                {
                    _12527 = false;
                    break;
                }
                uint _7950_dummy_parameter;
                float2 _12526;
                do
                {
                    float _7973 = _4701.x;
                    float _7976 = 1.0f - _4701.y;
                    float4 _7987 = mul(float4((float2(_7973, _7976) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_4701 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7950_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                    float _7989 = _7987.w;
                    if (!(_7989 > 9.9999999747524270787835121154785e-07f))
                    {
                        _12526 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8002 = ((_7987.xy / _7989.xx) + 1.0f.xx) * 0.5f;
                    _12526 = float2(_8002.x - _7973, _7976 - _8002.y);
                    break;
                } while(false);
                float2 _7901 = abs(_12526);
                if (any(bool2(_7901.x > 100000.0f.xx.x, _7901.y > 100000.0f.xx.y)))
                {
                    _12527 = false;
                    break;
                }
                float _7909 = length(_12526 * _4666);
                uint _8022_dummy_parameter;
                bool _7923 = _7909 > ((8.0f * _4666.x) / float(cbFI_MvDepthLaneSize.x));
                bool _7930;
                if (_7923)
                {
                    _7930 = length((r_motion_tp1.Load(int3(int2(floor(_4701 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8022_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4666) < (0.20000000298023223876953125f * _7909);
                }
                else
                {
                    _7930 = _7923;
                }
                _12527 = _7930;
                break;
            } while(false);
            float _4707 = 0.25f * (((float(_12521) + float(_12523)) + float(_12525)) + float(_12527));
            float4 _12613;
            if (_4707 < 1.0f)
            {
                bool _12529;
                do
                {
                    bool _8108 = all(bool2(_12505.x > 0.0f.xx.x, _12505.y > 0.0f.xx.y));
                    bool _8114;
                    if (_8108)
                    {
                        _8114 = all(bool2(_12505.x < 1.0f.xx.x, _12505.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8114 = _8108;
                    }
                    if (!_8114)
                    {
                        _12529 = false;
                        break;
                    }
                    uint _8121_dummy_parameter;
                    float2 _12528;
                    do
                    {
                        float _8147 = 1.0f - _12505.y;
                        float4 _8158 = mul(float4((float2(_12505.x, _8147) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12505 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8121_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8160 = _8158.w;
                        if (!(_8160 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12528 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8173 = ((_8158.xy / _8160.xx) + 1.0f.xx) * 0.5f;
                        _12528 = float2(_8173.x - _12505.x, _8147 - _8173.y);
                        break;
                    } while(false);
                    float2 _8072 = abs(_12528);
                    if (any(bool2(_8072.x > 100000.0f.xx.x, _8072.y > 100000.0f.xx.y)))
                    {
                        _12529 = false;
                        break;
                    }
                    float _8080 = length(_12528 * _4666);
                    uint _8193_dummy_parameter;
                    bool _8094 = _8080 > ((8.0f * _4666.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8101;
                    if (_8094)
                    {
                        _8101 = length((r_motion_tp1.Load(int3(int2(floor(_12505 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8193_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4666) < (0.20000000298023223876953125f * _8080);
                    }
                    else
                    {
                        _8101 = _8094;
                    }
                    _12529 = _8101;
                    break;
                } while(false);
                bool _12531;
                do
                {
                    bool _8279 = all(bool2(_12507.x > 0.0f.xx.x, _12507.y > 0.0f.xx.y));
                    bool _8285;
                    if (_8279)
                    {
                        _8285 = all(bool2(_12507.x < 1.0f.xx.x, _12507.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8285 = _8279;
                    }
                    if (!_8285)
                    {
                        _12531 = false;
                        break;
                    }
                    uint _8292_dummy_parameter;
                    float2 _12530;
                    do
                    {
                        float _8318 = 1.0f - _12507.y;
                        float4 _8329 = mul(float4((float2(_12507.x, _8318) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12507 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8292_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8331 = _8329.w;
                        if (!(_8331 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12530 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8344 = ((_8329.xy / _8331.xx) + 1.0f.xx) * 0.5f;
                        _12530 = float2(_8344.x - _12507.x, _8318 - _8344.y);
                        break;
                    } while(false);
                    float2 _8243 = abs(_12530);
                    if (any(bool2(_8243.x > 100000.0f.xx.x, _8243.y > 100000.0f.xx.y)))
                    {
                        _12531 = false;
                        break;
                    }
                    float _8251 = length(_12530 * _4666);
                    uint _8364_dummy_parameter;
                    bool _8265 = _8251 > ((8.0f * _4666.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8272;
                    if (_8265)
                    {
                        _8272 = length((r_motion_tp1.Load(int3(int2(floor(_12507 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8364_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4666) < (0.20000000298023223876953125f * _8251);
                    }
                    else
                    {
                        _8272 = _8265;
                    }
                    _12531 = _8272;
                    break;
                } while(false);
                bool _12533;
                do
                {
                    bool _8450 = all(bool2(_12508.x > 0.0f.xx.x, _12508.y > 0.0f.xx.y));
                    bool _8456;
                    if (_8450)
                    {
                        _8456 = all(bool2(_12508.x < 1.0f.xx.x, _12508.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8456 = _8450;
                    }
                    if (!_8456)
                    {
                        _12533 = false;
                        break;
                    }
                    uint _8463_dummy_parameter;
                    float2 _12532;
                    do
                    {
                        float _8489 = 1.0f - _12508.y;
                        float4 _8500 = mul(float4((float2(_12508.x, _8489) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12508 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8463_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8502 = _8500.w;
                        if (!(_8502 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12532 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8515 = ((_8500.xy / _8502.xx) + 1.0f.xx) * 0.5f;
                        _12532 = float2(_8515.x - _12508.x, _8489 - _8515.y);
                        break;
                    } while(false);
                    float2 _8414 = abs(_12532);
                    if (any(bool2(_8414.x > 100000.0f.xx.x, _8414.y > 100000.0f.xx.y)))
                    {
                        _12533 = false;
                        break;
                    }
                    float _8422 = length(_12532 * _4666);
                    uint _8535_dummy_parameter;
                    bool _8436 = _8422 > ((8.0f * _4666.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8443;
                    if (_8436)
                    {
                        _8443 = length((r_motion_tp1.Load(int3(int2(floor(_12508 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8535_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4666) < (0.20000000298023223876953125f * _8422);
                    }
                    else
                    {
                        _8443 = _8436;
                    }
                    _12533 = _8443;
                    break;
                } while(false);
                bool _12535;
                do
                {
                    bool _8621 = all(bool2(_12509.x > 0.0f.xx.x, _12509.y > 0.0f.xx.y));
                    bool _8627;
                    if (_8621)
                    {
                        _8627 = all(bool2(_12509.x < 1.0f.xx.x, _12509.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8627 = _8621;
                    }
                    if (!_8627)
                    {
                        _12535 = false;
                        break;
                    }
                    uint _8634_dummy_parameter;
                    float2 _12534;
                    do
                    {
                        float _8660 = 1.0f - _12509.y;
                        float4 _8671 = mul(float4((float2(_12509.x, _8660) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_12509 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8634_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTP1ToTM1);
                        float _8673 = _8671.w;
                        if (!(_8673 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12534 = 1000000.0f.xx;
                            break;
                        }
                        float2 _8686 = ((_8671.xy / _8673.xx) + 1.0f.xx) * 0.5f;
                        _12534 = float2(_8686.x - _12509.x, _8660 - _8686.y);
                        break;
                    } while(false);
                    float2 _8585 = abs(_12534);
                    if (any(bool2(_8585.x > 100000.0f.xx.x, _8585.y > 100000.0f.xx.y)))
                    {
                        _12535 = false;
                        break;
                    }
                    float _8593 = length(_12534 * _4666);
                    uint _8706_dummy_parameter;
                    bool _8607 = _8593 > ((8.0f * _4666.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _8614;
                    if (_8607)
                    {
                        _8614 = length((r_motion_tp1.Load(int3(int2(floor(_12509 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8706_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _4666) < (0.20000000298023223876953125f * _8593);
                    }
                    else
                    {
                        _8614 = _8607;
                    }
                    _12535 = _8614;
                    break;
                } while(false);
                float4 _4734 = _7344 * float4(_12529 ? 0.0f : 1.0f, _12531 ? 0.0f : 1.0f, _12533 ? 0.0f : 1.0f, _12535 ? 0.0f : 1.0f);
                float _4736 = dot(_4734, 1.0f.xxxx);
                float4 _12614;
                if (_4736 > 0.001000000047497451305389404296875f)
                {
                    _12614 = _4734 / _4736.xxxx;
                }
                else
                {
                    _12614 = _7344;
                }
                _12613 = _12614;
            }
            else
            {
                _12613 = _7344;
            }
            _13718 = _4707;
            _12612 = _12613;
        }
        else
        {
            _13718 = 0.0f;
            _12612 = _7344;
        }
        bool _4753 = _4445 && (!_12573);
        bool _4762;
        if (_4753)
        {
            _4762 = (_12612.z + _12612.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4762 = _4753;
        }
        bool _4773;
        if (_4762)
        {
            _4773 = length((_12508 - _12505) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4773 = _4762;
        }
        bool _12669;
        if (_4773)
        {
            uint4 _8735 = r_warped_motion_qdata_tp1.Load(int3(_12622, 0));
            uint _8736 = _8735.x;
            bool _12672;
            if (_8736 != 0u)
            {
                float _12658;
                if (_8736 == 0u)
                {
                    _12658 = -1.0f;
                }
                else
                {
                    _12658 = float((_8736 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4783 = _12658 - 0.12000000476837158203125f;
                bool _8755 = all(bool2(_12508.x > 0.0f.xx.x, _12508.y > 0.0f.xx.y));
                bool _8761;
                if (_8755)
                {
                    _8761 = all(bool2(_12508.x < 1.0f.xx.x, _12508.y < 1.0f.xx.y));
                }
                else
                {
                    _8761 = _8755;
                }
                bool _4793;
                if (_8761)
                {
                    uint _8768_dummy_parameter;
                    _4793 = (log((r_depth_tm1.Load(int3(int2(floor(_12508 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8768_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4783;
                }
                else
                {
                    _4793 = _8761;
                }
                bool _4807;
                if (!_4793)
                {
                    bool _8798 = all(bool2(_12509.x > 0.0f.xx.x, _12509.y > 0.0f.xx.y));
                    bool _8804;
                    if (_8798)
                    {
                        _8804 = all(bool2(_12509.x < 1.0f.xx.x, _12509.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8804 = _8798;
                    }
                    bool _4805;
                    if (_8804)
                    {
                        uint _8811_dummy_parameter;
                        _4805 = (log((r_depth_tp1.Load(int3(int2(floor(_12509 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8811_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4783;
                    }
                    else
                    {
                        _4805 = _8804;
                    }
                    _4807 = _4805;
                }
                else
                {
                    _4807 = _4793;
                }
                _12672 = _4807;
            }
            else
            {
                _12672 = false;
            }
            _12669 = _12672;
        }
        else
        {
            _12669 = false;
        }
        bool _4812 = _12573 || _12669;
        bool _4817;
        if (_4812)
        {
            bool _8841 = all(bool2(_12505.x > 0.0f.xx.x, _12505.y > 0.0f.xx.y));
            bool _8847;
            if (_8841)
            {
                _8847 = all(bool2(_12505.x < 1.0f.xx.x, _12505.y < 1.0f.xx.y));
            }
            else
            {
                _8847 = _8841;
            }
            _4817 = _8847;
        }
        else
        {
            _4817 = _4812;
        }
        bool _4822;
        if (_4817)
        {
            bool _8852 = all(bool2(_12507.x > 0.0f.xx.x, _12507.y > 0.0f.xx.y));
            bool _8858;
            if (_8852)
            {
                _8858 = all(bool2(_12507.x < 1.0f.xx.x, _12507.y < 1.0f.xx.y));
            }
            else
            {
                _8858 = _8852;
            }
            _4822 = _8858;
        }
        else
        {
            _4822 = _4817;
        }
        float4 _12766;
        if (_4822)
        {
            float _4828 = _12612.x + _12612.y;
            float _4833 = _12612.z + _12612.w;
            float _12687;
            if (_4828 > 0.001000000047497451305389404296875f)
            {
                _12687 = _12612.x / _4828;
            }
            else
            {
                _12687 = _4633;
            }
            _12766 = float4(_12612.x + (_4833 * _12687), _12612.y + (_4833 * (1.0f - _12687)), 0.0f, 0.0f);
        }
        else
        {
            _12766 = _12612;
        }
        bool _8886 = (cbFI_pad0 & 1024u) != 0u;
        bool _8862 = !_8886;
        bool _8863 = !_8862;
        bool _8880;
        if (_8863)
        {
            _8880 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_12622.y * cbFI_MvDepthLaneSize.x) + _12622.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _8880 = _8862;
        }
        bool _8912;
        if (_8863)
        {
            _8912 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4424.y * cbFI_FlowLaneSize.x) + _4424.x)) * 4 + 0) != 0u;
        }
        else
        {
            _8912 = _8862;
        }
        float _4868 = float(_8912);
        bool _12779;
        float4 _12810;
        float3 _14271;
        if (_8886)
        {
            bool _4878;
            if (_8880)
            {
                _4878 = all(bool2(_12505.x > 0.0f.xx.x, _12505.y > 0.0f.xx.y));
            }
            else
            {
                _4878 = _8880;
            }
            bool _4884;
            if (_4878)
            {
                _4884 = all(bool2(_12505.x < 1.0f.xx.x, _12505.y < 1.0f.xx.y));
            }
            else
            {
                _4884 = _4878;
            }
            bool _4891;
            if (_8880)
            {
                _4891 = all(bool2(_12507.x > 0.0f.xx.x, _12507.y > 0.0f.xx.y));
            }
            else
            {
                _4891 = _8880;
            }
            bool _4897;
            if (_4891)
            {
                _4897 = all(bool2(_12507.x < 1.0f.xx.x, _12507.y < 1.0f.xx.y));
            }
            else
            {
                _4897 = _4891;
            }
            bool _4904;
            if (_8912)
            {
                _4904 = all(bool2(_12508.x > 0.0f.xx.x, _12508.y > 0.0f.xx.y));
            }
            else
            {
                _4904 = _8912;
            }
            bool _4910;
            if (_4904)
            {
                _4910 = all(bool2(_12508.x < 1.0f.xx.x, _12508.y < 1.0f.xx.y));
            }
            else
            {
                _4910 = _4904;
            }
            bool _4917;
            if (_8912)
            {
                _4917 = all(bool2(_12509.x > 0.0f.xx.x, _12509.y > 0.0f.xx.y));
            }
            else
            {
                _4917 = _8912;
            }
            bool _4923;
            if (_4917)
            {
                _4923 = all(bool2(_12509.x < 1.0f.xx.x, _12509.y < 1.0f.xx.y));
            }
            else
            {
                _4923 = _4917;
            }
            bool _4925 = !_8880;
            if (_4925)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _8954;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _8954);
                }
            }
            bool _4930 = !_8912;
            if (_4930)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _8964;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _8964);
                }
            }
            if (_8880 && _4930)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _8974;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _8974);
                }
            }
            if (_4925 && _8912)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _8984;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _8984);
                }
            }
            float _4949 = float(_4884);
            float _4951 = float(_4897);
            bool _4954 = _4910 && _4923;
            float _12721;
            if (_4954)
            {
                _12721 = 1.0f;
            }
            else
            {
                _12721 = (_4910 || _4923) ? 0.5f : 0.0f;
            }
            bool _12726;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4884)) && (!_4897))
            {
                bool _4984;
                if (_4954)
                {
                    float _12724;
                    do
                    {
                        bool _9068 = all(bool2(_12508.x > 0.0f.xx.x, _12508.y > 0.0f.xx.y));
                        bool _9074;
                        if (_9068)
                        {
                            _9074 = all(bool2(_12508.x < 1.0f.xx.x, _12508.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _9074 = _9068;
                        }
                        bool _9005 = !_9074;
                        bool _9012;
                        if (!_9005)
                        {
                            bool _9079 = all(bool2(_12509.x > 0.0f.xx.x, _12509.y > 0.0f.xx.y));
                            bool _9085;
                            if (_9079)
                            {
                                _9085 = all(bool2(_12509.x < 1.0f.xx.x, _12509.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _9085 = _9079;
                            }
                            _9012 = !_9085;
                        }
                        else
                        {
                            _9012 = _9005;
                        }
                        if (_9012)
                        {
                            _12724 = 0.0f;
                            break;
                        }
                        uint _9092_dummy_parameter;
                        uint _9108_dummy_parameter;
                        float4 _9033 = mul(float4((float2(_12508.x, 1.0f - _12508.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12508 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9092_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _9035 = _9033.w;
                        if (abs(_9035) < 9.9999999747524270787835121154785e-07f)
                        {
                            _12724 = 0.0f;
                            break;
                        }
                        float _9046 = abs(cbFI_DeviceToViewDepth.y / ((_9033.z / _9035) - cbFI_DeviceToViewDepth.x));
                        float _9049 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12509 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9108_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _12724 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9046 - _9049) / max(max(_9046, _9049), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4984 = _12724 >= 0.5f;
                }
                else
                {
                    _4984 = _4954;
                }
                bool _4992;
                if (_4984)
                {
                    _4992 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4992 = _4984;
                }
                bool _12727;
                if (_4992)
                {
                    uint _9158_dummy_parameter;
                    float2 _12725;
                    do
                    {
                        float _9184 = 1.0f - _12508.y;
                        float4 _9195 = mul(float4((float2(_12508.x, _9184) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12508 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9158_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _9197 = _9195.w;
                        if (!(_9197 > 9.9999999747524270787835121154785e-07f))
                        {
                            _12725 = 1000000.0f.xx;
                            break;
                        }
                        float2 _9210 = ((_9195.xy / _9197.xx) + 1.0f.xx) * 0.5f;
                        _12725 = float2(_9210.x - _12508.x, _9184 - _9210.y);
                        break;
                    } while(false);
                    float2 _5005 = float2(cbFI_DisplaySize);
                    _12727 = length(((_12508 + _12725) - _12509) * _5005) <= ((0.100000001490116119384765625f * length(_12725 * _5005)) + 8.0f);
                }
                else
                {
                    _12727 = _4984;
                }
                _12726 = _12727;
            }
            else
            {
                _12726 = true;
            }
            bool _5019 = !_12726;
            bool _15116 = _5019 ? false : _4923;
            bool _15117 = _5019 ? false : _4910;
            bool _12780;
            float4 _12811;
            if (!(((_4884 && _4897) && _15117) && _15116))
            {
                float4 _5041 = _12766 * float4(_4949, _4951, float(_15117), float(_15116));
                float _5043 = dot(_5041, 1.0f.xxxx);
                bool _5046 = !(_5043 > 0.0f);
                float4 _12812;
                if (!_5046)
                {
                    _12812 = _5041 / _5043.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9232;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9232);
                    }
                    _12812 = 0.0f.xxxx;
                }
                _12811 = _12812;
                _12780 = _5046;
            }
            else
            {
                _12811 = _12766;
                _12780 = false;
            }
            _14271 = float3(_4949, _4951, _12721);
            _12810 = _12811;
            _12779 = _12780;
        }
        else
        {
            _14271 = float3(float(_8880), _4868, 0.0f);
            _12810 = _12766;
            _12779 = false;
        }
        bool _5064 = !_12779;
        float4 _12895;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _5064)
        {
            float _5071 = _12810.x + _12810.y;
            float4 _12896;
            if (_5071 > 0.001000000047497451305389404296875f)
            {
                _12896 = float4(_12810.x / _5071, _12810.y / _5071, 0.0f, 0.0f);
            }
            else
            {
                _12896 = float4(_4633, cbFI_Timestep, 0.0f, 0.0f);
            }
            _12895 = _12896;
        }
        else
        {
            _12895 = _12810;
        }
        float4 _13072;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _5064) && _8880)
        {
            float _12869;
            do
            {
                uint4 _9372 = r_warped_motion_qdata_tp1.Load(int3(_12622, 0));
                uint _9373 = _9372.x;
                if (_9373 != 0u)
                {
                    float _12868;
                    if (_9373 == 0u)
                    {
                        _12868 = -1.0f;
                    }
                    else
                    {
                        _12868 = float((_9373 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12869 = _12868;
                    break;
                }
                int _12851;
                uint _12852;
                _12852 = _9373;
                _12851 = -1;
                uint _12867;
                for (; _12851 <= 1; _12852 = _12867, _12851++)
                {
                    _12867 = _12852;
                    for (int _12865 = -1; _12865 <= 1; )
                    {
                        _12867 = max(_12867, r_warped_motion_qdata_tp1.Load(int3(clamp(_12622 + int2(_12865, _12851), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _12865++;
                        continue;
                    }
                }
                if (_12852 != 0u)
                {
                    float _12864;
                    if (_12852 == 0u)
                    {
                        _12864 = -1.0f;
                    }
                    else
                    {
                        _12864 = float((_12852 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12869 = _12864;
                    break;
                }
                uint _12854;
                _12854 = 4294967295u;
                uint _15087;
                for (int _12853 = 0; _12853 < 8; _12854 = _15087, _12853++)
                {
                    int _12857 = 0;
                    for (;;)
                    {
                        if (_12857 < 5)
                        {
                            int2 _9323 = _12622 + (_1090[_12853] * _1099[_12857].xx);
                            bool _9326 = any(bool2(_9323.x < int2(0, 0).x, _9323.y < int2(0, 0).y));
                            bool _9334;
                            if (!_9326)
                            {
                                _9334 = any(bool2(_9323.x >= cbFI_MvDepthLaneSize.x, _9323.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _9334 = _9326;
                            }
                            if (_9334)
                            {
                                _15087 = _12854;
                                break;
                            }
                            uint4 _9412 = r_warped_motion_qdata_tp1.Load(int3(_9323, 0));
                            uint _9413 = _9412.x;
                            if (_9413 != 0u)
                            {
                                _15087 = min(_12854, _9413);
                                break;
                            }
                            _12857++;
                            continue;
                        }
                        else
                        {
                            _15087 = _12854;
                            break;
                        }
                    }
                }
                float _12856;
                if (_12854 == 4294967295u)
                {
                    _12856 = -1.0f;
                }
                else
                {
                    float _12855;
                    if (_12854 == 0u)
                    {
                        _12855 = -1.0f;
                    }
                    else
                    {
                        _12855 = float((_12854 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12856 = _12855;
                }
                _12869 = _12856;
                break;
            } while(false);
            float _5107 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _5110 = r_warped_motion_qdata_tp1.Load(int3(_12622, 0)).x == 0u;
            bool _5116;
            if (_5110)
            {
                bool _9438 = all(bool2(_12505.x > 0.0f.xx.x, _12505.y > 0.0f.xx.y));
                bool _9444;
                if (_9438)
                {
                    _9444 = all(bool2(_12505.x < 1.0f.xx.x, _12505.y < 1.0f.xx.y));
                }
                else
                {
                    _9444 = _9438;
                }
                _5116 = _9444;
            }
            else
            {
                _5116 = _5110;
            }
            bool _5121;
            if (_5116)
            {
                bool _9449 = all(bool2(_12507.x > 0.0f.xx.x, _12507.y > 0.0f.xx.y));
                bool _9455;
                if (_9449)
                {
                    _9455 = all(bool2(_12507.x < 1.0f.xx.x, _12507.y < 1.0f.xx.y));
                }
                else
                {
                    _9455 = _9449;
                }
                _5121 = _9455;
            }
            else
            {
                _5121 = _5116;
            }
            bool _12881;
            float4 _12890;
            if (_5121)
            {
                uint _9462_dummy_parameter;
                float _9486 = log((r_depth_tm1.Load(int3(int2(floor(_12505 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9462_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _9494_dummy_parameter;
                float _9518 = log((r_depth_tp1.Load(int3(int2(floor(_12507 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9494_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _5132 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5139;
                if (_5132)
                {
                    _5139 = _9518 > (_9486 + 0.07999999821186065673828125f);
                }
                else
                {
                    _5139 = _5132;
                }
                bool _12886;
                float4 _12908;
                if (_5139)
                {
                    _12908 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _12886 = true;
                }
                else
                {
                    bool _5145 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _5152;
                    if (_5145)
                    {
                        _5152 = _9486 > (_9518 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _5152 = _5145;
                    }
                    bool4 _15118 = _5152.xxxx;
                    _12908 = float4(_15118.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _12895.x, _15118.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _12895.y, _15118.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _12895.z, _15118.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _12895.w);
                    _12886 = _5152 ? true : false;
                }
                _12890 = _12908;
                _12881 = _12886;
            }
            else
            {
                _12890 = _12895;
                _12881 = false;
            }
            float4 _12963;
            if (_12881)
            {
                _12963 = 1.0f.xxxx;
            }
            else
            {
                bool _5163 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5169;
                if (_5163)
                {
                    _5169 = _12890.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5169 = _5163;
                }
                bool _5174;
                if (_5169)
                {
                    bool _9524 = all(bool2(_12507.x > 0.0f.xx.x, _12507.y > 0.0f.xx.y));
                    bool _9530;
                    if (_9524)
                    {
                        _9530 = all(bool2(_12507.x < 1.0f.xx.x, _12507.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9530 = _9524;
                    }
                    _5174 = _9530;
                }
                else
                {
                    _5174 = _5169;
                }
                float4 _12964;
                if (_5174)
                {
                    float _12917;
                    if (_12869 >= 0.0f)
                    {
                        _12917 = _12869 - _5107;
                    }
                    else
                    {
                        float _12913;
                        _12913 = 2.0f;
                        float _9587;
                        for (int _12912 = 0; _12912 < 24; _12913 = _9587, _12912++)
                        {
                            float _9551 = float(_12912 & 7) * 0.785398185253143310546875f;
                            int _9553 = _12912 >> 3;
                            int _12914;
                            if (_9553 == 0)
                            {
                                _12914 = 16;
                            }
                            else
                            {
                                _12914 = (_9553 == 1) ? 48 : 96;
                            }
                            uint _9619_dummy_parameter;
                            _9587 = min(_12913, log((r_depth_tp1.Load(int3(int2(floor(clamp(_12507 + ((cbFI_MvDepthLaneSizeRcp * float(_12914)) * float2(cos(_9551), sin(_9551))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9619_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _12917 = _12913;
                    }
                    uint _9651_dummy_parameter;
                    float4 _12965;
                    if (r_depth_tp1.Load(int3(int2(floor(_12507 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9651_dummy_parameter))))), 0)).x > ((exp((_12917 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _12965 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _12965 = 1.0f.xxxx;
                    }
                    _12964 = _12965;
                }
                else
                {
                    _12964 = 1.0f.xxxx;
                }
                _12963 = _12964;
            }
            bool _5202 = _12869 >= 0.0f;
            bool _5203 = (!_12881) && _5202;
            bool _5210;
            if (_5203)
            {
                _5210 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _5210 = _5203;
            }
            bool _5216;
            if (_5210)
            {
                _5216 = _12890.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _5216 = _5210;
            }
            bool _5221;
            if (_5216)
            {
                bool _9675 = all(bool2(_12505.x > 0.0f.xx.x, _12505.y > 0.0f.xx.y));
                bool _9681;
                if (_9675)
                {
                    _9681 = all(bool2(_12505.x < 1.0f.xx.x, _12505.y < 1.0f.xx.y));
                }
                else
                {
                    _9681 = _9675;
                }
                _5221 = _9681;
            }
            else
            {
                _5221 = _5216;
            }
            float4 _12988;
            if (_5221)
            {
                float _12957;
                if (_5202)
                {
                    _12957 = _12869 - _5107;
                }
                else
                {
                    float _12953;
                    _12953 = 2.0f;
                    float _9738;
                    for (int _12952 = 0; _12952 < 24; _12953 = _9738, _12952++)
                    {
                        float _9702 = float(_12952 & 7) * 0.785398185253143310546875f;
                        int _9704 = _12952 >> 3;
                        int _12954;
                        if (_9704 == 0)
                        {
                            _12954 = 16;
                        }
                        else
                        {
                            _12954 = (_9704 == 1) ? 48 : 96;
                        }
                        uint _9754_dummy_parameter;
                        _9738 = min(_12953, log((r_depth_tm1.Load(int3(int2(floor(clamp(_12505 + ((cbFI_MvDepthLaneSizeRcp * float(_12954)) * float2(cos(_9702), sin(_9702))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9754_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _12957 = _12953;
                }
                uint _9802_dummy_parameter;
                float4 _12989;
                if (r_depth_tm1.Load(int3(int2(floor(_12505 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9802_dummy_parameter))))), 0)).x > ((exp((_12957 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _12337 = _12963;
                    _12337.x = 0.0f;
                    _12989 = _12337;
                }
                else
                {
                    _12989 = _12963;
                }
                _12988 = _12989;
            }
            else
            {
                _12988 = _12963;
            }
            float4 _13001;
            if (_5203)
            {
                float _9828 = (exp(((_12869 - _5107) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _5259 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _5265;
                if (_5259)
                {
                    _5265 = _12890.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5265 = _5259;
                }
                bool _5270;
                if (_5265)
                {
                    bool _9833 = all(bool2(_12509.x > 0.0f.xx.x, _12509.y > 0.0f.xx.y));
                    bool _9839;
                    if (_9833)
                    {
                        _9839 = all(bool2(_12509.x < 1.0f.xx.x, _12509.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9839 = _9833;
                    }
                    _5270 = _9839;
                }
                else
                {
                    _5270 = _5265;
                }
                bool _5278;
                if (_5270)
                {
                    uint _9846_dummy_parameter;
                    _5278 = r_depth_tp1.Load(int3(int2(floor(_12509 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9846_dummy_parameter))))), 0)).x > _9828;
                }
                else
                {
                    _5278 = _5270;
                }
                float4 _12999;
                if (_5278)
                {
                    float4 _12340 = _12988;
                    _12340.w = 0.0f;
                    _12999 = _12340;
                }
                else
                {
                    _12999 = _12988;
                }
                bool _5285 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _5291;
                if (_5285)
                {
                    _5291 = _12890.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _5291 = _5285;
                }
                bool _5296;
                if (_5291)
                {
                    bool _9863 = all(bool2(_12508.x > 0.0f.xx.x, _12508.y > 0.0f.xx.y));
                    bool _9869;
                    if (_9863)
                    {
                        _9869 = all(bool2(_12508.x < 1.0f.xx.x, _12508.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9869 = _9863;
                    }
                    _5296 = _9869;
                }
                else
                {
                    _5296 = _5291;
                }
                bool _5304;
                if (_5296)
                {
                    uint _9876_dummy_parameter;
                    _5304 = r_depth_tm1.Load(int3(int2(floor(_12508 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9876_dummy_parameter))))), 0)).x > _9828;
                }
                else
                {
                    _5304 = _5296;
                }
                float4 _13002;
                if (_5304)
                {
                    float4 _12343 = _12999;
                    _12343.z = 0.0f;
                    _13002 = _12343;
                }
                else
                {
                    _13002 = _12999;
                }
                _13001 = _13002;
            }
            else
            {
                _13001 = _12988;
            }
            float4 _13073;
            if (any(bool4(_13001.x < 1.0f.xxxx.x, _13001.y < 1.0f.xxxx.y, _13001.z < 1.0f.xxxx.z, _13001.w < 1.0f.xxxx.w)))
            {
                float4 _5315 = _12890 * _13001;
                float _5317 = dot(_5315, 1.0f.xxxx);
                float4 _13074;
                if (_5317 > 0.0f)
                {
                    _13074 = _5315 / _5317.xxxx;
                }
                else
                {
                    bool _5328 = _13001.y == 0.0f;
                    bool _5334;
                    if (_5328)
                    {
                        _5334 = _13001.x > 0.0f;
                    }
                    else
                    {
                        _5334 = _5328;
                    }
                    bool _5339;
                    if (_5334)
                    {
                        bool _9893 = all(bool2(_12505.x > 0.0f.xx.x, _12505.y > 0.0f.xx.y));
                        bool _9899;
                        if (_9893)
                        {
                            _9899 = all(bool2(_12505.x < 1.0f.xx.x, _12505.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _9899 = _9893;
                        }
                        _5339 = _9899;
                    }
                    else
                    {
                        _5339 = _5334;
                    }
                    float4 _13075;
                    if (_5339)
                    {
                        _13075 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _5344 = _13001.x == 0.0f;
                        bool _5350;
                        if (_5344)
                        {
                            _5350 = _13001.y > 0.0f;
                        }
                        else
                        {
                            _5350 = _5344;
                        }
                        bool _5355;
                        if (_5350)
                        {
                            bool _9904 = all(bool2(_12507.x > 0.0f.xx.x, _12507.y > 0.0f.xx.y));
                            bool _9910;
                            if (_9904)
                            {
                                _9910 = all(bool2(_12507.x < 1.0f.xx.x, _12507.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _9910 = _9904;
                            }
                            _5355 = _9910;
                        }
                        else
                        {
                            _5355 = _5350;
                        }
                        bool4 _15121 = _5355.xxxx;
                        _13075 = float4(_15121.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _12890.x, _15121.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _12890.y, _15121.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _12890.z, _15121.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _12890.w);
                    }
                    _13074 = _13075;
                }
                _13073 = _13074;
            }
            else
            {
                _13073 = _12890;
            }
            _13072 = _13073;
        }
        else
        {
            _13072 = _12895;
        }
        float4 _13686;
        bool _13948;
        float3 _14065;
        if (((cbFI_pad0 & 32768u) != 0u) && _5064)
        {
            bool _5372 = _13072.x > 0.00999999977648258209228515625f;
            bool _5375 = _13072.y > 0.00999999977648258209228515625f;
            bool _5384 = (_13072.z + _13072.w) > 0.0199999995529651641845703125f;
            bool _5390;
            if (_5384)
            {
                bool _9915 = all(bool2(_12508.x > 0.0f.xx.x, _12508.y > 0.0f.xx.y));
                bool _9921;
                if (_9915)
                {
                    _9921 = all(bool2(_12508.x < 1.0f.xx.x, _12508.y < 1.0f.xx.y));
                }
                else
                {
                    _9921 = _9915;
                }
                _5390 = _9921;
            }
            else
            {
                _5390 = _5384;
            }
            bool _5395;
            if (_5390)
            {
                bool _9926 = all(bool2(_12509.x > 0.0f.xx.x, _12509.y > 0.0f.xx.y));
                bool _9932;
                if (_9926)
                {
                    _9932 = all(bool2(_12509.x < 1.0f.xx.x, _12509.y < 1.0f.xx.y));
                }
                else
                {
                    _9932 = _9926;
                }
                _5395 = _9932;
            }
            else
            {
                _5395 = _5390;
            }
            bool _5402;
            if (_5395)
            {
                float _13083;
                do
                {
                    bool _10015 = all(bool2(_12508.x > 0.0f.xx.x, _12508.y > 0.0f.xx.y));
                    bool _10021;
                    if (_10015)
                    {
                        _10021 = all(bool2(_12508.x < 1.0f.xx.x, _12508.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10021 = _10015;
                    }
                    bool _9952 = !_10021;
                    bool _9959;
                    if (!_9952)
                    {
                        bool _10026 = all(bool2(_12509.x > 0.0f.xx.x, _12509.y > 0.0f.xx.y));
                        bool _10032;
                        if (_10026)
                        {
                            _10032 = all(bool2(_12509.x < 1.0f.xx.x, _12509.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _10032 = _10026;
                        }
                        _9959 = !_10032;
                    }
                    else
                    {
                        _9959 = _9952;
                    }
                    if (_9959)
                    {
                        _13083 = 0.0f;
                        break;
                    }
                    uint _10039_dummy_parameter;
                    uint _10055_dummy_parameter;
                    float4 _9980 = mul(float4((float2(_12508.x, 1.0f - _12508.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12508 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10039_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _9982 = _9980.w;
                    if (abs(_9982) < 9.9999999747524270787835121154785e-07f)
                    {
                        _13083 = 0.0f;
                        break;
                    }
                    float _9993 = abs(cbFI_DeviceToViewDepth.y / ((_9980.z / _9982) - cbFI_DeviceToViewDepth.x));
                    float _9996 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12509 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10055_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _13083 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9993 - _9996) / max(max(_9993, _9996), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5402 = _13083 < 0.5f;
            }
            else
            {
                _5402 = _5395;
            }
            float4 _13098;
            if (_5402)
            {
                uint _10105_dummy_parameter;
                uint _10136_dummy_parameter;
                float4 _13099;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_12508 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10105_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12509 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10136_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _13099 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _13099 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _13098 = _13099;
            }
            else
            {
                _13098 = 1.0f.xxxx;
            }
            bool _5426;
            if (_8880)
            {
                bool _10165 = all(bool2(_12505.x > 0.0f.xx.x, _12505.y > 0.0f.xx.y));
                bool _10171;
                if (_10165)
                {
                    _10171 = all(bool2(_12505.x < 1.0f.xx.x, _12505.y < 1.0f.xx.y));
                }
                else
                {
                    _10171 = _10165;
                }
                _5426 = _10171;
            }
            else
            {
                _5426 = _8880;
            }
            bool _5432;
            if (_8880)
            {
                bool _10176 = all(bool2(_12507.x > 0.0f.xx.x, _12507.y > 0.0f.xx.y));
                bool _10182;
                if (_10176)
                {
                    _10182 = all(bool2(_12507.x < 1.0f.xx.x, _12507.y < 1.0f.xx.y));
                }
                else
                {
                    _10182 = _10176;
                }
                _5432 = _10182;
            }
            else
            {
                _5432 = _8880;
            }
            bool _5438;
            if (_8912)
            {
                bool _10187 = all(bool2(_12508.x > 0.0f.xx.x, _12508.y > 0.0f.xx.y));
                bool _10193;
                if (_10187)
                {
                    _10193 = all(bool2(_12508.x < 1.0f.xx.x, _12508.y < 1.0f.xx.y));
                }
                else
                {
                    _10193 = _10187;
                }
                _5438 = _10193;
            }
            else
            {
                _5438 = _8912;
            }
            bool _5444;
            if (_8912)
            {
                bool _10198 = all(bool2(_12509.x > 0.0f.xx.x, _12509.y > 0.0f.xx.y));
                bool _10204;
                if (_10198)
                {
                    _10204 = all(bool2(_12509.x < 1.0f.xx.x, _12509.y < 1.0f.xx.y));
                }
                else
                {
                    _10204 = _10198;
                }
                _5444 = _10204;
            }
            else
            {
                _5444 = _8912;
            }
            bool _5447 = _5438 != _5444;
            bool _5453;
            if (_5447)
            {
                _5453 = _5426 || _5432;
            }
            else
            {
                _5453 = _5447;
            }
            float4 _13197;
            if (_5453)
            {
                float4 _12370 = _13098;
                _12370.z = 0.0f;
                _12370.w = 0.0f;
                _13197 = _12370;
            }
            else
            {
                _13197 = _13098;
            }
            bool _5460 = _5426 && _5372;
            bool _5463 = _5432 && _5375;
            float4 _13302;
            float3 _14166;
            if (_5460 || _5463)
            {
                float _13192;
                do
                {
                    uint4 _10343 = r_warped_motion_qdata_tp1.Load(int3(_12622, 0));
                    uint _10344 = _10343.x;
                    if (_10344 != 0u)
                    {
                        float _13191;
                        if (_10344 == 0u)
                        {
                            _13191 = -1.0f;
                        }
                        else
                        {
                            _13191 = float((_10344 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13192 = _13191;
                        break;
                    }
                    int _13174;
                    uint _13175;
                    _13175 = _10344;
                    _13174 = -1;
                    uint _13190;
                    for (; _13174 <= 1; _13175 = _13190, _13174++)
                    {
                        _13190 = _13175;
                        for (int _13188 = -1; _13188 <= 1; )
                        {
                            _13190 = max(_13190, r_warped_motion_qdata_tp1.Load(int3(clamp(_12622 + int2(_13188, _13174), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _13188++;
                            continue;
                        }
                    }
                    if (_13175 != 0u)
                    {
                        float _13187;
                        if (_13175 == 0u)
                        {
                            _13187 = -1.0f;
                        }
                        else
                        {
                            _13187 = float((_13175 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13192 = _13187;
                        break;
                    }
                    uint _13177;
                    _13177 = 4294967295u;
                    uint _15088;
                    for (int _13176 = 0; _13176 < 8; _13177 = _15088, _13176++)
                    {
                        int _13180 = 0;
                        for (;;)
                        {
                            if (_13180 < 5)
                            {
                                int2 _10294 = _12622 + (_1090[_13176] * _1099[_13180].xx);
                                bool _10297 = any(bool2(_10294.x < int2(0, 0).x, _10294.y < int2(0, 0).y));
                                bool _10305;
                                if (!_10297)
                                {
                                    _10305 = any(bool2(_10294.x >= cbFI_MvDepthLaneSize.x, _10294.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _10305 = _10297;
                                }
                                if (_10305)
                                {
                                    _15088 = _13177;
                                    break;
                                }
                                uint4 _10383 = r_warped_motion_qdata_tp1.Load(int3(_10294, 0));
                                uint _10384 = _10383.x;
                                if (_10384 != 0u)
                                {
                                    _15088 = min(_13177, _10384);
                                    break;
                                }
                                _13180++;
                                continue;
                            }
                            else
                            {
                                _15088 = _13177;
                                break;
                            }
                        }
                    }
                    float _13179;
                    if (_13177 == 4294967295u)
                    {
                        _13179 = -1.0f;
                    }
                    else
                    {
                        float _13178;
                        if (_13177 == 0u)
                        {
                            _13178 = -1.0f;
                        }
                        else
                        {
                            _13178 = float((_13177 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13179 = _13178;
                    }
                    _13192 = _13179;
                    break;
                } while(false);
                bool _5471 = _13192 < 0.0f;
                float _13193;
                if (_5471)
                {
                    _13193 = 0.0f;
                }
                else
                {
                    _13193 = _13192 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _10405_dummy_parameter;
                uint _10437_dummy_parameter;
                float4 _13230;
                if ((_5471 && _5460) && _5463)
                {
                    uint _10469_dummy_parameter;
                    float _10493 = log((r_depth_tm1.Load(int3(int2(floor(_12505 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10469_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _10501_dummy_parameter;
                    float _10525 = log((r_depth_tp1.Load(int3(int2(floor(_12507 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10501_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _13231;
                    if (_10493 > (_10525 + 0.07999999821186065673828125f))
                    {
                        float4 _12374 = _13197;
                        _12374.x = 0.0f;
                        _13231 = _12374;
                    }
                    else
                    {
                        float4 _13232;
                        if (_10525 > (_10493 + 0.07999999821186065673828125f))
                        {
                            float4 _12376 = _13197;
                            _12376.y = 0.0f;
                            _13232 = _12376;
                        }
                        else
                        {
                            _13232 = _13197;
                        }
                        _13231 = _13232;
                    }
                    _13230 = _13231;
                }
                else
                {
                    _13230 = _13197;
                }
                float _5523 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5525 = _13192 >= 0.0f;
                float _13213;
                if (_5525)
                {
                    _13213 = _13192 - _5523;
                }
                else
                {
                    float _13209;
                    if (_5460)
                    {
                        float _13208;
                        _13208 = 2.0f;
                        float _10583;
                        for (int _13207 = 0; _13207 < 24; _13208 = _10583, _13207++)
                        {
                            float _10547 = float(_13207 & 7) * 0.785398185253143310546875f;
                            int _10549 = _13207 >> 3;
                            int _13210;
                            if (_10549 == 0)
                            {
                                _13210 = 16;
                            }
                            else
                            {
                                _13210 = (_10549 == 1) ? 48 : 96;
                            }
                            uint _10599_dummy_parameter;
                            _10583 = min(_13208, log((r_depth_tm1.Load(int3(int2(floor(clamp(_12505 + ((cbFI_MvDepthLaneSizeRcp * float(_13210)) * float2(cos(_10547), sin(_10547))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10599_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _13209 = _13208;
                    }
                    else
                    {
                        _13209 = 0.0f;
                    }
                    _13213 = _13209;
                }
                float _13220;
                if (_5525)
                {
                    _13220 = _13192 - _5523;
                }
                else
                {
                    float _13216;
                    if (_5463)
                    {
                        float _13215;
                        _13215 = 2.0f;
                        float _10697;
                        for (int _13214 = 0; _13214 < 24; _13215 = _10697, _13214++)
                        {
                            float _10661 = float(_13214 & 7) * 0.785398185253143310546875f;
                            int _10663 = _13214 >> 3;
                            int _13217;
                            if (_10663 == 0)
                            {
                                _13217 = 16;
                            }
                            else
                            {
                                _13217 = (_10663 == 1) ? 48 : 96;
                            }
                            uint _10729_dummy_parameter;
                            _10697 = min(_13215, log((r_depth_tp1.Load(int3(int2(floor(clamp(_12507 + ((cbFI_MvDepthLaneSizeRcp * float(_13217)) * float2(cos(_10661), sin(_10661))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10729_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _13216 = _13215;
                    }
                    else
                    {
                        _13216 = 0.0f;
                    }
                    _13220 = _13216;
                }
                float _13221;
                if (_5460)
                {
                    uint _10761_dummy_parameter;
                    _13221 = r_depth_tm1.Load(int3(int2(floor(_12505 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10761_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _13221 = 0.0f;
                }
                float _13222;
                if (_5463)
                {
                    uint _10780_dummy_parameter;
                    _13222 = r_depth_tp1.Load(int3(int2(floor(_12507 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10780_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _13222 = 0.0f;
                }
                bool _5580;
                if (_5460)
                {
                    _5580 = _13221 > ((exp((_13213 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5580 = _5460;
                }
                float4 _13238;
                if (_5580)
                {
                    float4 _12378 = _13230;
                    _12378.x = 0.0f;
                    _13238 = _12378;
                }
                else
                {
                    _13238 = _13230;
                }
                bool _5592;
                if (_5463)
                {
                    _5592 = _13222 > ((exp((_13220 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5592 = _5463;
                }
                float4 _13240;
                if (_5592)
                {
                    float4 _12380 = _13238;
                    _12380.y = 0.0f;
                    _13240 = _12380;
                }
                else
                {
                    _13240 = _13238;
                }
                float4 _13303;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5525)
                {
                    bool _5612;
                    if (_5460)
                    {
                        _5612 = _13221 < ((exp((_13213 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5612 = _5460;
                    }
                    float4 _13242;
                    if (_5612)
                    {
                        float4 _12382 = _13240;
                        _12382.x = 0.0f;
                        _13242 = _12382;
                    }
                    else
                    {
                        _13242 = _13240;
                    }
                    bool _5624;
                    if (_5463)
                    {
                        _5624 = _13222 < ((exp((_13220 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5624 = _5463;
                    }
                    float4 _13304;
                    if (_5624)
                    {
                        float4 _12384 = _13242;
                        _12384.y = 0.0f;
                        _13304 = _12384;
                    }
                    else
                    {
                        _13304 = _13242;
                    }
                    _13303 = _13304;
                }
                else
                {
                    _13303 = _13240;
                }
                _14166 = float3(_13193, log((r_depth_tm1.Load(int3(int2(floor(_12505 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10405_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_12507 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10437_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _13302 = _13303;
            }
            else
            {
                _14166 = float3(0.0f, 0.0f, 0.5f);
                _13302 = _13197;
            }
            bool _5635 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5384;
            bool _5641;
            if (_5635)
            {
                _5641 = _5438 || _5444;
            }
            else
            {
                _5641 = _5635;
            }
            float4 _13325;
            if (_5641)
            {
                float _13297;
                do
                {
                    uint4 _10959 = r_warped_motion_qdata_tp1.Load(int3(_12622, 0));
                    uint _10960 = _10959.x;
                    if (_10960 != 0u)
                    {
                        float _13296;
                        if (_10960 == 0u)
                        {
                            _13296 = -1.0f;
                        }
                        else
                        {
                            _13296 = float((_10960 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13297 = _13296;
                        break;
                    }
                    int _13279;
                    uint _13280;
                    _13280 = _10960;
                    _13279 = -1;
                    uint _13295;
                    for (; _13279 <= 1; _13280 = _13295, _13279++)
                    {
                        _13295 = _13280;
                        for (int _13293 = -1; _13293 <= 1; )
                        {
                            _13295 = max(_13295, r_warped_motion_qdata_tp1.Load(int3(clamp(_12622 + int2(_13293, _13279), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _13293++;
                            continue;
                        }
                    }
                    if (_13280 != 0u)
                    {
                        float _13292;
                        if (_13280 == 0u)
                        {
                            _13292 = -1.0f;
                        }
                        else
                        {
                            _13292 = float((_13280 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13297 = _13292;
                        break;
                    }
                    uint _13282;
                    _13282 = 4294967295u;
                    uint _15089;
                    for (int _13281 = 0; _13281 < 8; _13282 = _15089, _13281++)
                    {
                        int _13285 = 0;
                        for (;;)
                        {
                            if (_13285 < 5)
                            {
                                int2 _10910 = _12622 + (_1090[_13281] * _1099[_13285].xx);
                                bool _10913 = any(bool2(_10910.x < int2(0, 0).x, _10910.y < int2(0, 0).y));
                                bool _10921;
                                if (!_10913)
                                {
                                    _10921 = any(bool2(_10910.x >= cbFI_MvDepthLaneSize.x, _10910.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _10921 = _10913;
                                }
                                if (_10921)
                                {
                                    _15089 = _13282;
                                    break;
                                }
                                uint4 _10999 = r_warped_motion_qdata_tp1.Load(int3(_10910, 0));
                                uint _11000 = _10999.x;
                                if (_11000 != 0u)
                                {
                                    _15089 = min(_13282, _11000);
                                    break;
                                }
                                _13285++;
                                continue;
                            }
                            else
                            {
                                _15089 = _13282;
                                break;
                            }
                        }
                    }
                    float _13284;
                    if (_13282 == 4294967295u)
                    {
                        _13284 = -1.0f;
                    }
                    else
                    {
                        float _13283;
                        if (_13282 == 0u)
                        {
                            _13283 = -1.0f;
                        }
                        else
                        {
                            _13283 = float((_13282 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _13284 = _13283;
                    }
                    _13297 = _13284;
                    break;
                } while(false);
                float4 _13326;
                if (_13297 >= 0.0f)
                {
                    float _11021 = (exp((_13297 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5660;
                    if (_5438)
                    {
                        uint _11028_dummy_parameter;
                        _5660 = r_depth_tm1.Load(int3(int2(floor(_12508 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11028_dummy_parameter))))), 0)).x > _11021;
                    }
                    else
                    {
                        _5660 = _5438;
                    }
                    float4 _13315;
                    if (_5660)
                    {
                        float4 _12386 = _13302;
                        _12386.z = 0.0f;
                        _13315 = _12386;
                    }
                    else
                    {
                        _13315 = _13302;
                    }
                    bool _5672;
                    if (_5444)
                    {
                        uint _11047_dummy_parameter;
                        _5672 = r_depth_tp1.Load(int3(int2(floor(_12509 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11047_dummy_parameter))))), 0)).x > _11021;
                    }
                    else
                    {
                        _5672 = _5444;
                    }
                    float4 _13327;
                    if (_5672)
                    {
                        float4 _12388 = _13315;
                        _12388.w = 0.0f;
                        _13327 = _12388;
                    }
                    else
                    {
                        _13327 = _13315;
                    }
                    _13326 = _13327;
                }
                else
                {
                    _13326 = _13302;
                }
                _13325 = _13326;
            }
            else
            {
                _13325 = _13302;
            }
            bool _5680 = _5426 != _5432;
            bool _5687;
            if (_5680)
            {
                _5687 = _5426 ? _5372 : _5375;
            }
            else
            {
                _5687 = _5680;
            }
            bool _5694;
            if (_5687)
            {
                _5694 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5694 = _5687;
            }
            float4 _13410;
            if (_5694)
            {
                bool2 _5699 = _5426.xx;
                float2 _5700 = float2(_5699.x ? _12505.x : _12507.x, _5699.y ? _12505.y : _12507.y);
                float _13317;
                if (_5426)
                {
                    uint _11066_dummy_parameter;
                    _13317 = r_depth_tm1.Load(int3(int2(floor(_5700 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11066_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _11082_dummy_parameter;
                    _13317 = r_depth_tp1.Load(int3(int2(floor(_5700 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11082_dummy_parameter))))), 0)).x;
                }
                float4x4 _13318;
                if (_5426)
                {
                    _13318 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _13318 = cbFI_MotionTP1ToTM1;
                }
                float2 _13319;
                do
                {
                    float _11109 = _5700.x;
                    float _11112 = 1.0f - _5700.y;
                    float4 _11123 = mul(float4((float2(_11109, _11112) * 2.0f) - 1.0f.xx, _13317, 1.0f), _13318);
                    float _11125 = _11123.w;
                    if (!(_11125 > 9.9999999747524270787835121154785e-07f))
                    {
                        _13319 = 1000000.0f.xx;
                        break;
                    }
                    float2 _11138 = ((_11123.xy / _11125.xx) + 1.0f.xx) * 0.5f;
                    _13319 = float2(_11138.x - _11109, _11112 - _11138.y);
                    break;
                } while(false);
                float2 _5730 = float2(cbFI_DisplaySize);
                float4 _13411;
                if (!(length(((_5700 + _13319) - float2(_5699.x ? _12507.x : _12505.x, _5699.y ? _12507.y : _12505.y)) * _5730) <= ((0.100000001490116119384765625f * length(_13319 * _5730)) + 8.0f)))
                {
                    float4 _13412;
                    if (_5426)
                    {
                        float4 _12398 = _13325;
                        _12398.x = 0.0f;
                        _13412 = _12398;
                    }
                    else
                    {
                        float4 _12400 = _13325;
                        _12400.y = 0.0f;
                        _13412 = _12400;
                    }
                    _13411 = _13412;
                }
                else
                {
                    _13411 = _13325;
                }
                _13410 = _13411;
            }
            else
            {
                _13410 = _13325;
            }
            float4 _5755 = _13072 * _13410;
            float _5757 = dot(_5755, 1.0f.xxxx);
            float4 _13687;
            bool _13949;
            if (_5757 > 0.0f)
            {
                _13949 = _12779;
                _13687 = _5755 / _5757.xxxx;
            }
            else
            {
                bool _5768 = any(bool4(_13410.x < 1.0f.xxxx.x, _13410.y < 1.0f.xxxx.y, _13410.z < 1.0f.xxxx.z, _13410.w < 1.0f.xxxx.w));
                if (_5768)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11160;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11160);
                    }
                }
                bool4 _15124 = _5768.xxxx;
                _13949 = _5768 ? true : _12779;
                _13687 = float4(_15124.x ? 0.0f.xxxx.x : _13072.x, _15124.y ? 0.0f.xxxx.y : _13072.y, _15124.z ? 0.0f.xxxx.z : _13072.z, _15124.w ? 0.0f.xxxx.w : _13072.w);
            }
            _14065 = _14166;
            _13948 = _13949;
            _13686 = _13687;
        }
        else
        {
            _14065 = float3(0.0f, 0.0f, 0.5f);
            _13948 = _12779;
            _13686 = _13072;
        }
        uint _5777 = (cbFI_pad0 >> 24u) & 31u;
        uint _5781 = (cbFI_pad0 >> 16u) & 255u;
        bool _5783 = _5777 != 0u;
        bool _5785 = _5781 == 12u;
        bool _5788 = _5781 == 13u;
        float4 _13703;
        if ((_5783 || _5785) || _5788)
        {
            float _13413;
            do
            {
                bool _11244 = all(bool2(_12508.x > 0.0f.xx.x, _12508.y > 0.0f.xx.y));
                bool _11250;
                if (_11244)
                {
                    _11250 = all(bool2(_12508.x < 1.0f.xx.x, _12508.y < 1.0f.xx.y));
                }
                else
                {
                    _11250 = _11244;
                }
                bool _11181 = !_11250;
                bool _11188;
                if (!_11181)
                {
                    bool _11255 = all(bool2(_12509.x > 0.0f.xx.x, _12509.y > 0.0f.xx.y));
                    bool _11261;
                    if (_11255)
                    {
                        _11261 = all(bool2(_12509.x < 1.0f.xx.x, _12509.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11261 = _11255;
                    }
                    _11188 = !_11261;
                }
                else
                {
                    _11188 = _11181;
                }
                if (_11188)
                {
                    _13413 = 0.0f;
                    break;
                }
                uint _11268_dummy_parameter;
                uint _11284_dummy_parameter;
                float4 _11209 = mul(float4((float2(_12508.x, 1.0f - _12508.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_12508 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11268_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _11211 = _11209.w;
                if (abs(_11211) < 9.9999999747524270787835121154785e-07f)
                {
                    _13413 = 0.0f;
                    break;
                }
                float _11222 = abs(cbFI_DeviceToViewDepth.y / ((_11209.z / _11211) - cbFI_DeviceToViewDepth.x));
                float _11225 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_12509 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11284_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _13413 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11222 - _11225) / max(max(_11222, _11225), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _11332 = all(bool2(_12509.x > 0.0f.xx.x, _12509.y > 0.0f.xx.y));
            bool _11338;
            if (_11332)
            {
                _11338 = all(bool2(_12509.x < 1.0f.xx.x, _12509.y < 1.0f.xx.y));
            }
            else
            {
                _11338 = _11332;
            }
            float _13414;
            if (_11338)
            {
                uint _11345_dummy_parameter;
                _13414 = length((_6594 + (r_motion_tp1.Load(int3(int2(floor(_12509 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _11345_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _13414 = 1000000.0f;
            }
            float _13425;
            if ((_5777 & 1u) != 0u)
            {
                _13425 = _13413;
            }
            else
            {
                _13425 = 1.0f;
            }
            float _13426;
            if ((_5777 & 2u) != 0u)
            {
                _13426 = _13425 * (1.0f - smoothstep(2.0f, 8.0f, _13414));
            }
            else
            {
                _13426 = _13425;
            }
            float _13427;
            if ((_5777 & 4u) != 0u)
            {
                _13427 = _13426 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_7315 - _7323) - length(_7299 - _7307))));
            }
            else
            {
                _13427 = _13426;
            }
            float _13697;
            if ((_5777 & 8u) != 0u)
            {
                _13697 = lerp(1.0f, _13427, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_7299 - _7307)));
            }
            else
            {
                _13697 = _13427;
            }
            bool _5863 = (_5777 & 16u) != 0u;
            bool _5872;
            if (_5863)
            {
                _5872 = length(_12503 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5872 = _5863;
            }
            float _15126 = _5872 ? 1.0f : _13697;
            bool _5878 = _5783 && _8880;
            bool _5883;
            if (_5878)
            {
                bool _11370 = all(bool2(_12505.x > 0.0f.xx.x, _12505.y > 0.0f.xx.y));
                bool _11376;
                if (_11370)
                {
                    _11376 = all(bool2(_12505.x < 1.0f.xx.x, _12505.y < 1.0f.xx.y));
                }
                else
                {
                    _11376 = _11370;
                }
                _5883 = _11376;
            }
            else
            {
                _5883 = _5878;
            }
            bool _5888;
            if (_5883)
            {
                bool _11381 = all(bool2(_12507.x > 0.0f.xx.x, _12507.y > 0.0f.xx.y));
                bool _11387;
                if (_11381)
                {
                    _11387 = all(bool2(_12507.x < 1.0f.xx.x, _12507.y < 1.0f.xx.y));
                }
                else
                {
                    _11387 = _11381;
                }
                _5888 = _11387;
            }
            else
            {
                _5888 = _5883;
            }
            float4 _13704;
            if (_5888)
            {
                float _5894 = _13686.x + _13686.y;
                float _5903 = (_13686.z + _13686.w) * (1.0f - _15126);
                float _13700;
                if (_5894 > 9.9999997473787516355514526367188e-06f)
                {
                    _13700 = _13686.x / _5894;
                }
                else
                {
                    _13700 = _4633;
                }
                _13704 = float4(_13686.x + (_5903 * _13700), _13686.y + (_5903 * (1.0f - _13700)), _13686.zw * _15126);
            }
            else
            {
                _13704 = _13686;
            }
            _13703 = _13704;
        }
        else
        {
            _13703 = _13686;
        }
        float3 _5964 = (((_7299 * _13703.x) + (_7307 * _13703.y)) + (_7315 * _13703.z)) + (_7323 * _13703.w);
        float3 _14891;
        if (_4649 && (_13718 > 0.0f))
        {
            uint _11394_dummy_parameter;
            float2 _11409 = r_motion_tp1.Load(int3(int2(floor(_4408 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _11394_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _13940;
            if (_6622)
            {
                float2 _11454 = clamp((((_12482 + (_11409 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _11457 = tan(_11454.x);
                _13940 = (float2(_11457 / cbFI_DeviceToViewDepth.z, (tan(_11454.y) * sqrt(1.0f + (_11457 * _11457))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _13940 = _12482 + (_11409 * cbFI_Timestep);
            }
            float2 _13941;
            if (_6622)
            {
                float2 _11533 = clamp((((_12482 + (_11409 * _4623)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _11536 = tan(_11533.x);
                _13941 = (float2(_11536 / cbFI_DeviceToViewDepth.z, (tan(_11533.y) * sqrt(1.0f + (_11536 * _11536))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _13941 = _12482 + (_11409 * _4623);
            }
            _14891 = lerp(_5964, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _13940, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _13941, 0.0f).xyz, cbFI_Timestep.xxx), _13718.xxx);
        }
        else
        {
            _14891 = _5964;
        }
        float3 _14890;
        if (_13948)
        {
            float3 _11578 = r_current_interpolation_source.Load(int3(_3962, 0)).xyz;
            float3 _14892;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _8880)
            {
                uint _11585_dummy_parameter;
                float _14055;
                _14055 = r_depth_tm1.Load(int3(int2(floor(_12505 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11585_dummy_parameter))))), 0)).x;
                float _6045;
                for (int _14054 = 0; _14054 < 24; _14055 = _6045, _14054++)
                {
                    float _6017 = float(_14054 & 7) * 0.785398185253143310546875f;
                    int _6019 = _14054 >> 3;
                    int _14942;
                    if (_6019 == 0)
                    {
                        _14942 = 16;
                    }
                    else
                    {
                        _14942 = (_6019 == 1) ? 48 : 96;
                    }
                    uint _11605_dummy_parameter;
                    _6045 = min(_14055, r_depth_tm1.Load(int3(int2(floor(clamp(_12505 + ((cbFI_MvDepthLaneSizeRcp * float(_14942)) * float2(cos(_6017), sin(_6017))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11605_dummy_parameter))))), 0)).x);
                }
                float2 _14056;
                do
                {
                    float _11627 = 1.0f - _12505.y;
                    float4 _11638 = mul(float4((float2(_12505.x, _11627) * 2.0f) - 1.0f.xx, _14055, 1.0f), cbFI_MotionTM1ToTM2);
                    float _11640 = _11638.w;
                    if (!(_11640 > 9.9999999747524270787835121154785e-07f))
                    {
                        _14056 = 1000000.0f.xx;
                        break;
                    }
                    float2 _11653 = ((_11638.xy / _11640.xx) + 1.0f.xx) * 0.5f;
                    _14056 = float2(_11653.x - _12505.x, _11627 - _11653.y);
                    break;
                } while(false);
                float2 _6056 = _12505 + _14056;
                bool _11671 = all(bool2(_6056.x > 0.0f.xx.x, _6056.y > 0.0f.xx.y));
                bool _11677;
                if (_11671)
                {
                    _11677 = all(bool2(_6056.x < 1.0f.xx.x, _6056.y < 1.0f.xx.y));
                }
                else
                {
                    _11677 = _11671;
                }
                float3 _14893;
                if (_11677)
                {
                    float _6062 = abs(cbFI_DeviceToViewDepth.y / (_14055 - cbFI_DeviceToViewDepth.x));
                    uint _11697_dummy_parameter;
                    int2 _11697 = int2(spvTextureSize(r_depth_m2, uint(0), _11697_dummy_parameter));
                    float _6066 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_6056 * float2(_11697))), int2(0, 0), _11697 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _14898;
                    if (abs(_6066 - _6062) <= (0.20000000298023223876953125f * max(_6066, _6062)))
                    {
                        uint _11731_dummy_parameter;
                        int2 _11731 = int2(spvTextureSize(r_colour_m2, uint(0), _11731_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _11754;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _11754);
                        }
                        _14898 = r_colour_m2.Load(int3(clamp(int2(floor(_6056 * float2(_11731))), int2(0, 0), _11731 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _11764;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _11764);
                        }
                        _14898 = _11578;
                    }
                    _14893 = _14898;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11774;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _11774);
                    }
                    _14893 = _11578;
                }
                _14892 = _14893;
            }
            else
            {
                _14892 = _11578;
            }
            _14890 = _14892;
        }
        else
        {
            _14890 = _14891;
        }
        uint _6094 = cbFI_pad0 & 255u;
        bool _14779;
        float3 _14889;
        if (_6094 != 0u)
        {
            float3 _6099 = r_present_backbuffer.Load(int3(_3962, 0)).xyz;
            float3 _6103 = r_current_interpolation_source.Load(int3(_3962, 0)).xyz;
            float3 _6107 = abs(_6099 - _6103);
            float3 _14059;
            if (_6094 == 2u)
            {
                _14059 = (abs(_6103) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _14059 = 0.000244140625f.xxx;
            }
            bool _6123 = any(bool3(_6107.x > _14059.x, _6107.y > _14059.y, _6107.z > _14059.z));
            bool3 _15127 = _6123.xxx;
            _14889 = float3(_15127.x ? _6099.x : _14890.x, _15127.y ? _6099.y : _14890.y, _15127.z ? _6099.z : _14890.z);
            _14779 = _6123;
        }
        else
        {
            _14889 = _14890;
            _14779 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _11789;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _11789);
        }
        float3 _14872;
        if (_5781 == 1u)
        {
            _14872 = lerp(_7299, _7307, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _14873;
            if (_5781 == 2u)
            {
                _14873 = lerp(_7315, _7323, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _14874;
                if (_5781 == 3u)
                {
                    _14874 = float(_14779).xxx;
                }
                else
                {
                    float3 _14875;
                    if (_5781 == 4u)
                    {
                        _14875 = float3(((_12503 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _14876;
                        if (_5781 == 5u)
                        {
                            _14876 = float3(((_6594 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _14877;
                            if (_5781 == 6u)
                            {
                                _14877 = float3(_13703.xy, _13703.z + _13703.w);
                            }
                            else
                            {
                                float3 _14878;
                                if (_5781 == 7u)
                                {
                                    _14878 = r_current_interpolation_source.Load(int3(_3962, 0)).xyz;
                                }
                                else
                                {
                                    float3 _14879;
                                    if (_5781 == 8u)
                                    {
                                        _14879 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4408, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _14880;
                                        if (_5785)
                                        {
                                            uint _11811_dummy_parameter;
                                            uint _11843_dummy_parameter;
                                            _14880 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4408 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11811_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4408 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11843_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _14881;
                                            if (_5788)
                                            {
                                                _14881 = _7315;
                                            }
                                            else
                                            {
                                                float3 _14882;
                                                if (_5781 == 20u)
                                                {
                                                    _14882 = _7299;
                                                }
                                                else
                                                {
                                                    float3 _14883;
                                                    if (_5781 == 21u)
                                                    {
                                                        _14883 = _7307;
                                                    }
                                                    else
                                                    {
                                                        float3 _14884;
                                                        if (_5781 == 22u)
                                                        {
                                                            _14884 = _7323;
                                                        }
                                                        else
                                                        {
                                                            float3 _14885;
                                                            if (_5781 == 18u)
                                                            {
                                                                _14885 = _14483;
                                                            }
                                                            else
                                                            {
                                                                float3 _14886;
                                                                if (_5781 == 19u)
                                                                {
                                                                    _14886 = _14271;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _15129 = (_5781 == 23u).xxx;
                                                                    _14886 = float3(_15129.x ? _14065.x : _14889.x, _15129.y ? _14065.y : _14889.y, _15129.z ? _14065.z : _14889.z);
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
                                            _14880 = _14881;
                                        }
                                        _14879 = _14880;
                                    }
                                    _14878 = _14879;
                                }
                                _14877 = _14878;
                            }
                            _14876 = _14877;
                        }
                        _14875 = _14876;
                    }
                    _14874 = _14875;
                }
                _14873 = _14874;
            }
            _14872 = _14873;
        }
        float3 _14871;
        if ((_5781 >= 9u) && (_5781 <= 11u))
        {
            uint _6287 = 64u + uint((_12622.y * cbFI_MvDepthLaneSize.x) + _12622.x);
            uint _6291 = rw_nfru_diagnostics.Load<uint>(_6287 * 4 + 0) & 15u;
            float3 _14903;
            if (_5781 == 10u)
            {
                float3 _14870;
                if ((rw_nfru_diagnostics.Load<uint>(_6287 * 4 + 0) & 32u) != 0u)
                {
                    _14870 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _14869;
                    if ((rw_nfru_diagnostics.Load<uint>(_6287 * 4 + 0) & 16u) != 0u)
                    {
                        _14869 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _6312 = ((rw_nfru_diagnostics.Load<uint>(_6287 * 4 + 0) & 64u) != 0u).xxx;
                        _14869 = float3(_6312.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _6312.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _6312.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _14870 = _14869;
                }
                _14903 = _14870;
            }
            else
            {
                float3 _14904;
                if (_5781 == 11u)
                {
                    uint _6325 = (rw_nfru_diagnostics.Load<uint>(_6287 * 4 + 0) >> 8u) & 15u;
                    uint _6328 = (rw_nfru_diagnostics.Load<uint>(_6287 * 4 + 0) >> 12u) & 15u;
                    float3 _14862;
                    if ((_6291 == 2u) || (_6291 == 3u))
                    {
                        _14862 = _3675[_6291];
                    }
                    else
                    {
                        bool _6340 = _6325 == 3u;
                        bool _6342 = _6328 == 3u;
                        float3 _14863;
                        if (_6340 && _6342)
                        {
                            _14863 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _14864;
                            if (_6340)
                            {
                                _14864 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _14865;
                                if (_6342)
                                {
                                    _14865 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _14866;
                                    if ((_6325 == 4u) || (_6328 == 4u))
                                    {
                                        _14866 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _14867;
                                        if ((_6325 == 1u) || (_6328 == 1u))
                                        {
                                            _14867 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _15131 = (_6291 == 1u).xxx;
                                            _14867 = float3(_15131.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _15131.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _15131.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _14866 = _14867;
                                    }
                                    _14865 = _14866;
                                }
                                _14864 = _14865;
                            }
                            _14863 = _14864;
                        }
                        _14862 = _14863;
                    }
                    _14904 = _14862;
                }
                else
                {
                    _14904 = _3675[min(_6291, 7u)];
                }
                _14903 = _14904;
            }
            _14871 = _14903;
        }
        else
        {
            _14871 = _14872;
        }
        float4 _14907;
        if ((_5781 >= 14u) && (_5781 <= 16u))
        {
            float2 _14905;
            if (_5781 == 14u)
            {
                uint _6398_dummy_parameter;
                uint _6404_dummy_parameter;
                _14905 = r_flow_tm1.Load(int3(clamp(int2(floor(_4408 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _6398_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6404_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _14906;
                if (_5781 == 16u)
                {
                    uint _11894 = r_warped_flow_qdata_tm1.Load(int3(_4424, 0)).x & 2147483647u;
                    uint _11926 = uint(max((int((_11894 >> 16u) & 15u) - 6), 0));
                    _14906 = ((float2(float((1 - (2 * int((_11894 >> 15u) & 1u))) * int(((_11894 >> uint(7)) & 127u) << _11926)), float((1 - (2 * int((_11894 >> 14u) & 1u))) * int((_11894 & 127u) << _11926))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _14906 = _6594 * float2(cbFI_DisplaySize);
                }
                _14905 = _14906;
            }
            uint2 _6437 = uint2(clamp(round(_14905 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6439 = _6437.x;
            uint _6446 = _6437.y;
            _14907 = float4(float(_6439 & 255u), float((_6439 >> 8u) | ((_6446 & 15u) << 4u)), float(_6446 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _14908;
            if (_5781 == 17u)
            {
                _14908 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4424, 0)).x != 0u), _4868, 0.0f, 1.0f);
            }
            else
            {
                _14908 = float4(_14871, 1.0f);
            }
            _14907 = _14908;
        }
        rw_output[_3962] = _14907.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6490 = ((uint(_3962.y) * uint(cbFI_DisplaySize.x)) + uint(_3962.x)) * 6u;
            uint _11972 = spvPackHalf2x16(clamp(_7298.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6490 * 4 + 0, (((_11972 & 32767u) >> 4u) | ((((_11972 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7298.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12007 = spvPackHalf2x16(clamp(_7306.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6490 + 1u) * 4 + 0, (((_12007 & 32767u) >> 4u) | ((((_12007 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7306.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12042 = spvPackHalf2x16(clamp(_7314.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6490 + 2u) * 4 + 0, (((_12042 & 32767u) >> 4u) | ((((_12042 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7314.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12077 = spvPackHalf2x16(clamp(_7322.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6490 + 3u) * 4 + 0, (((_12077 & 32767u) >> 4u) | ((((_12077 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_7322.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _12104 = r_current_interpolation_source.Load(int3(_3962, 0));
            uint _12118 = spvPackHalf2x16(clamp(_12104.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6490 + 4u) * 4 + 0, (((_12118 & 32767u) >> 4u) | ((((_12118 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12104.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _14941;
            if (_14779 || (_5781 != 0u))
            {
                _14941 = 4294967295u;
            }
            else
            {
                uint _12153 = spvPackHalf2x16(clamp(_14907.xy, 0.0f.xx, 65000.0f.xx));
                _14941 = (((_12153 & 32767u) >> 4u) | ((((_12153 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_14907.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6490 + 5u) * 4 + 0, _14941);
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
