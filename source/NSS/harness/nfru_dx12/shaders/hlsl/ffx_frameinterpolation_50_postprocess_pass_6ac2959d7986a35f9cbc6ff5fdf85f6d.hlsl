static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19871;

static const int2 _1243[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1252[5] = { 2, 4, 7, 11, 16 };
static const float3 _4746[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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

                                           
float spvDet2x2(float a1, float a2, float b1, float b2)
{
    return a1 * b2 - b1 * a2;
}

                                           
float spvDet3x3(float a1, float a2, float a3, float b1, float b2, float b3, float c1, float c2, float c3)
{
    return a1 * spvDet2x2(b2, b3, c2, c3) - b1 * spvDet2x2(a2, a3, c2, c3) + c1 * spvDet2x2(a2, a3, b2, b3);
}

                                                                                       
                                                                                   
float4x4 spvInverse(float4x4 m)
{
    float4x4 adj;	                                                             

                                                                                     
    adj[0][0] =  spvDet3x3(m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3]);
    adj[0][1] = -spvDet3x3(m[0][1], m[0][2], m[0][3], m[2][1], m[2][2], m[2][3], m[3][1], m[3][2], m[3][3]);
    adj[0][2] =  spvDet3x3(m[0][1], m[0][2], m[0][3], m[1][1], m[1][2], m[1][3], m[3][1], m[3][2], m[3][3]);
    adj[0][3] = -spvDet3x3(m[0][1], m[0][2], m[0][3], m[1][1], m[1][2], m[1][3], m[2][1], m[2][2], m[2][3]);

    adj[1][0] = -spvDet3x3(m[1][0], m[1][2], m[1][3], m[2][0], m[2][2], m[2][3], m[3][0], m[3][2], m[3][3]);
    adj[1][1] =  spvDet3x3(m[0][0], m[0][2], m[0][3], m[2][0], m[2][2], m[2][3], m[3][0], m[3][2], m[3][3]);
    adj[1][2] = -spvDet3x3(m[0][0], m[0][2], m[0][3], m[1][0], m[1][2], m[1][3], m[3][0], m[3][2], m[3][3]);
    adj[1][3] =  spvDet3x3(m[0][0], m[0][2], m[0][3], m[1][0], m[1][2], m[1][3], m[2][0], m[2][2], m[2][3]);

    adj[2][0] =  spvDet3x3(m[1][0], m[1][1], m[1][3], m[2][0], m[2][1], m[2][3], m[3][0], m[3][1], m[3][3]);
    adj[2][1] = -spvDet3x3(m[0][0], m[0][1], m[0][3], m[2][0], m[2][1], m[2][3], m[3][0], m[3][1], m[3][3]);
    adj[2][2] =  spvDet3x3(m[0][0], m[0][1], m[0][3], m[1][0], m[1][1], m[1][3], m[3][0], m[3][1], m[3][3]);
    adj[2][3] = -spvDet3x3(m[0][0], m[0][1], m[0][3], m[1][0], m[1][1], m[1][3], m[2][0], m[2][1], m[2][3]);

    adj[3][0] = -spvDet3x3(m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2], m[3][0], m[3][1], m[3][2]);
    adj[3][1] =  spvDet3x3(m[0][0], m[0][1], m[0][2], m[2][0], m[2][1], m[2][2], m[3][0], m[3][1], m[3][2]);
    adj[3][2] = -spvDet3x3(m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[3][0], m[3][1], m[3][2]);
    adj[3][3] =  spvDet3x3(m[0][0], m[0][1], m[0][2], m[1][0], m[1][1], m[1][2], m[2][0], m[2][1], m[2][2]);

                                                                                    
    float det = (adj[0][0] * m[0][0]) + (adj[0][1] * m[1][0]) + (adj[0][2] * m[2][0]) + (adj[0][3] * m[3][0]);

                                                              
                                                                               
    return (det != 0.0f) ? (adj * (1.0f / det)) : m;
}

void comp_main()
{
    int2 _5046 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_5046.x >= cbFI_DisplaySize.x, _5046.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_5046] = float4(r_present_backbuffer.Load(int3(_5046, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7899 = cbFI_DisplaySize - int2(1, 1);
                int2 _7900 = clamp(_5046, int2(0, 0), _7899);
                uint _7910 = uint((_7900.y * cbFI_DisplaySize.x) + _7900.x) * 2u;
                uint _7913 = rw_nfru_select.Load<uint>(_7910 * 4 + 0);
                float2 _7914 = spvUnpackHalf2x16(_7913);
                uint _7918 = rw_nfru_select.Load<uint>((_7910 + 1u) * 4 + 0);
                float2 _7919 = spvUnpackHalf2x16(_7918);
                float _7920 = _7914.x;
                float _7922 = _7919.x;
                if (_7919.y > 1.5f)
                {
                    rw_output[_5046] = float4(_7920, _7914.y, _7922, 1.0f).xyz;
                    break;
                }
                int _23545;
                float _23546;
                float3 _23547;
                float _23548;
                float _23549;
                _23549 = 0.0f;
                _23548 = 0.0f;
                _23547 = 0.0f.xxx;
                _23546 = 0.0f;
                _23545 = -2;
                float3 _23552;
                float _23553;
                float _23554;
                float _23555;
                for (; _23545 <= 2; _23549 = _23555, _23548 = _23554, _23547 = _23552, _23546 = _23553, _23545++)
                {
                    _23555 = _23549;
                    _23554 = _23548;
                    _23553 = _23546;
                    _23552 = _23547;
                    for (int _23550 = -2; _23550 <= 2; )
                    {
                        float _7816 = float((_23550 * _23550) + (_23545 * _23545));
                        float _7821 = exp(_7816 * (-0.319999992847442626953125f));
                        int2 _7826 = int2(_23550, _23545);
                        int2 _7936 = clamp(_5046 + (_7826 * int2(2, 2)), int2(0, 0), _7899);
                        uint _7946 = uint((_7936.y * cbFI_DisplaySize.x) + _7936.x) * 2u;
                        float _7843 = exp(_7816 * (-0.5f));
                        int2 _7968 = clamp(_5046 + (_7826 * int2(6, 6)), int2(0, 0), _7899);
                        _23555 += _7843;
                        _23554 += (_7843 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7968.y * cbFI_DisplaySize.x) + _7968.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23553 += _7821;
                        _23552 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7946 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7946 + 1u) * 4 + 0)).x, _19871).xyz * _7821);
                        _23550++;
                        continue;
                    }
                }
                float3 _7873 = _23547 / _23546.xxx;
                rw_output[_5046] = float4(_7873 + ((float4(_7920, _7914.y, _7922, _7919.y).xyz - _7873) * clamp(_23548 / _23549, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5545 = (float2(_5046) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5547 = float2(cbFI_MvDepthLaneSize);
        int2 _5556 = int2(floor(_5545 * _5547));
        int2 _5561 = int2(floor(_5545 * float2(cbFI_FlowLaneSize)));
        float4 _8039 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5545 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _8045 = r_warped_filled_flow_tm1.Load(int3(_5561, 0)).xy;
        float2 _8051 = r_warped_filled_motion_tp1.Load(int3(_5556, 0)).xy;
        bool _8073 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19872;
        if (_8073)
        {
            float _8086 = ((2.0f * _5545.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19872 = float2(atan(_8086) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5545.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_8086 * _8086))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19872 = _5545;
        }
        bool _5582 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19893;
        bool _20035;
        int2 _20116;
        float3 _22635;
        if (_5582)
        {
            float _19874;
            float _19876;
            _19876 = 2.0f;
            _19874 = -1.0f;
            uint _5143[9];
            float _23556;
            float _23559;
            for (int _19873 = 0; _19873 < 9; _19876 = _23559, _19874 = _23556, _19873++)
            {
                _5143[_19873] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5556 + int2((_19873 % 3) - 1, (_19873 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_5143[_19873] != 0u)
                {
                    float _23540;
                    if (_5143[_19873] == 0u)
                    {
                        _23540 = -1.0f;
                    }
                    else
                    {
                        _23540 = float((_5143[_19873] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23559 = min(_19876, _23540);
                    _23556 = max(_19874, _23540);
                }
                else
                {
                    _23559 = _19876;
                    _23556 = _19874;
                }
            }
            float _5628 = float(_19874 >= 0.0f);
            float3 _19409 = 0.0f.xxx;
            _19409.y = _5628;
            float2 _19894;
            bool _20036;
            int2 _20117;
            float3 _22636;
            if ((_19874 - _19876) > 0.0199999995529651641845703125f)
            {
                float _19882;
                int2 _19883;
                float2 _19884;
                int2 _19886;
                float2 _19892;
                _19892 = _8051;
                _19886 = _5556;
                _19884 = _8051;
                _19883 = _5556;
                _19882 = -1.0f;
                float _23564;
                int2 _23568;
                float2 _23579;
                int2 _23590;
                float2 _23623;
                float _23748;
                int _19881 = 0;
                float _23521 = 1000000000.0f;
                for (; _19881 < 9; _23521 = _23748, _19892 = _23623, _19886 = _23590, _19884 = _23579, _19883 = _23568, _19882 = _23564, _19881++)
                {
                    if (_5143[_19881] == 0u)
                    {
                        _23748 = _23521;
                        _23623 = _19892;
                        _23590 = _19886;
                        _23579 = _19884;
                        _23568 = _19883;
                        _23564 = _19882;
                        continue;
                    }
                    int2 _5663 = clamp(_5556 + int2((_19881 % 3) - 1, (_19881 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8161 = _5143[_19881] & 2147483647u;
                    uint _8193 = uint(max((int((_8161 >> 16u) & 15u) - 6), 0));
                    float2 _5669 = (float2(float((1 - (2 * int((_8161 >> 15u) & 1u))) * int(((_8161 >> uint(7)) & 127u) << _8193)), float((1 - (2 * int((_8161 >> 14u) & 1u))) * int((_8161 & 127u) << _8193))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23507;
                    if (_5143[_19881] == 0u)
                    {
                        _23507 = -1.0f;
                    }
                    else
                    {
                        _23507 = float((_5143[_19881] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5674 = _23507 - 0.100000001490116119384765625f;
                    float2 _23508;
                    if (_8073)
                    {
                        float2 _8270 = clamp((((_19872 + (_5669 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8273 = tan(_8270.x);
                        _23508 = (float2(_8273 / cbFI_DeviceToViewDepth.z, (tan(_8270.y) * sqrt(1.0f + (_8273 * _8273))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23508 = _19872 + (_5669 * cbFI_Timestep);
                    }
                    float _5681 = cbFI_Timestep - 1.0f;
                    float2 _23509;
                    if (_8073)
                    {
                        float2 _8341 = clamp((((_19872 + (_5669 * _5681)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8344 = tan(_8341.x);
                        _23509 = (float2(_8344 / cbFI_DeviceToViewDepth.z, (tan(_8341.y) * sqrt(1.0f + (_8344 * _8344))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23509 = _19872 + (_5669 * _5681);
                    }
                    bool _8377 = all(bool2(_23508.x > 0.0f.xx.x, _23508.y > 0.0f.xx.y));
                    bool _8383;
                    if (_8377)
                    {
                        _8383 = all(bool2(_23508.x < 1.0f.xx.x, _23508.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8383 = _8377;
                    }
                    float _23512;
                    if (_8383)
                    {
                        uint _8390_dummy_parameter;
                        _23512 = max((_5674 - (log(((r_depth_tm1.Load(int3(int2(floor(_23508 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8390_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23512 = 0.0f;
                    }
                    bool _8420 = all(bool2(_23509.x > 0.0f.xx.x, _23509.y > 0.0f.xx.y));
                    bool _8426;
                    if (_8420)
                    {
                        _8426 = all(bool2(_23509.x < 1.0f.xx.x, _23509.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8426 = _8420;
                    }
                    float _23513;
                    if (_8426)
                    {
                        uint _8433_dummy_parameter;
                        _23513 = _23512 + max((_5674 - (log(((r_depth_tp1.Load(int3(int2(floor(_23509 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8433_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23513 = _23512;
                    }
                    float _23565;
                    int2 _23569;
                    float2 _23580;
                    int2 _23591;
                    float2 _23624;
                    float _23749;
                    if (_23513 == 0.0f)
                    {
                        bool _5716 = _5674 > _19882;
                        bool2 _23757 = _5716.xx;
                        _23749 = _23521;
                        _23624 = float2(_23757.x ? _5669.x : _19892.x, _23757.y ? _5669.y : _19892.y);
                        _23591 = int2(_23757.x ? _5663.x : _19886.x, _23757.y ? _5663.y : _19886.y);
                        _23580 = _19884;
                        _23569 = _19883;
                        _23565 = _5716 ? _5674 : _19882;
                    }
                    else
                    {
                        bool _5725 = _23513 < _23521;
                        bool2 _23753 = _5725.xx;
                        _23749 = _5725 ? _23513 : _23521;
                        _23624 = _19892;
                        _23591 = _19886;
                        _23580 = float2(_23753.x ? _5669.x : _19884.x, _23753.y ? _5669.y : _19884.y);
                        _23569 = int2(_23753.x ? _5663.x : _19883.x, _23753.y ? _5663.y : _19883.y);
                        _23565 = _19882;
                    }
                    _23748 = _23749;
                    _23623 = _23624;
                    _23590 = _23591;
                    _23579 = _23580;
                    _23568 = _23569;
                    _23564 = _23565;
                }
                bool _5737 = _19882 < 0.0f;
                bool2 _23763 = _5737.xx;
                int2 _23766 = int2(_23763.x ? _19883.x : _19886.x, _23763.y ? _19883.y : _19886.y);
                _22636 = float3(1.0f, _5628, float(any(bool2(_23766.x != _5556.x, _23766.y != _5556.y))));
                _20117 = _23766;
                _20036 = _5737 ? false : true;
                _19894 = float2(_23763.x ? _19884.x : _19892.x, _23763.y ? _19884.y : _19892.y);
            }
            else
            {
                _22636 = _19409;
                _20117 = _5556;
                _20036 = false;
                _19894 = _8051;
            }
            _22635 = _22636;
            _20116 = _20117;
            _20035 = _20036;
            _19893 = _19894;
        }
        else
        {
            _22635 = 0.0f.xxx;
            _20116 = _5556;
            _20035 = false;
            _19893 = _8051;
        }
        float2 _19895;
        if (_8073)
        {
            float2 _8498 = clamp((((_19872 + (_19893 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8501 = tan(_8498.x);
            _19895 = (float2(_8501 / cbFI_DeviceToViewDepth.z, (tan(_8498.y) * sqrt(1.0f + (_8501 * _8501))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19895 = _19872 + (_19893 * cbFI_Timestep);
        }
        float _5760 = cbFI_Timestep - 1.0f;
        float2 _19897;
        if (_8073)
        {
            float2 _8569 = clamp((((_19872 + (_19893 * _5760)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8572 = tan(_8569.x);
            _19897 = (float2(_8572 / cbFI_DeviceToViewDepth.z, (tan(_8569.y) * sqrt(1.0f + (_8572 * _8572))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19897 = _19872 + (_19893 * _5760);
        }
        float _5765 = -cbFI_Timestep;
        float2 _19898;
        if (_8073)
        {
            float2 _8640 = clamp((((_19872 + (_8045 * _5765)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8643 = tan(_8640.x);
            _19898 = (float2(_8643 / cbFI_DeviceToViewDepth.z, (tan(_8640.y) * sqrt(1.0f + (_8643 * _8643))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19898 = _19872 + (_8045 * _5765);
        }
        float _5770 = 1.0f - cbFI_Timestep;
        float2 _19899;
        if (_8073)
        {
            float2 _8711 = clamp((((_19872 + (_8045 * _5770)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8714 = tan(_8711.x);
            _19899 = (float2(_8714 / cbFI_DeviceToViewDepth.z, (tan(_8711.y) * sqrt(1.0f + (_8714 * _8714))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19899 = _19872 + (_8045 * _5770);
        }
        float4 _8749 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19895, 0.0f);
        float3 _8750 = _8749.xyz;
        float4 _8757 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19897, 0.0f);
        float3 _8758 = _8757.xyz;
        float4 _8765 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19898, 0.0f);
        float3 _8766 = _8765.xyz;
        float4 _8773 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19899, 0.0f);
        float3 _8774 = _8773.xyz;
        float4 _8788 = exp(_8039 - max(max(max(_8039.x, _8039.y), _8039.z), _8039.w).xxxx);
        float4 _8795 = _8788 / (dot(_8788, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5786 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _20106;
        float _21414;
        if (_5786)
        {
            float2 _5792 = 0.5f.xx / _5547;
            float _5795 = _5792.x;
            float _5796 = -_5795;
            float _5798 = _5792.y;
            float _5799 = -_5798;
            float2 _5801 = _5545 + float2(_5796, _5799);
            float2 _5803 = float2(cbFI_DisplaySize);
            bool _19916;
            do
            {
                bool _8875 = all(bool2(_5801.x > 0.0f.xx.x, _5801.y > 0.0f.xx.y));
                bool _8881;
                if (_8875)
                {
                    _8881 = all(bool2(_5801.x < 1.0f.xx.x, _5801.y < 1.0f.xx.y));
                }
                else
                {
                    _8881 = _8875;
                }
                if (!_8881)
                {
                    _19916 = false;
                    break;
                }
                uint _8888_dummy_parameter;
                float4x4 _19914;
                do
                {
                    float4x4 _8902;
                    bool _19913;
                    do
                    {
                        _8902 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19913 = false;
                            break;
                        }
                        uint _8936 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8936 + 32u) * 4 + 0) != 1u)
                        {
                            _19913 = false;
                            break;
                        }
                        uint _19910;
                        _19910 = 0u;
                        for (; _19910 < 4u; _19910++)
                        {
                            for (uint _19911 = 0u; _19911 < 4u; )
                            {
                                _8902[_19910][_19911] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8936 + (_19910 * 4u)) + _19911) * 4 + 0));
                                _19911++;
                                continue;
                            }
                        }
                        _19913 = true;
                        break;
                    } while(false);
                    if (_19913)
                    {
                        _19914 = _8902;
                        break;
                    }
                    _19914 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19915;
                do
                {
                    float _9013 = _5801.x;
                    float _9016 = 1.0f - _5801.y;
                    float4 _9027 = mul(float4((float2(_9013, _9016) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5801 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8888_dummy_parameter))))), 0)).x, 1.0f), _19914);
                    float _9029 = _9027.w;
                    if (!(_9029 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19915 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9042 = ((_9027.xy / _9029.xx) + 1.0f.xx) * 0.5f;
                    _19915 = float2(_9042.x - _9013, _9016 - _9042.y);
                    break;
                } while(false);
                float2 _8839 = abs(_19915);
                if (any(bool2(_8839.x > 100000.0f.xx.x, _8839.y > 100000.0f.xx.y)))
                {
                    _19916 = false;
                    break;
                }
                float _8847 = length(_19915 * _5803);
                uint _9062_dummy_parameter;
                bool _8861 = _8847 > ((8.0f * _5803.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8868;
                if (_8861)
                {
                    _8868 = length((r_motion_tp1.Load(int3(int2(floor(_5801 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9062_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5803) < (0.20000000298023223876953125f * _8847);
                }
                else
                {
                    _8868 = _8861;
                }
                _19916 = _8868;
                break;
            } while(false);
            float2 _5813 = _5545 + float2(_5795, _5799);
            bool _19923;
            do
            {
                bool _9148 = all(bool2(_5813.x > 0.0f.xx.x, _5813.y > 0.0f.xx.y));
                bool _9154;
                if (_9148)
                {
                    _9154 = all(bool2(_5813.x < 1.0f.xx.x, _5813.y < 1.0f.xx.y));
                }
                else
                {
                    _9154 = _9148;
                }
                if (!_9154)
                {
                    _19923 = false;
                    break;
                }
                uint _9161_dummy_parameter;
                float4x4 _19921;
                do
                {
                    float4x4 _9175;
                    bool _19920;
                    do
                    {
                        _9175 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19920 = false;
                            break;
                        }
                        uint _9209 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9209 + 32u) * 4 + 0) != 1u)
                        {
                            _19920 = false;
                            break;
                        }
                        uint _19917;
                        _19917 = 0u;
                        for (; _19917 < 4u; _19917++)
                        {
                            for (uint _19918 = 0u; _19918 < 4u; )
                            {
                                _9175[_19917][_19918] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9209 + (_19917 * 4u)) + _19918) * 4 + 0));
                                _19918++;
                                continue;
                            }
                        }
                        _19920 = true;
                        break;
                    } while(false);
                    if (_19920)
                    {
                        _19921 = _9175;
                        break;
                    }
                    _19921 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19922;
                do
                {
                    float _9286 = _5813.x;
                    float _9289 = 1.0f - _5813.y;
                    float4 _9300 = mul(float4((float2(_9286, _9289) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5813 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9161_dummy_parameter))))), 0)).x, 1.0f), _19921);
                    float _9302 = _9300.w;
                    if (!(_9302 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19922 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9315 = ((_9300.xy / _9302.xx) + 1.0f.xx) * 0.5f;
                    _19922 = float2(_9315.x - _9286, _9289 - _9315.y);
                    break;
                } while(false);
                float2 _9112 = abs(_19922);
                if (any(bool2(_9112.x > 100000.0f.xx.x, _9112.y > 100000.0f.xx.y)))
                {
                    _19923 = false;
                    break;
                }
                float _9120 = length(_19922 * _5803);
                uint _9335_dummy_parameter;
                bool _9134 = _9120 > ((8.0f * _5803.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9141;
                if (_9134)
                {
                    _9141 = length((r_motion_tp1.Load(int3(int2(floor(_5813 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9335_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5803) < (0.20000000298023223876953125f * _9120);
                }
                else
                {
                    _9141 = _9134;
                }
                _19923 = _9141;
                break;
            } while(false);
            float2 _5826 = _5545 + float2(_5796, _5798);
            bool _19930;
            do
            {
                bool _9421 = all(bool2(_5826.x > 0.0f.xx.x, _5826.y > 0.0f.xx.y));
                bool _9427;
                if (_9421)
                {
                    _9427 = all(bool2(_5826.x < 1.0f.xx.x, _5826.y < 1.0f.xx.y));
                }
                else
                {
                    _9427 = _9421;
                }
                if (!_9427)
                {
                    _19930 = false;
                    break;
                }
                uint _9434_dummy_parameter;
                float4x4 _19928;
                do
                {
                    float4x4 _9448;
                    bool _19927;
                    do
                    {
                        _9448 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19927 = false;
                            break;
                        }
                        uint _9482 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9482 + 32u) * 4 + 0) != 1u)
                        {
                            _19927 = false;
                            break;
                        }
                        uint _19924;
                        _19924 = 0u;
                        for (; _19924 < 4u; _19924++)
                        {
                            for (uint _19925 = 0u; _19925 < 4u; )
                            {
                                _9448[_19924][_19925] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9482 + (_19924 * 4u)) + _19925) * 4 + 0));
                                _19925++;
                                continue;
                            }
                        }
                        _19927 = true;
                        break;
                    } while(false);
                    if (_19927)
                    {
                        _19928 = _9448;
                        break;
                    }
                    _19928 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19929;
                do
                {
                    float _9559 = _5826.x;
                    float _9562 = 1.0f - _5826.y;
                    float4 _9573 = mul(float4((float2(_9559, _9562) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5826 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9434_dummy_parameter))))), 0)).x, 1.0f), _19928);
                    float _9575 = _9573.w;
                    if (!(_9575 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19929 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9588 = ((_9573.xy / _9575.xx) + 1.0f.xx) * 0.5f;
                    _19929 = float2(_9588.x - _9559, _9562 - _9588.y);
                    break;
                } while(false);
                float2 _9385 = abs(_19929);
                if (any(bool2(_9385.x > 100000.0f.xx.x, _9385.y > 100000.0f.xx.y)))
                {
                    _19930 = false;
                    break;
                }
                float _9393 = length(_19929 * _5803);
                uint _9608_dummy_parameter;
                bool _9407 = _9393 > ((8.0f * _5803.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9414;
                if (_9407)
                {
                    _9414 = length((r_motion_tp1.Load(int3(int2(floor(_5826 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9608_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5803) < (0.20000000298023223876953125f * _9393);
                }
                else
                {
                    _9414 = _9407;
                }
                _19930 = _9414;
                break;
            } while(false);
            float2 _5838 = _5545 + _5792;
            bool _19937;
            do
            {
                bool _9694 = all(bool2(_5838.x > 0.0f.xx.x, _5838.y > 0.0f.xx.y));
                bool _9700;
                if (_9694)
                {
                    _9700 = all(bool2(_5838.x < 1.0f.xx.x, _5838.y < 1.0f.xx.y));
                }
                else
                {
                    _9700 = _9694;
                }
                if (!_9700)
                {
                    _19937 = false;
                    break;
                }
                uint _9707_dummy_parameter;
                float4x4 _19935;
                do
                {
                    float4x4 _9721;
                    bool _19934;
                    do
                    {
                        _9721 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19934 = false;
                            break;
                        }
                        uint _9755 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9755 + 32u) * 4 + 0) != 1u)
                        {
                            _19934 = false;
                            break;
                        }
                        uint _19931;
                        _19931 = 0u;
                        for (; _19931 < 4u; _19931++)
                        {
                            for (uint _19932 = 0u; _19932 < 4u; )
                            {
                                _9721[_19931][_19932] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9755 + (_19931 * 4u)) + _19932) * 4 + 0));
                                _19932++;
                                continue;
                            }
                        }
                        _19934 = true;
                        break;
                    } while(false);
                    if (_19934)
                    {
                        _19935 = _9721;
                        break;
                    }
                    _19935 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19936;
                do
                {
                    float _9832 = _5838.x;
                    float _9835 = 1.0f - _5838.y;
                    float4 _9846 = mul(float4((float2(_9832, _9835) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5838 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9707_dummy_parameter))))), 0)).x, 1.0f), _19935);
                    float _9848 = _9846.w;
                    if (!(_9848 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19936 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9861 = ((_9846.xy / _9848.xx) + 1.0f.xx) * 0.5f;
                    _19936 = float2(_9861.x - _9832, _9835 - _9861.y);
                    break;
                } while(false);
                float2 _9658 = abs(_19936);
                if (any(bool2(_9658.x > 100000.0f.xx.x, _9658.y > 100000.0f.xx.y)))
                {
                    _19937 = false;
                    break;
                }
                float _9666 = length(_19936 * _5803);
                uint _9881_dummy_parameter;
                bool _9680 = _9666 > ((8.0f * _5803.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9687;
                if (_9680)
                {
                    _9687 = length((r_motion_tp1.Load(int3(int2(floor(_5838 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9881_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5803) < (0.20000000298023223876953125f * _9666);
                }
                else
                {
                    _9687 = _9680;
                }
                _19937 = _9687;
                break;
            } while(false);
            float _5844 = 0.25f * (((float(_19916) + float(_19923)) + float(_19930)) + float(_19937));
            float4 _20107;
            if (_5844 < 1.0f)
            {
                bool _19944;
                do
                {
                    bool _9967 = all(bool2(_19895.x > 0.0f.xx.x, _19895.y > 0.0f.xx.y));
                    bool _9973;
                    if (_9967)
                    {
                        _9973 = all(bool2(_19895.x < 1.0f.xx.x, _19895.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9973 = _9967;
                    }
                    if (!_9973)
                    {
                        _19944 = false;
                        break;
                    }
                    uint _9980_dummy_parameter;
                    float4x4 _19942;
                    do
                    {
                        float4x4 _9994;
                        bool _19941;
                        do
                        {
                            _9994 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19941 = false;
                                break;
                            }
                            uint _10028 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10028 + 32u) * 4 + 0) != 1u)
                            {
                                _19941 = false;
                                break;
                            }
                            uint _19938;
                            _19938 = 0u;
                            for (; _19938 < 4u; _19938++)
                            {
                                for (uint _19939 = 0u; _19939 < 4u; )
                                {
                                    _9994[_19938][_19939] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10028 + (_19938 * 4u)) + _19939) * 4 + 0));
                                    _19939++;
                                    continue;
                                }
                            }
                            _19941 = true;
                            break;
                        } while(false);
                        if (_19941)
                        {
                            _19942 = _9994;
                            break;
                        }
                        _19942 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19943;
                    do
                    {
                        float _10108 = 1.0f - _19895.y;
                        float4 _10119 = mul(float4((float2(_19895.x, _10108) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19895 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9980_dummy_parameter))))), 0)).x, 1.0f), _19942);
                        float _10121 = _10119.w;
                        if (!(_10121 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19943 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10134 = ((_10119.xy / _10121.xx) + 1.0f.xx) * 0.5f;
                        _19943 = float2(_10134.x - _19895.x, _10108 - _10134.y);
                        break;
                    } while(false);
                    float2 _9931 = abs(_19943);
                    if (any(bool2(_9931.x > 100000.0f.xx.x, _9931.y > 100000.0f.xx.y)))
                    {
                        _19944 = false;
                        break;
                    }
                    float _9939 = length(_19943 * _5803);
                    uint _10154_dummy_parameter;
                    bool _9953 = _9939 > ((8.0f * _5803.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9960;
                    if (_9953)
                    {
                        _9960 = length((r_motion_tp1.Load(int3(int2(floor(_19895 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10154_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5803) < (0.20000000298023223876953125f * _9939);
                    }
                    else
                    {
                        _9960 = _9953;
                    }
                    _19944 = _9960;
                    break;
                } while(false);
                bool _19951;
                do
                {
                    bool _10240 = all(bool2(_19897.x > 0.0f.xx.x, _19897.y > 0.0f.xx.y));
                    bool _10246;
                    if (_10240)
                    {
                        _10246 = all(bool2(_19897.x < 1.0f.xx.x, _19897.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10246 = _10240;
                    }
                    if (!_10246)
                    {
                        _19951 = false;
                        break;
                    }
                    uint _10253_dummy_parameter;
                    float4x4 _19949;
                    do
                    {
                        float4x4 _10267;
                        bool _19948;
                        do
                        {
                            _10267 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19948 = false;
                                break;
                            }
                            uint _10301 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10301 + 32u) * 4 + 0) != 1u)
                            {
                                _19948 = false;
                                break;
                            }
                            uint _19945;
                            _19945 = 0u;
                            for (; _19945 < 4u; _19945++)
                            {
                                for (uint _19946 = 0u; _19946 < 4u; )
                                {
                                    _10267[_19945][_19946] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10301 + (_19945 * 4u)) + _19946) * 4 + 0));
                                    _19946++;
                                    continue;
                                }
                            }
                            _19948 = true;
                            break;
                        } while(false);
                        if (_19948)
                        {
                            _19949 = _10267;
                            break;
                        }
                        _19949 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19950;
                    do
                    {
                        float _10381 = 1.0f - _19897.y;
                        float4 _10392 = mul(float4((float2(_19897.x, _10381) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19897 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10253_dummy_parameter))))), 0)).x, 1.0f), _19949);
                        float _10394 = _10392.w;
                        if (!(_10394 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19950 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10407 = ((_10392.xy / _10394.xx) + 1.0f.xx) * 0.5f;
                        _19950 = float2(_10407.x - _19897.x, _10381 - _10407.y);
                        break;
                    } while(false);
                    float2 _10204 = abs(_19950);
                    if (any(bool2(_10204.x > 100000.0f.xx.x, _10204.y > 100000.0f.xx.y)))
                    {
                        _19951 = false;
                        break;
                    }
                    float _10212 = length(_19950 * _5803);
                    uint _10427_dummy_parameter;
                    bool _10226 = _10212 > ((8.0f * _5803.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10233;
                    if (_10226)
                    {
                        _10233 = length((r_motion_tp1.Load(int3(int2(floor(_19897 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10427_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5803) < (0.20000000298023223876953125f * _10212);
                    }
                    else
                    {
                        _10233 = _10226;
                    }
                    _19951 = _10233;
                    break;
                } while(false);
                bool _19958;
                do
                {
                    bool _10513 = all(bool2(_19898.x > 0.0f.xx.x, _19898.y > 0.0f.xx.y));
                    bool _10519;
                    if (_10513)
                    {
                        _10519 = all(bool2(_19898.x < 1.0f.xx.x, _19898.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10519 = _10513;
                    }
                    if (!_10519)
                    {
                        _19958 = false;
                        break;
                    }
                    uint _10526_dummy_parameter;
                    float4x4 _19956;
                    do
                    {
                        float4x4 _10540;
                        bool _19955;
                        do
                        {
                            _10540 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19955 = false;
                                break;
                            }
                            uint _10574 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10574 + 32u) * 4 + 0) != 1u)
                            {
                                _19955 = false;
                                break;
                            }
                            uint _19952;
                            _19952 = 0u;
                            for (; _19952 < 4u; _19952++)
                            {
                                for (uint _19953 = 0u; _19953 < 4u; )
                                {
                                    _10540[_19952][_19953] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10574 + (_19952 * 4u)) + _19953) * 4 + 0));
                                    _19953++;
                                    continue;
                                }
                            }
                            _19955 = true;
                            break;
                        } while(false);
                        if (_19955)
                        {
                            _19956 = _10540;
                            break;
                        }
                        _19956 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19957;
                    do
                    {
                        float _10654 = 1.0f - _19898.y;
                        float4 _10665 = mul(float4((float2(_19898.x, _10654) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19898 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10526_dummy_parameter))))), 0)).x, 1.0f), _19956);
                        float _10667 = _10665.w;
                        if (!(_10667 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19957 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10680 = ((_10665.xy / _10667.xx) + 1.0f.xx) * 0.5f;
                        _19957 = float2(_10680.x - _19898.x, _10654 - _10680.y);
                        break;
                    } while(false);
                    float2 _10477 = abs(_19957);
                    if (any(bool2(_10477.x > 100000.0f.xx.x, _10477.y > 100000.0f.xx.y)))
                    {
                        _19958 = false;
                        break;
                    }
                    float _10485 = length(_19957 * _5803);
                    uint _10700_dummy_parameter;
                    bool _10499 = _10485 > ((8.0f * _5803.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10506;
                    if (_10499)
                    {
                        _10506 = length((r_motion_tp1.Load(int3(int2(floor(_19898 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10700_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5803) < (0.20000000298023223876953125f * _10485);
                    }
                    else
                    {
                        _10506 = _10499;
                    }
                    _19958 = _10506;
                    break;
                } while(false);
                bool _19965;
                do
                {
                    bool _10786 = all(bool2(_19899.x > 0.0f.xx.x, _19899.y > 0.0f.xx.y));
                    bool _10792;
                    if (_10786)
                    {
                        _10792 = all(bool2(_19899.x < 1.0f.xx.x, _19899.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10792 = _10786;
                    }
                    if (!_10792)
                    {
                        _19965 = false;
                        break;
                    }
                    uint _10799_dummy_parameter;
                    float4x4 _19963;
                    do
                    {
                        float4x4 _10813;
                        bool _19962;
                        do
                        {
                            _10813 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19962 = false;
                                break;
                            }
                            uint _10847 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10847 + 32u) * 4 + 0) != 1u)
                            {
                                _19962 = false;
                                break;
                            }
                            uint _19959;
                            _19959 = 0u;
                            for (; _19959 < 4u; _19959++)
                            {
                                for (uint _19960 = 0u; _19960 < 4u; )
                                {
                                    _10813[_19959][_19960] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10847 + (_19959 * 4u)) + _19960) * 4 + 0));
                                    _19960++;
                                    continue;
                                }
                            }
                            _19962 = true;
                            break;
                        } while(false);
                        if (_19962)
                        {
                            _19963 = _10813;
                            break;
                        }
                        _19963 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19964;
                    do
                    {
                        float _10927 = 1.0f - _19899.y;
                        float4 _10938 = mul(float4((float2(_19899.x, _10927) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19899 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10799_dummy_parameter))))), 0)).x, 1.0f), _19963);
                        float _10940 = _10938.w;
                        if (!(_10940 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19964 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10953 = ((_10938.xy / _10940.xx) + 1.0f.xx) * 0.5f;
                        _19964 = float2(_10953.x - _19899.x, _10927 - _10953.y);
                        break;
                    } while(false);
                    float2 _10750 = abs(_19964);
                    if (any(bool2(_10750.x > 100000.0f.xx.x, _10750.y > 100000.0f.xx.y)))
                    {
                        _19965 = false;
                        break;
                    }
                    float _10758 = length(_19964 * _5803);
                    uint _10973_dummy_parameter;
                    bool _10772 = _10758 > ((8.0f * _5803.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10779;
                    if (_10772)
                    {
                        _10779 = length((r_motion_tp1.Load(int3(int2(floor(_19899 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10973_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5803) < (0.20000000298023223876953125f * _10758);
                    }
                    else
                    {
                        _10779 = _10772;
                    }
                    _19965 = _10779;
                    break;
                } while(false);
                float4 _5871 = _8795 * float4(_19944 ? 0.0f : 1.0f, _19951 ? 0.0f : 1.0f, _19958 ? 0.0f : 1.0f, _19965 ? 0.0f : 1.0f);
                float _5873 = dot(_5871, 1.0f.xxxx);
                float4 _20108;
                if (_5873 > 0.001000000047497451305389404296875f)
                {
                    _20108 = _5871 / _5873.xxxx;
                }
                else
                {
                    _20108 = _8795;
                }
                _20107 = _20108;
            }
            else
            {
                _20107 = _8795;
            }
            _21414 = _5844;
            _20106 = _20107;
        }
        else
        {
            _21414 = 0.0f;
            _20106 = _8795;
        }
        bool _5890 = _5582 && (!_20035);
        bool _5899;
        if (_5890)
        {
            _5899 = (_20106.z + _20106.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5899 = _5890;
        }
        bool _5910;
        if (_5899)
        {
            _5910 = length((_19898 - _19895) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5910 = _5899;
        }
        bool _20195;
        if (_5910)
        {
            uint4 _11002 = r_warped_motion_qdata_tp1.Load(int3(_20116, 0));
            uint _11003 = _11002.x;
            bool _20198;
            if (_11003 != 0u)
            {
                float _20184;
                if (_11003 == 0u)
                {
                    _20184 = -1.0f;
                }
                else
                {
                    _20184 = float((_11003 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5920 = _20184 - 0.12000000476837158203125f;
                bool _11022 = all(bool2(_19898.x > 0.0f.xx.x, _19898.y > 0.0f.xx.y));
                bool _11028;
                if (_11022)
                {
                    _11028 = all(bool2(_19898.x < 1.0f.xx.x, _19898.y < 1.0f.xx.y));
                }
                else
                {
                    _11028 = _11022;
                }
                bool _5930;
                if (_11028)
                {
                    uint _11035_dummy_parameter;
                    _5930 = (log(((r_depth_tm1.Load(int3(int2(floor(_19898 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11035_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5920;
                }
                else
                {
                    _5930 = _11028;
                }
                bool _5944;
                if (!_5930)
                {
                    bool _11065 = all(bool2(_19899.x > 0.0f.xx.x, _19899.y > 0.0f.xx.y));
                    bool _11071;
                    if (_11065)
                    {
                        _11071 = all(bool2(_19899.x < 1.0f.xx.x, _19899.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11071 = _11065;
                    }
                    bool _5942;
                    if (_11071)
                    {
                        uint _11078_dummy_parameter;
                        _5942 = (log(((r_depth_tp1.Load(int3(int2(floor(_19899 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11078_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5920;
                    }
                    else
                    {
                        _5942 = _11071;
                    }
                    _5944 = _5942;
                }
                else
                {
                    _5944 = _5930;
                }
                _20198 = _5944;
            }
            else
            {
                _20198 = false;
            }
            _20195 = _20198;
        }
        else
        {
            _20195 = false;
        }
        bool _5949 = _20035 || _20195;
        bool _5954;
        if (_5949)
        {
            bool _11108 = all(bool2(_19895.x > 0.0f.xx.x, _19895.y > 0.0f.xx.y));
            bool _11114;
            if (_11108)
            {
                _11114 = all(bool2(_19895.x < 1.0f.xx.x, _19895.y < 1.0f.xx.y));
            }
            else
            {
                _11114 = _11108;
            }
            _5954 = _11114;
        }
        else
        {
            _5954 = _5949;
        }
        bool _5959;
        if (_5954)
        {
            bool _11119 = all(bool2(_19897.x > 0.0f.xx.x, _19897.y > 0.0f.xx.y));
            bool _11125;
            if (_11119)
            {
                _11125 = all(bool2(_19897.x < 1.0f.xx.x, _19897.y < 1.0f.xx.y));
            }
            else
            {
                _11125 = _11119;
            }
            _5959 = _11125;
        }
        else
        {
            _5959 = _5954;
        }
        float4 _20318;
        if (_5959)
        {
            float _5965 = _20106.x + _20106.y;
            float _5970 = _20106.z + _20106.w;
            float _20213;
            if (_5965 > 0.001000000047497451305389404296875f)
            {
                _20213 = _20106.x / _5965;
            }
            else
            {
                _20213 = _5770;
            }
            _20318 = float4(_20106.x + (_5970 * _20213), _20106.y + (_5970 * (1.0f - _20213)), 0.0f, 0.0f);
        }
        else
        {
            _20318 = _20106;
        }
        bool _11153 = (cbFI_pad0 & 1024u) != 0u;
        bool _11129 = !_11153;
        bool _11130 = !_11129;
        bool _11147;
        if (_11130)
        {
            _11147 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_20116.y * cbFI_MvDepthLaneSize.x) + _20116.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11147 = _11129;
        }
        bool _11179;
        if (_11130)
        {
            _11179 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5561.y * cbFI_FlowLaneSize.x) + _5561.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11179 = _11129;
        }
        float _6005 = float(_11179);
        bool _20339;
        float4 _20378;
        float3 _22325;
        if (_11153)
        {
            bool _6015;
            if (_11147)
            {
                _6015 = all(bool2(_19895.x > 0.0f.xx.x, _19895.y > 0.0f.xx.y));
            }
            else
            {
                _6015 = _11147;
            }
            bool _6021;
            if (_6015)
            {
                _6021 = all(bool2(_19895.x < 1.0f.xx.x, _19895.y < 1.0f.xx.y));
            }
            else
            {
                _6021 = _6015;
            }
            bool _6028;
            if (_11147)
            {
                _6028 = all(bool2(_19897.x > 0.0f.xx.x, _19897.y > 0.0f.xx.y));
            }
            else
            {
                _6028 = _11147;
            }
            bool _6034;
            if (_6028)
            {
                _6034 = all(bool2(_19897.x < 1.0f.xx.x, _19897.y < 1.0f.xx.y));
            }
            else
            {
                _6034 = _6028;
            }
            bool _6041;
            if (_11179)
            {
                _6041 = all(bool2(_19898.x > 0.0f.xx.x, _19898.y > 0.0f.xx.y));
            }
            else
            {
                _6041 = _11179;
            }
            bool _6047;
            if (_6041)
            {
                _6047 = all(bool2(_19898.x < 1.0f.xx.x, _19898.y < 1.0f.xx.y));
            }
            else
            {
                _6047 = _6041;
            }
            bool _6054;
            if (_11179)
            {
                _6054 = all(bool2(_19899.x > 0.0f.xx.x, _19899.y > 0.0f.xx.y));
            }
            else
            {
                _6054 = _11179;
            }
            bool _6060;
            if (_6054)
            {
                _6060 = all(bool2(_19899.x < 1.0f.xx.x, _19899.y < 1.0f.xx.y));
            }
            else
            {
                _6060 = _6054;
            }
            bool _6062 = !_11147;
            if (_6062)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11221;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11221);
                }
            }
            bool _6067 = !_11179;
            if (_6067)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11231;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11231);
                }
            }
            if (_11147 && _6067)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11241;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11241);
                }
            }
            if (_6062 && _11179)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11251;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11251);
                }
            }
            float _6086 = float(_6021);
            float _6088 = float(_6034);
            bool _6091 = _6047 && _6060;
            float _20247;
            if (_6091)
            {
                _20247 = 1.0f;
            }
            else
            {
                _20247 = (_6047 || _6060) ? 0.5f : 0.0f;
            }
            bool _20262;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_6021)) && (!_6034))
            {
                bool _6121;
                if (_6091)
                {
                    float _20255;
                    do
                    {
                        bool _11335 = all(bool2(_19898.x > 0.0f.xx.x, _19898.y > 0.0f.xx.y));
                        bool _11341;
                        if (_11335)
                        {
                            _11341 = all(bool2(_19898.x < 1.0f.xx.x, _19898.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11341 = _11335;
                        }
                        bool _11272 = !_11341;
                        bool _11279;
                        if (!_11272)
                        {
                            bool _11346 = all(bool2(_19899.x > 0.0f.xx.x, _19899.y > 0.0f.xx.y));
                            bool _11352;
                            if (_11346)
                            {
                                _11352 = all(bool2(_19899.x < 1.0f.xx.x, _19899.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11352 = _11346;
                            }
                            _11279 = !_11352;
                        }
                        else
                        {
                            _11279 = _11272;
                        }
                        if (_11279)
                        {
                            _20255 = 0.0f;
                            break;
                        }
                        uint _11359_dummy_parameter;
                        uint _11375_dummy_parameter;
                        float4x4 _20254;
                        do
                        {
                            float4x4 _11389;
                            bool _20253;
                            do
                            {
                                _11389 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20253 = false;
                                    break;
                                }
                                uint _11423 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11423 + 32u) * 4 + 0) != 1u)
                                {
                                    _20253 = false;
                                    break;
                                }
                                uint _20250;
                                _20250 = 0u;
                                for (; _20250 < 4u; _20250++)
                                {
                                    for (uint _20251 = 0u; _20251 < 4u; )
                                    {
                                        _11389[_20250][_20251] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11423 + 16u) + (_20250 * 4u)) + _20251) * 4 + 0));
                                        _20251++;
                                        continue;
                                    }
                                }
                                _20253 = true;
                                break;
                            } while(false);
                            if (_20253)
                            {
                                _20254 = _11389;
                                break;
                            }
                            _20254 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11300 = mul(float4((float2(_19898.x, 1.0f - _19898.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19898 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11359_dummy_parameter))))), 0)).x, 1.0f), _20254);
                        float _11302 = _11300.w;
                        if (abs(_11302) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20255 = 0.0f;
                            break;
                        }
                        float _11313 = abs(cbFI_DeviceToViewDepth.y / ((_11300.z / _11302) - cbFI_DeviceToViewDepth.x));
                        float _11316 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19899 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11375_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20255 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11313 - _11316) / max(max(_11313, _11316), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _6121 = _20255 >= 0.5f;
                }
                else
                {
                    _6121 = _6091;
                }
                bool _6129;
                if (_6121)
                {
                    _6129 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _6129 = _6121;
                }
                bool _20263;
                if (_6129)
                {
                    uint _11527_dummy_parameter;
                    float4x4 _20260;
                    do
                    {
                        float4x4 _11541;
                        bool _20259;
                        do
                        {
                            _11541 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20259 = false;
                                break;
                            }
                            uint _11575 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11575 + 32u) * 4 + 0) != 1u)
                            {
                                _20259 = false;
                                break;
                            }
                            uint _20256;
                            _20256 = 0u;
                            for (; _20256 < 4u; _20256++)
                            {
                                for (uint _20257 = 0u; _20257 < 4u; )
                                {
                                    _11541[_20256][_20257] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11575 + 16u) + (_20256 * 4u)) + _20257) * 4 + 0));
                                    _20257++;
                                    continue;
                                }
                            }
                            _20259 = true;
                            break;
                        } while(false);
                        if (_20259)
                        {
                            _20260 = _11541;
                            break;
                        }
                        _20260 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20261;
                    do
                    {
                        float _11655 = 1.0f - _19898.y;
                        float4 _11666 = mul(float4((float2(_19898.x, _11655) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19898 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11527_dummy_parameter))))), 0)).x, 1.0f), _20260);
                        float _11668 = _11666.w;
                        if (!(_11668 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20261 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11681 = ((_11666.xy / _11668.xx) + 1.0f.xx) * 0.5f;
                        _20261 = float2(_11681.x - _19898.x, _11655 - _11681.y);
                        break;
                    } while(false);
                    float2 _6142 = float2(cbFI_DisplaySize);
                    _20263 = length(((_19898 + _20261) - _19899) * _6142) <= ((0.100000001490116119384765625f * length(_20261 * _6142)) + 8.0f);
                }
                else
                {
                    _20263 = _6121;
                }
                _20262 = _20263;
            }
            else
            {
                _20262 = true;
            }
            bool _6156 = !_20262;
            bool _23767 = _6156 ? false : _6060;
            bool _23768 = _6156 ? false : _6047;
            bool _20340;
            float4 _20379;
            if (!(((_6021 && _6034) && _23768) && _23767))
            {
                float4 _6178 = _20318 * float4(_6086, _6088, float(_23768), float(_23767));
                float _6180 = dot(_6178, 1.0f.xxxx);
                bool _6183 = !(_6180 > 0.0f);
                float4 _20380;
                if (!_6183)
                {
                    _20380 = _6178 / _6180.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11703;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11703);
                    }
                    _20380 = 0.0f.xxxx;
                }
                _20379 = _20380;
                _20340 = _6183;
            }
            else
            {
                _20379 = _20318;
                _20340 = false;
            }
            _22325 = float3(_6086, _6088, _20247);
            _20378 = _20379;
            _20339 = _20340;
        }
        else
        {
            _22325 = float3(float(_11147), _6005, 0.0f);
            _20378 = _20318;
            _20339 = false;
        }
        bool _6201 = !_20339;
        float4 _20471;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6201)
        {
            float _6208 = _20378.x + _20378.y;
            float4 _20472;
            if (_6208 > 0.001000000047497451305389404296875f)
            {
                _20472 = float4(_20378.x / _6208, _20378.y / _6208, 0.0f, 0.0f);
            }
            else
            {
                _20472 = float4(_5770, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20471 = _20472;
        }
        else
        {
            _20471 = _20378;
        }
        float4 _20648;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6201) && _11147)
        {
            float _20445;
            do
            {
                uint4 _11843 = r_warped_motion_qdata_tp1.Load(int3(_20116, 0));
                uint _11844 = _11843.x;
                if (_11844 != 0u)
                {
                    float _20444;
                    if (_11844 == 0u)
                    {
                        _20444 = -1.0f;
                    }
                    else
                    {
                        _20444 = float((_11844 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20445 = _20444;
                    break;
                }
                int _20427;
                uint _20428;
                _20428 = _11844;
                _20427 = -1;
                uint _20443;
                for (; _20427 <= 1; _20428 = _20443, _20427++)
                {
                    _20443 = _20428;
                    for (int _20441 = -1; _20441 <= 1; )
                    {
                        _20443 = max(_20443, r_warped_motion_qdata_tp1.Load(int3(clamp(_20116 + int2(_20441, _20427), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20441++;
                        continue;
                    }
                }
                if (_20428 != 0u)
                {
                    float _20440;
                    if (_20428 == 0u)
                    {
                        _20440 = -1.0f;
                    }
                    else
                    {
                        _20440 = float((_20428 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20445 = _20440;
                    break;
                }
                uint _20430;
                _20430 = 4294967295u;
                uint _23660;
                for (int _20429 = 0; _20429 < 8; _20430 = _23660, _20429++)
                {
                    int _20433 = 0;
                    for (;;)
                    {
                        if (_20433 < 5)
                        {
                            int2 _11794 = _20116 + (_1243[_20429] * _1252[_20433].xx);
                            bool _11797 = any(bool2(_11794.x < int2(0, 0).x, _11794.y < int2(0, 0).y));
                            bool _11805;
                            if (!_11797)
                            {
                                _11805 = any(bool2(_11794.x >= cbFI_MvDepthLaneSize.x, _11794.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11805 = _11797;
                            }
                            if (_11805)
                            {
                                _23660 = _20430;
                                break;
                            }
                            uint4 _11883 = r_warped_motion_qdata_tp1.Load(int3(_11794, 0));
                            uint _11884 = _11883.x;
                            if (_11884 != 0u)
                            {
                                _23660 = min(_20430, _11884);
                                break;
                            }
                            _20433++;
                            continue;
                        }
                        else
                        {
                            _23660 = _20430;
                            break;
                        }
                    }
                }
                float _20432;
                if (_20430 == 4294967295u)
                {
                    _20432 = -1.0f;
                }
                else
                {
                    float _20431;
                    if (_20430 == 0u)
                    {
                        _20431 = -1.0f;
                    }
                    else
                    {
                        _20431 = float((_20430 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20432 = _20431;
                }
                _20445 = _20432;
                break;
            } while(false);
            float _6244 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6247 = r_warped_motion_qdata_tp1.Load(int3(_20116, 0)).x == 0u;
            bool _6253;
            if (_6247)
            {
                bool _11909 = all(bool2(_19895.x > 0.0f.xx.x, _19895.y > 0.0f.xx.y));
                bool _11915;
                if (_11909)
                {
                    _11915 = all(bool2(_19895.x < 1.0f.xx.x, _19895.y < 1.0f.xx.y));
                }
                else
                {
                    _11915 = _11909;
                }
                _6253 = _11915;
            }
            else
            {
                _6253 = _6247;
            }
            bool _6258;
            if (_6253)
            {
                bool _11920 = all(bool2(_19897.x > 0.0f.xx.x, _19897.y > 0.0f.xx.y));
                bool _11926;
                if (_11920)
                {
                    _11926 = all(bool2(_19897.x < 1.0f.xx.x, _19897.y < 1.0f.xx.y));
                }
                else
                {
                    _11926 = _11920;
                }
                _6258 = _11926;
            }
            else
            {
                _6258 = _6253;
            }
            bool _20457;
            float4 _20466;
            if (_6258)
            {
                uint _11933_dummy_parameter;
                float _11957 = log(((r_depth_tm1.Load(int3(int2(floor(_19895 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11933_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _11965_dummy_parameter;
                float _11989 = log(((r_depth_tp1.Load(int3(int2(floor(_19897 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11965_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _6269 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6276;
                if (_6269)
                {
                    _6276 = _11989 > (_11957 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6276 = _6269;
                }
                bool _20462;
                float4 _20484;
                if (_6276)
                {
                    _20484 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20462 = true;
                }
                else
                {
                    bool _6282 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6289;
                    if (_6282)
                    {
                        _6289 = _11957 > (_11989 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6289 = _6282;
                    }
                    bool4 _23769 = _6289.xxxx;
                    _20484 = float4(_23769.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20471.x, _23769.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20471.y, _23769.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20471.z, _23769.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20471.w);
                    _20462 = _6289 ? true : false;
                }
                _20466 = _20484;
                _20457 = _20462;
            }
            else
            {
                _20466 = _20471;
                _20457 = false;
            }
            float4 _20539;
            if (_20457)
            {
                _20539 = 1.0f.xxxx;
            }
            else
            {
                bool _6300 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6306;
                if (_6300)
                {
                    _6306 = _20466.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6306 = _6300;
                }
                bool _6311;
                if (_6306)
                {
                    bool _11995 = all(bool2(_19897.x > 0.0f.xx.x, _19897.y > 0.0f.xx.y));
                    bool _12001;
                    if (_11995)
                    {
                        _12001 = all(bool2(_19897.x < 1.0f.xx.x, _19897.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12001 = _11995;
                    }
                    _6311 = _12001;
                }
                else
                {
                    _6311 = _6306;
                }
                float4 _20540;
                if (_6311)
                {
                    float _20493;
                    if (_20445 >= 0.0f)
                    {
                        _20493 = _20445 - _6244;
                    }
                    else
                    {
                        float _20489;
                        _20489 = 2.0f;
                        float _12058;
                        for (int _20488 = 0; _20488 < 24; _20489 = _12058, _20488++)
                        {
                            float _12022 = float(_20488 & 7) * 0.785398185253143310546875f;
                            int _12024 = _20488 >> 3;
                            int _20490;
                            if (_12024 == 0)
                            {
                                _20490 = 16;
                            }
                            else
                            {
                                _20490 = (_12024 == 1) ? 48 : 96;
                            }
                            uint _12090_dummy_parameter;
                            _12058 = min(_20489, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19897 + ((cbFI_MvDepthLaneSizeRcp * float(_20490)) * float2(cos(_12022), sin(_12022))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12090_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20493 = _20489;
                    }
                    uint _12122_dummy_parameter;
                    float4 _20541;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_19897 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12122_dummy_parameter))))), 0)).x) > ((exp((_20493 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20541 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20541 = 1.0f.xxxx;
                    }
                    _20540 = _20541;
                }
                else
                {
                    _20540 = 1.0f.xxxx;
                }
                _20539 = _20540;
            }
            bool _6339 = _20445 >= 0.0f;
            bool _6340 = (!_20457) && _6339;
            bool _6347;
            if (_6340)
            {
                _6347 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6347 = _6340;
            }
            bool _6353;
            if (_6347)
            {
                _6353 = _20466.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6353 = _6347;
            }
            bool _6358;
            if (_6353)
            {
                bool _12147 = all(bool2(_19895.x > 0.0f.xx.x, _19895.y > 0.0f.xx.y));
                bool _12153;
                if (_12147)
                {
                    _12153 = all(bool2(_19895.x < 1.0f.xx.x, _19895.y < 1.0f.xx.y));
                }
                else
                {
                    _12153 = _12147;
                }
                _6358 = _12153;
            }
            else
            {
                _6358 = _6353;
            }
            float4 _20564;
            if (_6358)
            {
                float _20533;
                if (_6339)
                {
                    _20533 = _20445 - _6244;
                }
                else
                {
                    float _20529;
                    _20529 = 2.0f;
                    float _12210;
                    for (int _20528 = 0; _20528 < 24; _20529 = _12210, _20528++)
                    {
                        float _12174 = float(_20528 & 7) * 0.785398185253143310546875f;
                        int _12176 = _20528 >> 3;
                        int _20530;
                        if (_12176 == 0)
                        {
                            _20530 = 16;
                        }
                        else
                        {
                            _20530 = (_12176 == 1) ? 48 : 96;
                        }
                        uint _12226_dummy_parameter;
                        _12210 = min(_20529, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19895 + ((cbFI_MvDepthLaneSizeRcp * float(_20530)) * float2(cos(_12174), sin(_12174))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12226_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20533 = _20529;
                }
                uint _12274_dummy_parameter;
                float4 _20565;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_19895 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12274_dummy_parameter))))), 0)).x) > ((exp((_20533 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19561 = _20539;
                    _19561.x = 0.0f;
                    _20565 = _19561;
                }
                else
                {
                    _20565 = _20539;
                }
                _20564 = _20565;
            }
            else
            {
                _20564 = _20539;
            }
            float4 _20577;
            if (_6340)
            {
                float _12301 = (exp(((_20445 - _6244) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6396 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6402;
                if (_6396)
                {
                    _6402 = _20466.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6402 = _6396;
                }
                bool _6407;
                if (_6402)
                {
                    bool _12306 = all(bool2(_19899.x > 0.0f.xx.x, _19899.y > 0.0f.xx.y));
                    bool _12312;
                    if (_12306)
                    {
                        _12312 = all(bool2(_19899.x < 1.0f.xx.x, _19899.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12312 = _12306;
                    }
                    _6407 = _12312;
                }
                else
                {
                    _6407 = _6402;
                }
                bool _6415;
                if (_6407)
                {
                    uint _12319_dummy_parameter;
                    _6415 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19899 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12319_dummy_parameter))))), 0)).x) > _12301;
                }
                else
                {
                    _6415 = _6407;
                }
                float4 _20575;
                if (_6415)
                {
                    float4 _19564 = _20564;
                    _19564.w = 0.0f;
                    _20575 = _19564;
                }
                else
                {
                    _20575 = _20564;
                }
                bool _6422 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6428;
                if (_6422)
                {
                    _6428 = _20466.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6428 = _6422;
                }
                bool _6433;
                if (_6428)
                {
                    bool _12337 = all(bool2(_19898.x > 0.0f.xx.x, _19898.y > 0.0f.xx.y));
                    bool _12343;
                    if (_12337)
                    {
                        _12343 = all(bool2(_19898.x < 1.0f.xx.x, _19898.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12343 = _12337;
                    }
                    _6433 = _12343;
                }
                else
                {
                    _6433 = _6428;
                }
                bool _6441;
                if (_6433)
                {
                    uint _12350_dummy_parameter;
                    _6441 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19898 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12350_dummy_parameter))))), 0)).x) > _12301;
                }
                else
                {
                    _6441 = _6433;
                }
                float4 _20578;
                if (_6441)
                {
                    float4 _19567 = _20575;
                    _19567.z = 0.0f;
                    _20578 = _19567;
                }
                else
                {
                    _20578 = _20575;
                }
                _20577 = _20578;
            }
            else
            {
                _20577 = _20564;
            }
            float4 _20649;
            if (any(bool4(_20577.x < 1.0f.xxxx.x, _20577.y < 1.0f.xxxx.y, _20577.z < 1.0f.xxxx.z, _20577.w < 1.0f.xxxx.w)))
            {
                float4 _6452 = _20466 * _20577;
                float _6454 = dot(_6452, 1.0f.xxxx);
                float4 _20650;
                if (_6454 > 0.0f)
                {
                    _20650 = _6452 / _6454.xxxx;
                }
                else
                {
                    bool _6465 = _20577.y == 0.0f;
                    bool _6471;
                    if (_6465)
                    {
                        _6471 = _20577.x > 0.0f;
                    }
                    else
                    {
                        _6471 = _6465;
                    }
                    bool _6476;
                    if (_6471)
                    {
                        bool _12368 = all(bool2(_19895.x > 0.0f.xx.x, _19895.y > 0.0f.xx.y));
                        bool _12374;
                        if (_12368)
                        {
                            _12374 = all(bool2(_19895.x < 1.0f.xx.x, _19895.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12374 = _12368;
                        }
                        _6476 = _12374;
                    }
                    else
                    {
                        _6476 = _6471;
                    }
                    float4 _20651;
                    if (_6476)
                    {
                        _20651 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6481 = _20577.x == 0.0f;
                        bool _6487;
                        if (_6481)
                        {
                            _6487 = _20577.y > 0.0f;
                        }
                        else
                        {
                            _6487 = _6481;
                        }
                        bool _6492;
                        if (_6487)
                        {
                            bool _12379 = all(bool2(_19897.x > 0.0f.xx.x, _19897.y > 0.0f.xx.y));
                            bool _12385;
                            if (_12379)
                            {
                                _12385 = all(bool2(_19897.x < 1.0f.xx.x, _19897.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12385 = _12379;
                            }
                            _6492 = _12385;
                        }
                        else
                        {
                            _6492 = _6487;
                        }
                        bool4 _23772 = _6492.xxxx;
                        _20651 = float4(_23772.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20466.x, _23772.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20466.y, _23772.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20466.z, _23772.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20466.w);
                    }
                    _20650 = _20651;
                }
                _20649 = _20650;
            }
            else
            {
                _20649 = _20466;
            }
            _20648 = _20649;
        }
        else
        {
            _20648 = _20471;
        }
        float4 _21378;
        bool _21684;
        float3 _22021;
        if (((cbFI_pad0 & 32768u) != 0u) && _6201)
        {
            bool _6509 = _20648.x > 0.00999999977648258209228515625f;
            bool _6512 = _20648.y > 0.00999999977648258209228515625f;
            bool _6521 = (_20648.z + _20648.w) > 0.0199999995529651641845703125f;
            bool _6527;
            if (_6521)
            {
                bool _12390 = all(bool2(_19898.x > 0.0f.xx.x, _19898.y > 0.0f.xx.y));
                bool _12396;
                if (_12390)
                {
                    _12396 = all(bool2(_19898.x < 1.0f.xx.x, _19898.y < 1.0f.xx.y));
                }
                else
                {
                    _12396 = _12390;
                }
                _6527 = _12396;
            }
            else
            {
                _6527 = _6521;
            }
            bool _6532;
            if (_6527)
            {
                bool _12401 = all(bool2(_19899.x > 0.0f.xx.x, _19899.y > 0.0f.xx.y));
                bool _12407;
                if (_12401)
                {
                    _12407 = all(bool2(_19899.x < 1.0f.xx.x, _19899.y < 1.0f.xx.y));
                }
                else
                {
                    _12407 = _12401;
                }
                _6532 = _12407;
            }
            else
            {
                _6532 = _6527;
            }
            bool _6539;
            if (_6532)
            {
                float _20664;
                do
                {
                    bool _12490 = all(bool2(_19898.x > 0.0f.xx.x, _19898.y > 0.0f.xx.y));
                    bool _12496;
                    if (_12490)
                    {
                        _12496 = all(bool2(_19898.x < 1.0f.xx.x, _19898.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12496 = _12490;
                    }
                    bool _12427 = !_12496;
                    bool _12434;
                    if (!_12427)
                    {
                        bool _12501 = all(bool2(_19899.x > 0.0f.xx.x, _19899.y > 0.0f.xx.y));
                        bool _12507;
                        if (_12501)
                        {
                            _12507 = all(bool2(_19899.x < 1.0f.xx.x, _19899.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12507 = _12501;
                        }
                        _12434 = !_12507;
                    }
                    else
                    {
                        _12434 = _12427;
                    }
                    if (_12434)
                    {
                        _20664 = 0.0f;
                        break;
                    }
                    uint _12514_dummy_parameter;
                    uint _12530_dummy_parameter;
                    float4x4 _20663;
                    do
                    {
                        float4x4 _12544;
                        bool _20662;
                        do
                        {
                            _12544 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20662 = false;
                                break;
                            }
                            uint _12578 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12578 + 32u) * 4 + 0) != 1u)
                            {
                                _20662 = false;
                                break;
                            }
                            uint _20659;
                            _20659 = 0u;
                            for (; _20659 < 4u; _20659++)
                            {
                                for (uint _20660 = 0u; _20660 < 4u; )
                                {
                                    _12544[_20659][_20660] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12578 + 16u) + (_20659 * 4u)) + _20660) * 4 + 0));
                                    _20660++;
                                    continue;
                                }
                            }
                            _20662 = true;
                            break;
                        } while(false);
                        if (_20662)
                        {
                            _20663 = _12544;
                            break;
                        }
                        _20663 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12455 = mul(float4((float2(_19898.x, 1.0f - _19898.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19898 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12514_dummy_parameter))))), 0)).x, 1.0f), _20663);
                    float _12457 = _12455.w;
                    if (abs(_12457) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20664 = 0.0f;
                        break;
                    }
                    float _12468 = abs(cbFI_DeviceToViewDepth.y / ((_12455.z / _12457) - cbFI_DeviceToViewDepth.x));
                    float _12471 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19899 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12530_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20664 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12468 - _12471) / max(max(_12468, _12471), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6539 = _20664 < 0.5f;
            }
            else
            {
                _6539 = _6532;
            }
            float4 _20683;
            if (_6539)
            {
                uint _12682_dummy_parameter;
                uint _12713_dummy_parameter;
                float4 _20684;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19898 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12682_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19899 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12713_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20684 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20684 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20683 = _20684;
            }
            else
            {
                _20683 = 1.0f.xxxx;
            }
            bool _6563;
            if (_11147)
            {
                bool _12742 = all(bool2(_19895.x > 0.0f.xx.x, _19895.y > 0.0f.xx.y));
                bool _12748;
                if (_12742)
                {
                    _12748 = all(bool2(_19895.x < 1.0f.xx.x, _19895.y < 1.0f.xx.y));
                }
                else
                {
                    _12748 = _12742;
                }
                _6563 = _12748;
            }
            else
            {
                _6563 = _11147;
            }
            bool _6569;
            if (_11147)
            {
                bool _12753 = all(bool2(_19897.x > 0.0f.xx.x, _19897.y > 0.0f.xx.y));
                bool _12759;
                if (_12753)
                {
                    _12759 = all(bool2(_19897.x < 1.0f.xx.x, _19897.y < 1.0f.xx.y));
                }
                else
                {
                    _12759 = _12753;
                }
                _6569 = _12759;
            }
            else
            {
                _6569 = _11147;
            }
            bool _6575;
            if (_11179)
            {
                bool _12764 = all(bool2(_19898.x > 0.0f.xx.x, _19898.y > 0.0f.xx.y));
                bool _12770;
                if (_12764)
                {
                    _12770 = all(bool2(_19898.x < 1.0f.xx.x, _19898.y < 1.0f.xx.y));
                }
                else
                {
                    _12770 = _12764;
                }
                _6575 = _12770;
            }
            else
            {
                _6575 = _11179;
            }
            bool _6581;
            if (_11179)
            {
                bool _12775 = all(bool2(_19899.x > 0.0f.xx.x, _19899.y > 0.0f.xx.y));
                bool _12781;
                if (_12775)
                {
                    _12781 = all(bool2(_19899.x < 1.0f.xx.x, _19899.y < 1.0f.xx.y));
                }
                else
                {
                    _12781 = _12775;
                }
                _6581 = _12781;
            }
            else
            {
                _6581 = _11179;
            }
            bool _6584 = _6575 != _6581;
            bool _6590;
            if (_6584)
            {
                _6590 = _6563 || _6569;
            }
            else
            {
                _6590 = _6584;
            }
            float4 _20786;
            if (_6590)
            {
                float4 _19594 = _20683;
                _19594.z = 0.0f;
                _19594.w = 0.0f;
                _20786 = _19594;
            }
            else
            {
                _20786 = _20683;
            }
            bool _6597 = _6563 && _6509;
            bool _6600 = _6569 && _6512;
            float4 _20891;
            float3 _22130;
            if (_6597 || _6600)
            {
                float _20781;
                do
                {
                    uint4 _12920 = r_warped_motion_qdata_tp1.Load(int3(_20116, 0));
                    uint _12921 = _12920.x;
                    if (_12921 != 0u)
                    {
                        float _20780;
                        if (_12921 == 0u)
                        {
                            _20780 = -1.0f;
                        }
                        else
                        {
                            _20780 = float((_12921 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20781 = _20780;
                        break;
                    }
                    int _20763;
                    uint _20764;
                    _20764 = _12921;
                    _20763 = -1;
                    uint _20779;
                    for (; _20763 <= 1; _20764 = _20779, _20763++)
                    {
                        _20779 = _20764;
                        for (int _20777 = -1; _20777 <= 1; )
                        {
                            _20779 = max(_20779, r_warped_motion_qdata_tp1.Load(int3(clamp(_20116 + int2(_20777, _20763), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20777++;
                            continue;
                        }
                    }
                    if (_20764 != 0u)
                    {
                        float _20776;
                        if (_20764 == 0u)
                        {
                            _20776 = -1.0f;
                        }
                        else
                        {
                            _20776 = float((_20764 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20781 = _20776;
                        break;
                    }
                    uint _20766;
                    _20766 = 4294967295u;
                    uint _23661;
                    for (int _20765 = 0; _20765 < 8; _20766 = _23661, _20765++)
                    {
                        int _20769 = 0;
                        for (;;)
                        {
                            if (_20769 < 5)
                            {
                                int2 _12871 = _20116 + (_1243[_20765] * _1252[_20769].xx);
                                bool _12874 = any(bool2(_12871.x < int2(0, 0).x, _12871.y < int2(0, 0).y));
                                bool _12882;
                                if (!_12874)
                                {
                                    _12882 = any(bool2(_12871.x >= cbFI_MvDepthLaneSize.x, _12871.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12882 = _12874;
                                }
                                if (_12882)
                                {
                                    _23661 = _20766;
                                    break;
                                }
                                uint4 _12960 = r_warped_motion_qdata_tp1.Load(int3(_12871, 0));
                                uint _12961 = _12960.x;
                                if (_12961 != 0u)
                                {
                                    _23661 = min(_20766, _12961);
                                    break;
                                }
                                _20769++;
                                continue;
                            }
                            else
                            {
                                _23661 = _20766;
                                break;
                            }
                        }
                    }
                    float _20768;
                    if (_20766 == 4294967295u)
                    {
                        _20768 = -1.0f;
                    }
                    else
                    {
                        float _20767;
                        if (_20766 == 0u)
                        {
                            _20767 = -1.0f;
                        }
                        else
                        {
                            _20767 = float((_20766 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20768 = _20767;
                    }
                    _20781 = _20768;
                    break;
                } while(false);
                bool _6608 = _20781 < 0.0f;
                float _20782;
                if (_6608)
                {
                    _20782 = 0.0f;
                }
                else
                {
                    _20782 = _20781 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12982_dummy_parameter;
                uint _13014_dummy_parameter;
                float4 _20819;
                if ((_6608 && _6597) && _6600)
                {
                    uint _13046_dummy_parameter;
                    float _13070 = log(((r_depth_tm1.Load(int3(int2(floor(_19895 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13046_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _13078_dummy_parameter;
                    float _13102 = log(((r_depth_tp1.Load(int3(int2(floor(_19897 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13078_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20820;
                    if (_13070 > (_13102 + 0.07999999821186065673828125f))
                    {
                        float4 _19598 = _20786;
                        _19598.x = 0.0f;
                        _20820 = _19598;
                    }
                    else
                    {
                        float4 _20821;
                        if (_13102 > (_13070 + 0.07999999821186065673828125f))
                        {
                            float4 _19600 = _20786;
                            _19600.y = 0.0f;
                            _20821 = _19600;
                        }
                        else
                        {
                            _20821 = _20786;
                        }
                        _20820 = _20821;
                    }
                    _20819 = _20820;
                }
                else
                {
                    _20819 = _20786;
                }
                float _6660 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6662 = _20781 >= 0.0f;
                float _20802;
                if (_6662)
                {
                    _20802 = _20781 - _6660;
                }
                else
                {
                    float _20798;
                    if (_6597)
                    {
                        float _20797;
                        _20797 = 2.0f;
                        float _13160;
                        for (int _20796 = 0; _20796 < 24; _20797 = _13160, _20796++)
                        {
                            float _13124 = float(_20796 & 7) * 0.785398185253143310546875f;
                            int _13126 = _20796 >> 3;
                            int _20799;
                            if (_13126 == 0)
                            {
                                _20799 = 16;
                            }
                            else
                            {
                                _20799 = (_13126 == 1) ? 48 : 96;
                            }
                            uint _13176_dummy_parameter;
                            _13160 = min(_20797, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19895 + ((cbFI_MvDepthLaneSizeRcp * float(_20799)) * float2(cos(_13124), sin(_13124))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13176_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20798 = _20797;
                    }
                    else
                    {
                        _20798 = 0.0f;
                    }
                    _20802 = _20798;
                }
                float _20809;
                if (_6662)
                {
                    _20809 = _20781 - _6660;
                }
                else
                {
                    float _20805;
                    if (_6600)
                    {
                        float _20804;
                        _20804 = 2.0f;
                        float _13274;
                        for (int _20803 = 0; _20803 < 24; _20804 = _13274, _20803++)
                        {
                            float _13238 = float(_20803 & 7) * 0.785398185253143310546875f;
                            int _13240 = _20803 >> 3;
                            int _20806;
                            if (_13240 == 0)
                            {
                                _20806 = 16;
                            }
                            else
                            {
                                _20806 = (_13240 == 1) ? 48 : 96;
                            }
                            uint _13306_dummy_parameter;
                            _13274 = min(_20804, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19897 + ((cbFI_MvDepthLaneSizeRcp * float(_20806)) * float2(cos(_13238), sin(_13238))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13306_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20805 = _20804;
                    }
                    else
                    {
                        _20805 = 0.0f;
                    }
                    _20809 = _20805;
                }
                float _20810;
                if (_6597)
                {
                    uint _13338_dummy_parameter;
                    _20810 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_19895 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13338_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20810 = 0.0f;
                }
                float _20811;
                if (_6600)
                {
                    uint _13358_dummy_parameter;
                    _20811 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_19897 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13358_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20811 = 0.0f;
                }
                bool _6717;
                if (_6597)
                {
                    _6717 = _20810 > ((exp((_20802 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6717 = _6597;
                }
                float4 _20827;
                if (_6717)
                {
                    float4 _19602 = _20819;
                    _19602.x = 0.0f;
                    _20827 = _19602;
                }
                else
                {
                    _20827 = _20819;
                }
                bool _6729;
                if (_6600)
                {
                    _6729 = _20811 > ((exp((_20809 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6729 = _6600;
                }
                float4 _20829;
                if (_6729)
                {
                    float4 _19604 = _20827;
                    _19604.y = 0.0f;
                    _20829 = _19604;
                }
                else
                {
                    _20829 = _20827;
                }
                float4 _20892;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6662)
                {
                    bool _6749;
                    if (_6597)
                    {
                        _6749 = _20810 < ((exp((_20802 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6749 = _6597;
                    }
                    float4 _20831;
                    if (_6749)
                    {
                        float4 _19606 = _20829;
                        _19606.x = 0.0f;
                        _20831 = _19606;
                    }
                    else
                    {
                        _20831 = _20829;
                    }
                    bool _6761;
                    if (_6600)
                    {
                        _6761 = _20811 < ((exp((_20809 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6761 = _6600;
                    }
                    float4 _20893;
                    if (_6761)
                    {
                        float4 _19608 = _20831;
                        _19608.y = 0.0f;
                        _20893 = _19608;
                    }
                    else
                    {
                        _20893 = _20831;
                    }
                    _20892 = _20893;
                }
                else
                {
                    _20892 = _20829;
                }
                _22130 = float3(_20782, log(((r_depth_tm1.Load(int3(int2(floor(_19895 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12982_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_19897 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13014_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _20891 = _20892;
            }
            else
            {
                _22130 = float3(0.0f, 0.0f, 0.5f);
                _20891 = _20786;
            }
            bool _6772 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6521;
            bool _6778;
            if (_6772)
            {
                _6778 = _6575 || _6581;
            }
            else
            {
                _6778 = _6772;
            }
            float4 _20934;
            if (_6778)
            {
                float _20886;
                do
                {
                    uint4 _13538 = r_warped_motion_qdata_tp1.Load(int3(_20116, 0));
                    uint _13539 = _13538.x;
                    if (_13539 != 0u)
                    {
                        float _20885;
                        if (_13539 == 0u)
                        {
                            _20885 = -1.0f;
                        }
                        else
                        {
                            _20885 = float((_13539 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20886 = _20885;
                        break;
                    }
                    int _20868;
                    uint _20869;
                    _20869 = _13539;
                    _20868 = -1;
                    uint _20884;
                    for (; _20868 <= 1; _20869 = _20884, _20868++)
                    {
                        _20884 = _20869;
                        for (int _20882 = -1; _20882 <= 1; )
                        {
                            _20884 = max(_20884, r_warped_motion_qdata_tp1.Load(int3(clamp(_20116 + int2(_20882, _20868), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20882++;
                            continue;
                        }
                    }
                    if (_20869 != 0u)
                    {
                        float _20881;
                        if (_20869 == 0u)
                        {
                            _20881 = -1.0f;
                        }
                        else
                        {
                            _20881 = float((_20869 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20886 = _20881;
                        break;
                    }
                    uint _20871;
                    _20871 = 4294967295u;
                    uint _23662;
                    for (int _20870 = 0; _20870 < 8; _20871 = _23662, _20870++)
                    {
                        int _20874 = 0;
                        for (;;)
                        {
                            if (_20874 < 5)
                            {
                                int2 _13489 = _20116 + (_1243[_20870] * _1252[_20874].xx);
                                bool _13492 = any(bool2(_13489.x < int2(0, 0).x, _13489.y < int2(0, 0).y));
                                bool _13500;
                                if (!_13492)
                                {
                                    _13500 = any(bool2(_13489.x >= cbFI_MvDepthLaneSize.x, _13489.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13500 = _13492;
                                }
                                if (_13500)
                                {
                                    _23662 = _20871;
                                    break;
                                }
                                uint4 _13578 = r_warped_motion_qdata_tp1.Load(int3(_13489, 0));
                                uint _13579 = _13578.x;
                                if (_13579 != 0u)
                                {
                                    _23662 = min(_20871, _13579);
                                    break;
                                }
                                _20874++;
                                continue;
                            }
                            else
                            {
                                _23662 = _20871;
                                break;
                            }
                        }
                    }
                    float _20873;
                    if (_20871 == 4294967295u)
                    {
                        _20873 = -1.0f;
                    }
                    else
                    {
                        float _20872;
                        if (_20871 == 0u)
                        {
                            _20872 = -1.0f;
                        }
                        else
                        {
                            _20872 = float((_20871 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20873 = _20872;
                    }
                    _20886 = _20873;
                    break;
                } while(false);
                float4 _20935;
                if (_20886 >= 0.0f)
                {
                    float _13600 = (exp((_20886 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6797;
                    if (_6575)
                    {
                        uint _13607_dummy_parameter;
                        _6797 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19898 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13607_dummy_parameter))))), 0)).x) > _13600;
                    }
                    else
                    {
                        _6797 = _6575;
                    }
                    float4 _20904;
                    if (_6797)
                    {
                        float4 _19610 = _20891;
                        _19610.z = 0.0f;
                        _20904 = _19610;
                    }
                    else
                    {
                        _20904 = _20891;
                    }
                    bool _6809;
                    if (_6581)
                    {
                        uint _13627_dummy_parameter;
                        _6809 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19899 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13627_dummy_parameter))))), 0)).x) > _13600;
                    }
                    else
                    {
                        _6809 = _6581;
                    }
                    float4 _20936;
                    if (_6809)
                    {
                        float4 _19612 = _20904;
                        _19612.w = 0.0f;
                        _20936 = _19612;
                    }
                    else
                    {
                        _20936 = _20904;
                    }
                    _20935 = _20936;
                }
                else
                {
                    _20935 = _20891;
                }
                _20934 = _20935;
            }
            else
            {
                _20934 = _20891;
            }
            bool _6817 = _6563 != _6569;
            bool _6824;
            if (_6817)
            {
                _6824 = _6563 ? _6509 : _6512;
            }
            else
            {
                _6824 = _6817;
            }
            bool _6831;
            if (_6824)
            {
                _6831 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6831 = _6824;
            }
            float4 _21037;
            if (_6831)
            {
                bool2 _6836 = _6563.xx;
                float2 _6837 = float2(_6836.x ? _19895.x : _19897.x, _6836.y ? _19895.y : _19897.y);
                float _20918;
                if (_6563)
                {
                    uint _13647_dummy_parameter;
                    _20918 = r_depth_tm1.Load(int3(int2(floor(_6837 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13647_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13663_dummy_parameter;
                    _20918 = r_depth_tp1.Load(int3(int2(floor(_6837 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13663_dummy_parameter))))), 0)).x;
                }
                float4x4 _20925;
                if (_6563)
                {
                    float4x4 _20914;
                    do
                    {
                        float4x4 _13677;
                        bool _20913;
                        do
                        {
                            _13677 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20913 = false;
                                break;
                            }
                            uint _13711 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13711 + 32u) * 4 + 0) != 1u)
                            {
                                _20913 = false;
                                break;
                            }
                            uint _20910;
                            _20910 = 0u;
                            for (; _20910 < 4u; _20910++)
                            {
                                for (uint _20911 = 0u; _20911 < 4u; )
                                {
                                    _13677[_20910][_20911] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13711 + 16u) + (_20910 * 4u)) + _20911) * 4 + 0));
                                    _20911++;
                                    continue;
                                }
                            }
                            _20913 = true;
                            break;
                        } while(false);
                        if (_20913)
                        {
                            _20914 = _13677;
                            break;
                        }
                        _20914 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20925 = _20914;
                }
                else
                {
                    float4x4 _20909;
                    do
                    {
                        float4x4 _13783;
                        bool _20908;
                        do
                        {
                            _13783 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20908 = false;
                                break;
                            }
                            uint _13817 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13817 + 32u) * 4 + 0) != 1u)
                            {
                                _20908 = false;
                                break;
                            }
                            uint _20905;
                            _20905 = 0u;
                            for (; _20905 < 4u; _20905++)
                            {
                                for (uint _20906 = 0u; _20906 < 4u; )
                                {
                                    _13783[_20905][_20906] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13817 + (_20905 * 4u)) + _20906) * 4 + 0));
                                    _20906++;
                                    continue;
                                }
                            }
                            _20908 = true;
                            break;
                        } while(false);
                        if (_20908)
                        {
                            _20909 = _13783;
                            break;
                        }
                        _20909 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20925 = _20909;
                }
                float2 _20926;
                do
                {
                    float _13894 = _6837.x;
                    float _13897 = 1.0f - _6837.y;
                    float4 _13908 = mul(float4((float2(_13894, _13897) * 2.0f) - 1.0f.xx, _20918, 1.0f), _20925);
                    float _13910 = _13908.w;
                    if (!(_13910 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20926 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13923 = ((_13908.xy / _13910.xx) + 1.0f.xx) * 0.5f;
                    _20926 = float2(_13923.x - _13894, _13897 - _13923.y);
                    break;
                } while(false);
                float2 _6867 = float2(cbFI_DisplaySize);
                float4 _21038;
                if (!(length(((_6837 + _20926) - float2(_6836.x ? _19897.x : _19895.x, _6836.y ? _19897.y : _19895.y)) * _6867) <= ((0.100000001490116119384765625f * length(_20926 * _6867)) + 8.0f)))
                {
                    float4 _21039;
                    if (_6563)
                    {
                        float4 _19622 = _20934;
                        _19622.x = 0.0f;
                        _21039 = _19622;
                    }
                    else
                    {
                        float4 _19624 = _20934;
                        _19624.y = 0.0f;
                        _21039 = _19624;
                    }
                    _21038 = _21039;
                }
                else
                {
                    _21038 = _20934;
                }
                _21037 = _21038;
            }
            else
            {
                _21037 = _20934;
            }
            float4 _6892 = _20648 * _21037;
            float _6894 = dot(_6892, 1.0f.xxxx);
            float4 _21379;
            bool _21685;
            if (_6894 > 0.0f)
            {
                _21685 = _20339;
                _21379 = _6892 / _6894.xxxx;
            }
            else
            {
                bool _6905 = any(bool4(_21037.x < 1.0f.xxxx.x, _21037.y < 1.0f.xxxx.y, _21037.z < 1.0f.xxxx.z, _21037.w < 1.0f.xxxx.w));
                if (_6905)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13945;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13945);
                    }
                }
                bool4 _23775 = _6905.xxxx;
                _21685 = _6905 ? true : _20339;
                _21379 = float4(_23775.x ? 0.0f.xxxx.x : _20648.x, _23775.y ? 0.0f.xxxx.y : _20648.y, _23775.z ? 0.0f.xxxx.z : _20648.z, _23775.w ? 0.0f.xxxx.w : _20648.w);
            }
            _22021 = _22130;
            _21684 = _21685;
            _21378 = _21379;
        }
        else
        {
            _22021 = float3(0.0f, 0.0f, 0.5f);
            _21684 = _20339;
            _21378 = _20648;
        }
        uint _6914 = (cbFI_pad0 >> 24u) & 31u;
        uint _6918 = (cbFI_pad0 >> 16u) & 255u;
        bool _6920 = _6914 != 0u;
        bool _6922 = _6918 == 12u;
        bool _6925 = _6918 == 13u;
        float4 _21399;
        if ((_6920 || _6922) || _6925)
        {
            float _21045;
            do
            {
                bool _14029 = all(bool2(_19898.x > 0.0f.xx.x, _19898.y > 0.0f.xx.y));
                bool _14035;
                if (_14029)
                {
                    _14035 = all(bool2(_19898.x < 1.0f.xx.x, _19898.y < 1.0f.xx.y));
                }
                else
                {
                    _14035 = _14029;
                }
                bool _13966 = !_14035;
                bool _13973;
                if (!_13966)
                {
                    bool _14040 = all(bool2(_19899.x > 0.0f.xx.x, _19899.y > 0.0f.xx.y));
                    bool _14046;
                    if (_14040)
                    {
                        _14046 = all(bool2(_19899.x < 1.0f.xx.x, _19899.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _14046 = _14040;
                    }
                    _13973 = !_14046;
                }
                else
                {
                    _13973 = _13966;
                }
                if (_13973)
                {
                    _21045 = 0.0f;
                    break;
                }
                uint _14053_dummy_parameter;
                uint _14069_dummy_parameter;
                float4x4 _21044;
                do
                {
                    float4x4 _14083;
                    bool _21043;
                    do
                    {
                        _14083 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _21043 = false;
                            break;
                        }
                        uint _14117 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14117 + 32u) * 4 + 0) != 1u)
                        {
                            _21043 = false;
                            break;
                        }
                        uint _21040;
                        _21040 = 0u;
                        for (; _21040 < 4u; _21040++)
                        {
                            for (uint _21041 = 0u; _21041 < 4u; )
                            {
                                _14083[_21040][_21041] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14117 + 16u) + (_21040 * 4u)) + _21041) * 4 + 0));
                                _21041++;
                                continue;
                            }
                        }
                        _21043 = true;
                        break;
                    } while(false);
                    if (_21043)
                    {
                        _21044 = _14083;
                        break;
                    }
                    _21044 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13994 = mul(float4((float2(_19898.x, 1.0f - _19898.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19898 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14053_dummy_parameter))))), 0)).x, 1.0f), _21044);
                float _13996 = _13994.w;
                if (abs(_13996) < 9.9999999747524270787835121154785e-07f)
                {
                    _21045 = 0.0f;
                    break;
                }
                float _14007 = abs(cbFI_DeviceToViewDepth.y / ((_13994.z / _13996) - cbFI_DeviceToViewDepth.x));
                float _14010 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19899 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _14069_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _21045 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_14007 - _14010) / max(max(_14007, _14010), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14219 = all(bool2(_19899.x > 0.0f.xx.x, _19899.y > 0.0f.xx.y));
            bool _14225;
            if (_14219)
            {
                _14225 = all(bool2(_19899.x < 1.0f.xx.x, _19899.y < 1.0f.xx.y));
            }
            else
            {
                _14225 = _14219;
            }
            float _21046;
            if (_14225)
            {
                uint _14232_dummy_parameter;
                _21046 = length((_8045 + (r_motion_tp1.Load(int3(int2(floor(_19899 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14232_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _21046 = 1000000.0f;
            }
            float _21061;
            if ((_6914 & 1u) != 0u)
            {
                _21061 = _21045;
            }
            else
            {
                _21061 = 1.0f;
            }
            float _21062;
            if ((_6914 & 2u) != 0u)
            {
                _21062 = _21061 * (1.0f - smoothstep(2.0f, 8.0f, _21046));
            }
            else
            {
                _21062 = _21061;
            }
            float _21063;
            if ((_6914 & 4u) != 0u)
            {
                _21063 = _21062 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8766 - _8774) - length(_8750 - _8758))));
            }
            else
            {
                _21063 = _21062;
            }
            float _21393;
            if ((_6914 & 8u) != 0u)
            {
                _21393 = lerp(1.0f, _21063, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8750 - _8758)));
            }
            else
            {
                _21393 = _21063;
            }
            bool _7000 = (_6914 & 16u) != 0u;
            bool _7009;
            if (_7000)
            {
                _7009 = length(_19893 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _7009 = _7000;
            }
            float _23777 = _7009 ? 1.0f : _21393;
            bool _7015 = _6920 && _11147;
            bool _7020;
            if (_7015)
            {
                bool _14257 = all(bool2(_19895.x > 0.0f.xx.x, _19895.y > 0.0f.xx.y));
                bool _14263;
                if (_14257)
                {
                    _14263 = all(bool2(_19895.x < 1.0f.xx.x, _19895.y < 1.0f.xx.y));
                }
                else
                {
                    _14263 = _14257;
                }
                _7020 = _14263;
            }
            else
            {
                _7020 = _7015;
            }
            bool _7025;
            if (_7020)
            {
                bool _14268 = all(bool2(_19897.x > 0.0f.xx.x, _19897.y > 0.0f.xx.y));
                bool _14274;
                if (_14268)
                {
                    _14274 = all(bool2(_19897.x < 1.0f.xx.x, _19897.y < 1.0f.xx.y));
                }
                else
                {
                    _14274 = _14268;
                }
                _7025 = _14274;
            }
            else
            {
                _7025 = _7020;
            }
            float4 _21400;
            if (_7025)
            {
                float _7031 = _21378.x + _21378.y;
                float _7040 = (_21378.z + _21378.w) * (1.0f - _23777);
                float _21396;
                if (_7031 > 9.9999997473787516355514526367188e-06f)
                {
                    _21396 = _21378.x / _7031;
                }
                else
                {
                    _21396 = _5770;
                }
                _21400 = float4(_21378.x + (_7040 * _21396), _21378.y + (_7040 * (1.0f - _21396)), _21378.zw * _23777);
            }
            else
            {
                _21400 = _21378;
            }
            _21399 = _21400;
        }
        else
        {
            _21399 = _21378;
        }
        float3 _7101 = (((_8750 * _21399.x) + (_8758 * _21399.y)) + (_8766 * _21399.z)) + (_8774 * _21399.w);
        float3 _23410;
        if (_5786 && (_21414 > 0.0f))
        {
            uint _14281_dummy_parameter;
            float2 _14296 = r_motion_tp1.Load(int3(int2(floor(_5545 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14281_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21676;
            if (_8073)
            {
                float2 _14341 = clamp((((_19872 + (_14296 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14344 = tan(_14341.x);
                _21676 = (float2(_14344 / cbFI_DeviceToViewDepth.z, (tan(_14341.y) * sqrt(1.0f + (_14344 * _14344))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21676 = _19872 + (_14296 * cbFI_Timestep);
            }
            float2 _21677;
            if (_8073)
            {
                float2 _14420 = clamp((((_19872 + (_14296 * _5760)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14423 = tan(_14420.x);
                _21677 = (float2(_14423 / cbFI_DeviceToViewDepth.z, (tan(_14420.y) * sqrt(1.0f + (_14423 * _14423))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21677 = _19872 + (_14296 * _5760);
            }
            _23410 = lerp(_7101, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21676, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21677, 0.0f).xyz, cbFI_Timestep.xxx), _21414.xxx);
        }
        else
        {
            _23410 = _7101;
        }
        float3 _23409;
        if (_21684)
        {
            float3 _14465 = r_current_interpolation_source.Load(int3(_5046, 0)).xyz;
            float3 _23411;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11147)
            {
                uint _14472_dummy_parameter;
                float _21807;
                _21807 = r_depth_tm1.Load(int3(int2(floor(_19895 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14472_dummy_parameter))))), 0)).x;
                float _7182;
                for (int _21806 = 0; _21806 < 24; _21807 = _7182, _21806++)
                {
                    float _7154 = float(_21806 & 7) * 0.785398185253143310546875f;
                    int _7156 = _21806 >> 3;
                    int _23504;
                    if (_7156 == 0)
                    {
                        _23504 = 16;
                    }
                    else
                    {
                        _23504 = (_7156 == 1) ? 48 : 96;
                    }
                    uint _14492_dummy_parameter;
                    _7182 = max(_21807, r_depth_tm1.Load(int3(int2(floor(clamp(_19895 + ((cbFI_MvDepthLaneSizeRcp * float(_23504)) * float2(cos(_7154), sin(_7154))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14492_dummy_parameter))))), 0)).x);
                }
                float2 _21808;
                do
                {
                    float _14514 = 1.0f - _19895.y;
                    float4 _14525 = mul(float4((float2(_19895.x, _14514) * 2.0f) - 1.0f.xx, _21807, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14527 = _14525.w;
                    if (!(_14527 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21808 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14540 = ((_14525.xy / _14527.xx) + 1.0f.xx) * 0.5f;
                    _21808 = float2(_14540.x - _19895.x, _14514 - _14540.y);
                    break;
                } while(false);
                float2 _7193 = _19895 + _21808;
                bool _14558 = all(bool2(_7193.x > 0.0f.xx.x, _7193.y > 0.0f.xx.y));
                bool _14564;
                if (_14558)
                {
                    _14564 = all(bool2(_7193.x < 1.0f.xx.x, _7193.y < 1.0f.xx.y));
                }
                else
                {
                    _14564 = _14558;
                }
                float3 _23412;
                if (_14564)
                {
                    float _7199 = abs(cbFI_DeviceToViewDepth.y / (_21807 - cbFI_DeviceToViewDepth.x));
                    uint _14584_dummy_parameter;
                    int2 _14584 = int2(spvTextureSize(r_depth_m2, uint(0), _14584_dummy_parameter));
                    float _7203 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7193 * float2(_14584))), int2(0, 0), _14584 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _23417;
                    if (abs(_7203 - _7199) <= (0.20000000298023223876953125f * max(_7203, _7199)))
                    {
                        uint _14618_dummy_parameter;
                        int2 _14618 = int2(spvTextureSize(r_colour_m2, uint(0), _14618_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14641;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14641);
                        }
                        _23417 = r_colour_m2.Load(int3(clamp(int2(floor(_7193 * float2(_14618))), int2(0, 0), _14618 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14651;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14651);
                        }
                        _23417 = _14465;
                    }
                    _23412 = _23417;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14661;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14661);
                    }
                    _23412 = _14465;
                }
                _23411 = _23412;
            }
            else
            {
                _23411 = _14465;
            }
            _23409 = _23411;
        }
        else
        {
            _23409 = _23410;
        }
        bool _7228 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _23408;
        float _23484;
        if (_7228)
        {
            float2 _7232 = float2(cbFI_DisplaySize);
            float3 _21996;
            float _21997;
            do
            {
                bool _15077;
                float4x4 _21815;
                do
                {
                    float4x4 _15053;
                    bool _21814;
                    do
                    {
                        _15053 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _15077 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_15077)
                        {
                            _21814 = false;
                            break;
                        }
                        uint _15087 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_15087 + 32u) * 4 + 0) != 1u)
                        {
                            _21814 = false;
                            break;
                        }
                        uint _21811;
                        _21811 = 0u;
                        for (; _21811 < 4u; _21811++)
                        {
                            for (uint _21812 = 0u; _21812 < 4u; )
                            {
                                _15053[_21811][_21812] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15087 + (_21811 * 4u)) + _21812) * 4 + 0));
                                _21812++;
                                continue;
                            }
                        }
                        _21814 = true;
                        break;
                    } while(false);
                    if (_21814)
                    {
                        _21815 = _15053;
                        break;
                    }
                    _21815 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float4x4 _14665 = _21815;
                float4x4 _14737 = spvInverse(_21815);
                float4x4 _14666 = _14737;
                if (_6918 == 35u)
                {
                    int2 _14744 = int2(_5545 * _7232);
                    bool _14751 = _14744.y != (int(_7232.y) / 2);
                    bool _14758;
                    if (!_14751)
                    {
                        _14758 = _14744.x >= 80;
                    }
                    else
                    {
                        _14758 = _14751;
                    }
                    if (_14758)
                    {
                        _21997 = 2.0f;
                        _21996 = 0.0f.xxx;
                        break;
                    }
                    int _14762 = _14744.x;
                    int _14763 = _14762 / 2;
                    float _21990;
                    if (_14763 < 16)
                    {
                        _21990 = _14665[_14763 / 4][_14763 % 4];
                    }
                    else
                    {
                        float _21991;
                        if (_14763 < 32)
                        {
                            int _14778 = _14763 - 16;
                            _21991 = _14666[_14778 / 4][_14778 % 4];
                        }
                        else
                        {
                            float _21992;
                            if (_14763 < 36)
                            {
                                _21992 = cbFI_DeviceToViewDepth[_14763 - 32];
                            }
                            else
                            {
                                float _21993;
                                if (_14763 == 36)
                                {
                                    _21993 = float(cbFI_RenderSize.x);
                                }
                                else
                                {
                                    float _21994;
                                    if (_14763 == 37)
                                    {
                                        _21994 = float(cbFI_RenderSize.y);
                                    }
                                    else
                                    {
                                        _21994 = 0.0f;
                                    }
                                    _21993 = _21994;
                                }
                                _21992 = _21993;
                            }
                            _21991 = _21992;
                        }
                        _21990 = _21991;
                    }
                    uint _14813 = asuint(_21990);
                    uint _21995;
                    if ((_14762 & 1) == 0)
                    {
                        _21995 = _14813 >> 16u;
                    }
                    else
                    {
                        _21995 = _14813 & 65535u;
                    }
                    _21997 = 2.0f;
                    _21996 = float3(float(_21995 >> 8u) * 0.0039215688593685626983642578125f, float(_21995 & 255u) * 0.0039215688593685626983642578125f, 0.0f);
                    break;
                }
                bool _14837 = _6918 == 33u;
                if (_14837 || (_6918 == 34u))
                {
                    uint _15175_dummy_parameter;
                    float2 _15190 = r_motion_tp1.Load(int3(int2(floor(clamp(_5545, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15175_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
                    float2 _21982;
                    if (_14837)
                    {
                        uint _15202_dummy_parameter;
                        float2 _21981;
                        do
                        {
                            float _15221 = _5545.x;
                            float _15224 = 1.0f - _5545.y;
                            float4 _15235 = mul(float4((float2(_15221, _15224) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5545 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15202_dummy_parameter))))), 0)).x, 1.0f), _21815);
                            float _15237 = _15235.w;
                            if (!(_15237 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21981 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15250 = ((_15235.xy / _15237.xx) + 1.0f.xx) * 0.5f;
                            _21981 = float2(_15250.x - _15221, _15224 - _15250.y);
                            break;
                        } while(false);
                        _21982 = _21981 - _15190;
                    }
                    else
                    {
                        float2 _14857 = _5545 + _15190;
                        bool _15268 = all(bool2(_14857.x > 0.0f.xx.x, _14857.y > 0.0f.xx.y));
                        bool _15274;
                        if (_15268)
                        {
                            _15274 = all(bool2(_14857.x < 1.0f.xx.x, _14857.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15274 = _15268;
                        }
                        float2 _21980;
                        if (_15274)
                        {
                            uint _15281_dummy_parameter;
                            float2 _21979;
                            do
                            {
                                float _15300 = _14857.x;
                                float _15303 = 1.0f - _14857.y;
                                float4 _15314 = mul(float4((float2(_15300, _15303) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14857 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _15281_dummy_parameter))))), 0)).x, 1.0f), _14737);
                                float _15316 = _15314.w;
                                if (!(_15316 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21979 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _15329 = ((_15314.xy / _15316.xx) + 1.0f.xx) * 0.5f;
                                _21979 = float2(_15329.x - _15300, _15303 - _15329.y);
                                break;
                            } while(false);
                            _21980 = _21979 + _15190;
                        }
                        else
                        {
                            _21980 = 0.0f.xx;
                        }
                        _21982 = _21980;
                    }
                    bool _21989;
                    do
                    {
                        bool _15408 = all(bool2(_5545.x > 0.0f.xx.x, _5545.y > 0.0f.xx.y));
                        bool _15414;
                        if (_15408)
                        {
                            _15414 = all(bool2(_5545.x < 1.0f.xx.x, _5545.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15414 = _15408;
                        }
                        if (!_15414)
                        {
                            _21989 = false;
                            break;
                        }
                        uint _15421_dummy_parameter;
                        float4x4 _21987;
                        do
                        {
                            float4x4 _15435;
                            bool _21986;
                            do
                            {
                                _15435 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_15077)
                                {
                                    _21986 = false;
                                    break;
                                }
                                uint _15469 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_15469 + 32u) * 4 + 0) != 1u)
                                {
                                    _21986 = false;
                                    break;
                                }
                                uint _21983;
                                _21983 = 0u;
                                for (; _21983 < 4u; _21983++)
                                {
                                    for (uint _21984 = 0u; _21984 < 4u; )
                                    {
                                        _15435[_21983][_21984] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15469 + (_21983 * 4u)) + _21984) * 4 + 0));
                                        _21984++;
                                        continue;
                                    }
                                }
                                _21986 = true;
                                break;
                            } while(false);
                            if (_21986)
                            {
                                _21987 = _15435;
                                break;
                            }
                            _21987 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21988;
                        do
                        {
                            float _15546 = _5545.x;
                            float _15549 = 1.0f - _5545.y;
                            float4 _15560 = mul(float4((float2(_15546, _15549) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5545 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15421_dummy_parameter))))), 0)).x, 1.0f), _21987);
                            float _15562 = _15560.w;
                            if (!(_15562 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21988 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15575 = ((_15560.xy / _15562.xx) + 1.0f.xx) * 0.5f;
                            _21988 = float2(_15575.x - _15546, _15549 - _15575.y);
                            break;
                        } while(false);
                        float2 _15372 = abs(_21988);
                        if (any(bool2(_15372.x > 100000.0f.xx.x, _15372.y > 100000.0f.xx.y)))
                        {
                            _21989 = false;
                            break;
                        }
                        float _15380 = length(_21988 * _7232);
                        uint _15595_dummy_parameter;
                        bool _15394 = _15380 > ((8.0f * _7232.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _15401;
                        if (_15394)
                        {
                            _15401 = length((r_motion_tp1.Load(int3(int2(floor(_5545 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15595_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7232) < (0.20000000298023223876953125f * _15380);
                        }
                        else
                        {
                            _15401 = _15394;
                        }
                        _21989 = _15401;
                        break;
                    } while(false);
                    _21997 = 2.0f;
                    _21996 = float3(clamp(length(_21982 * float2(cbFI_RenderSize)) * 0.25f, 0.0f, 1.0f), float(_21989), 0.0f);
                    break;
                }
                float _15629;
                float _15632;
                float4 _15642;
                float2 _21816;
                do
                {
                    _15629 = _5545.x;
                    _15632 = 1.0f - _5545.y;
                    _15642 = float4((float2(_15629, _15632) * 2.0f) - 1.0f.xx, 0.99999988079071044921875f, 1.0f);
                    float4 _15643 = mul(_15642, _21815);
                    float _15645 = _15643.w;
                    if (!(_15645 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21816 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15658 = ((_15643.xy / _15645.xx) + 1.0f.xx) * 0.5f;
                    _21816 = float2(_15658.x - _15629, _15632 - _15658.y);
                    break;
                } while(false);
                float2 _21817;
                do
                {
                    float4 _15695 = mul(_15642, _14737);
                    float _15697 = _15695.w;
                    if (!(_15697 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21817 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15710 = ((_15695.xy / _15697.xx) + 1.0f.xx) * 0.5f;
                    _21817 = float2(_15710.x - _15629, _15632 - _15710.y);
                    break;
                } while(false);
                float2 _14892 = abs(_21816);
                bool2 _23778 = any(bool2(_14892.x > 4.0f.xx.x, _14892.y > 4.0f.xx.y)).xx;
                float2 _14898 = abs(_21817);
                bool2 _23780 = any(bool2(_14898.x > 4.0f.xx.x, _14898.y > 4.0f.xx.y)).xx;
                float2 _15724[3];
                _15724[0] = _5545;
                float2 _15844 = clamp(_5545, 0.0f.xx, 1.0f.xx);
                uint _15852_dummy_parameter;
                _15724[1] = _5545 - ((r_motion_tp1.Load(int3(int2(floor(_15844 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15852_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5770);
                _15724[2] = _5545 - (float2(_23778.x ? 0.0f.xx.x : _21816.x, _23778.y ? 0.0f.xx.y : _21816.y) * _5770);
                float _21823;
                float2 _21824;
                _21824 = _5545;
                _21823 = 1000000000.0f;
                float _23782;
                float2 _23784;
                float _23785;
                int _21822 = 0;
                float _21971 = -1.0f;
                for (; _21822 < 3; _21971 = _23782, _21824 = _23784, _21823 = _23785, _21822++)
                {
                    float2 _21961;
                    _21961 = _15724[_21822];
                    for (int _21960 = 0; _21960 < 30; )
                    {
                        uint _16366_dummy_parameter;
                        _21961 += (((_5545 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_21961, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16366_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5770)) - _21961) * 0.699999988079071044921875f);
                        _21960++;
                        continue;
                    }
                    float2 _16796 = clamp(_21961, 0.0f.xx, 1.0f.xx);
                    uint _16804_dummy_parameter;
                    bool _17234 = all(bool2(_21961.x > 0.0f.xx.x, _21961.y > 0.0f.xx.y));
                    bool _17240;
                    if (_17234)
                    {
                        _17240 = all(bool2(_21961.x < 1.0f.xx.x, _21961.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17240 = _17234;
                    }
                    float _21963;
                    if (_17240)
                    {
                        _21963 = length(((_21961 + ((r_motion_tp1.Load(int3(int2(floor(_16796 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16804_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5770)) - _5545) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21963 = 1000000000.0f;
                    }
                    uint _17251_dummy_parameter;
                    float _17291 = log(((r_depth_tp1.Load(int3(int2(floor(_16796 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17251_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15804 = _21963 < 0.3499999940395355224609375f;
                    bool _15806 = _21823 < 0.3499999940395355224609375f;
                    bool _15816;
                    if (_15804)
                    {
                        _15816 = (!_15806) || (_17291 > _21971);
                    }
                    else
                    {
                        _15816 = _15804;
                    }
                    bool _15829;
                    if (!_15816)
                    {
                        _15829 = ((!_15804) && (!_15806)) && (_21963 < _21823);
                    }
                    else
                    {
                        _15829 = _15816;
                    }
                    _23782 = _15829 ? _17291 : _21971;
                    bool2 _23783 = _15829.xx;
                    _23784 = float2(_23783.x ? _21961.x : _21824.x, _23783.y ? _21961.y : _21824.y);
                    _23785 = _15829 ? _21963 : _21823;
                }
                float2 _17293[3];
                _17293[0] = _5545;
                float2 _21843;
                do
                {
                    bool _21833;
                    do
                    {
                        bool _17540 = all(bool2(_15844.x > 0.0f.xx.x, _15844.y > 0.0f.xx.y));
                        bool _17546;
                        if (_17540)
                        {
                            _17546 = all(bool2(_15844.x < 1.0f.xx.x, _15844.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17546 = _17540;
                        }
                        if (!_17546)
                        {
                            _21833 = false;
                            break;
                        }
                        uint _17553_dummy_parameter;
                        float4x4 _21831;
                        do
                        {
                            float4x4 _17567;
                            bool _21830;
                            do
                            {
                                _17567 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_15077)
                                {
                                    _21830 = false;
                                    break;
                                }
                                uint _17601 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17601 + 32u) * 4 + 0) != 1u)
                                {
                                    _21830 = false;
                                    break;
                                }
                                uint _21827;
                                _21827 = 0u;
                                for (; _21827 < 4u; _21827++)
                                {
                                    for (uint _21828 = 0u; _21828 < 4u; )
                                    {
                                        _17567[_21827][_21828] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17601 + (_21827 * 4u)) + _21828) * 4 + 0));
                                        _21828++;
                                        continue;
                                    }
                                }
                                _21830 = true;
                                break;
                            } while(false);
                            if (_21830)
                            {
                                _21831 = _17567;
                                break;
                            }
                            _21831 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21832;
                        do
                        {
                            float _17678 = _15844.x;
                            float _17681 = 1.0f - _15844.y;
                            float4 _17692 = mul(float4((float2(_17678, _17681) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15844 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17553_dummy_parameter))))), 0)).x, 1.0f), _21831);
                            float _17694 = _17692.w;
                            if (!(_17694 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21832 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17707 = ((_17692.xy / _17694.xx) + 1.0f.xx) * 0.5f;
                            _21832 = float2(_17707.x - _17678, _17681 - _17707.y);
                            break;
                        } while(false);
                        float2 _17504 = abs(_21832);
                        if (any(bool2(_17504.x > 100000.0f.xx.x, _17504.y > 100000.0f.xx.y)))
                        {
                            _21833 = false;
                            break;
                        }
                        float _17512 = length(_21832 * _7232);
                        uint _17727_dummy_parameter;
                        bool _17526 = _17512 > ((8.0f * _7232.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17533;
                        if (_17526)
                        {
                            _17533 = length((r_motion_tp1.Load(int3(int2(floor(_15844 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17727_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7232) < (0.20000000298023223876953125f * _17512);
                        }
                        else
                        {
                            _17533 = _17526;
                        }
                        _21833 = _17533;
                        break;
                    } while(false);
                    if (_21833)
                    {
                        uint _17758_dummy_parameter;
                        _21843 = -(r_motion_tp1.Load(int3(int2(floor(_15844 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17758_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17785_dummy_parameter;
                    float2 _21842;
                    do
                    {
                        float _17804 = _15844.x;
                        float _17807 = 1.0f - _15844.y;
                        float4 _17818 = mul(float4((float2(_17804, _17807) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15844 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17785_dummy_parameter))))), 0)).x, 1.0f), _14737);
                        float _17820 = _17818.w;
                        if (!(_17820 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21842 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17833 = ((_17818.xy / _17820.xx) + 1.0f.xx) * 0.5f;
                        _21842 = float2(_17833.x - _17804, _17807 - _17833.y);
                        break;
                    } while(false);
                    float2 _17471 = abs(_21842);
                    bool2 _17475 = any(bool2(_17471.x > 4.0f.xx.x, _17471.y > 4.0f.xx.y)).xx;
                    _21843 = float2(_17475.x ? 0.0f.xx.x : _21842.x, _17475.y ? 0.0f.xx.y : _21842.y);
                    break;
                } while(false);
                _17293[1] = _5545 - (_21843 * cbFI_Timestep);
                _17293[2] = _5545 - (float2(_23780.x ? 0.0f.xx.x : _21817.x, _23780.y ? 0.0f.xx.y : _21817.y) * cbFI_Timestep);
                float _21845;
                float2 _21846;
                _21846 = _5545;
                _21845 = 1000000000.0f;
                float _23786;
                float2 _23788;
                float _23789;
                float4x4 _18081;
                float4x4 _18519;
                int _21844 = 0;
                float _21898 = -1.0f;
                for (; _21844 < 3; _21898 = _23786, _21846 = _23788, _21845 = _23789, _21844++)
                {
                    float2 _21848;
                    _21848 = _17293[_21844];
                    float2 _17890;
                    for (int _21847 = 0; _21847 < 30; _21848 = _17890, _21847++)
                    {
                        float2 _21939;
                        do
                        {
                            float2 _17970 = clamp(_21848, 0.0f.xx, 1.0f.xx);
                            bool _21929;
                            do
                            {
                                bool _18054 = all(bool2(_17970.x > 0.0f.xx.x, _17970.y > 0.0f.xx.y));
                                bool _18060;
                                if (_18054)
                                {
                                    _18060 = all(bool2(_17970.x < 1.0f.xx.x, _17970.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _18060 = _18054;
                                }
                                if (!_18060)
                                {
                                    _21929 = false;
                                    break;
                                }
                                uint _18067_dummy_parameter;
                                float4x4 _21927;
                                do
                                {
                                    bool _21926;
                                    do
                                    {
                                        _18081 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_15077)
                                        {
                                            _21926 = false;
                                            break;
                                        }
                                        uint _18115 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_18115 + 32u) * 4 + 0) != 1u)
                                        {
                                            _21926 = false;
                                            break;
                                        }
                                        uint _21923;
                                        _21923 = 0u;
                                        for (; _21923 < 4u; _21923++)
                                        {
                                            for (uint _21924 = 0u; _21924 < 4u; )
                                            {
                                                _18081[_21923][_21924] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18115 + (_21923 * 4u)) + _21924) * 4 + 0));
                                                _21924++;
                                                continue;
                                            }
                                        }
                                        _21926 = true;
                                        break;
                                    } while(false);
                                    if (_21926)
                                    {
                                        _21927 = _18081;
                                        break;
                                    }
                                    _21927 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _21928;
                                do
                                {
                                    float _18192 = _17970.x;
                                    float _18195 = 1.0f - _17970.y;
                                    float4 _18206 = mul(float4((float2(_18192, _18195) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17970 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18067_dummy_parameter))))), 0)).x, 1.0f), _21927);
                                    float _18208 = _18206.w;
                                    if (!(_18208 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _21928 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _18221 = ((_18206.xy / _18208.xx) + 1.0f.xx) * 0.5f;
                                    _21928 = float2(_18221.x - _18192, _18195 - _18221.y);
                                    break;
                                } while(false);
                                float2 _18018 = abs(_21928);
                                if (any(bool2(_18018.x > 100000.0f.xx.x, _18018.y > 100000.0f.xx.y)))
                                {
                                    _21929 = false;
                                    break;
                                }
                                float _18026 = length(_21928 * _7232);
                                uint _18241_dummy_parameter;
                                bool _18040 = _18026 > ((8.0f * _7232.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _18047;
                                if (_18040)
                                {
                                    _18047 = length((r_motion_tp1.Load(int3(int2(floor(_17970 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18241_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7232) < (0.20000000298023223876953125f * _18026);
                                }
                                else
                                {
                                    _18047 = _18040;
                                }
                                _21929 = _18047;
                                break;
                            } while(false);
                            if (_21929)
                            {
                                uint _18272_dummy_parameter;
                                _21939 = -(r_motion_tp1.Load(int3(int2(floor(_17970 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18272_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _18299_dummy_parameter;
                            float2 _21938;
                            do
                            {
                                float _18318 = _17970.x;
                                float _18321 = 1.0f - _17970.y;
                                float4 _18332 = mul(float4((float2(_18318, _18321) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17970 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18299_dummy_parameter))))), 0)).x, 1.0f), _14737);
                                float _18334 = _18332.w;
                                if (!(_18334 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21938 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18347 = ((_18332.xy / _18334.xx) + 1.0f.xx) * 0.5f;
                                _21938 = float2(_18347.x - _18318, _18321 - _18347.y);
                                break;
                            } while(false);
                            float2 _17985 = abs(_21938);
                            bool2 _17989 = any(bool2(_17985.x > 4.0f.xx.x, _17985.y > 4.0f.xx.y)).xx;
                            _21939 = float2(_17989.x ? 0.0f.xx.x : _21938.x, _17989.y ? 0.0f.xx.y : _21938.y);
                            break;
                        } while(false);
                        _17890 = _21848 + (((_5545 - (_21939 * cbFI_Timestep)) - _21848) * 0.699999988079071044921875f);
                    }
                    float2 _18408;
                    float2 _21865;
                    do
                    {
                        _18408 = clamp(_21848, 0.0f.xx, 1.0f.xx);
                        bool _21855;
                        do
                        {
                            bool _18492 = all(bool2(_18408.x > 0.0f.xx.x, _18408.y > 0.0f.xx.y));
                            bool _18498;
                            if (_18492)
                            {
                                _18498 = all(bool2(_18408.x < 1.0f.xx.x, _18408.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18498 = _18492;
                            }
                            if (!_18498)
                            {
                                _21855 = false;
                                break;
                            }
                            uint _18505_dummy_parameter;
                            float4x4 _21853;
                            do
                            {
                                bool _21852;
                                do
                                {
                                    _18519 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_15077)
                                    {
                                        _21852 = false;
                                        break;
                                    }
                                    uint _18553 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18553 + 32u) * 4 + 0) != 1u)
                                    {
                                        _21852 = false;
                                        break;
                                    }
                                    uint _21849;
                                    _21849 = 0u;
                                    for (; _21849 < 4u; _21849++)
                                    {
                                        for (uint _21850 = 0u; _21850 < 4u; )
                                        {
                                            _18519[_21849][_21850] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18553 + (_21849 * 4u)) + _21850) * 4 + 0));
                                            _21850++;
                                            continue;
                                        }
                                    }
                                    _21852 = true;
                                    break;
                                } while(false);
                                if (_21852)
                                {
                                    _21853 = _18519;
                                    break;
                                }
                                _21853 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _21854;
                            do
                            {
                                float _18633 = 1.0f - _18408.y;
                                float4 _18644 = mul(float4((float2(_18408.x, _18633) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18408 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18505_dummy_parameter))))), 0)).x, 1.0f), _21853);
                                float _18646 = _18644.w;
                                if (!(_18646 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21854 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18659 = ((_18644.xy / _18646.xx) + 1.0f.xx) * 0.5f;
                                _21854 = float2(_18659.x - _18408.x, _18633 - _18659.y);
                                break;
                            } while(false);
                            float2 _18456 = abs(_21854);
                            if (any(bool2(_18456.x > 100000.0f.xx.x, _18456.y > 100000.0f.xx.y)))
                            {
                                _21855 = false;
                                break;
                            }
                            float _18464 = length(_21854 * _7232);
                            uint _18679_dummy_parameter;
                            bool _18478 = _18464 > ((8.0f * _7232.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18485;
                            if (_18478)
                            {
                                _18485 = length((r_motion_tp1.Load(int3(int2(floor(_18408 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18679_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7232) < (0.20000000298023223876953125f * _18464);
                            }
                            else
                            {
                                _18485 = _18478;
                            }
                            _21855 = _18485;
                            break;
                        } while(false);
                        if (_21855)
                        {
                            uint _18710_dummy_parameter;
                            _21865 = -(r_motion_tp1.Load(int3(int2(floor(_18408 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18710_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18737_dummy_parameter;
                        float2 _21864;
                        do
                        {
                            float _18759 = 1.0f - _18408.y;
                            float4 _18770 = mul(float4((float2(_18408.x, _18759) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18408 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18737_dummy_parameter))))), 0)).x, 1.0f), _14737);
                            float _18772 = _18770.w;
                            if (!(_18772 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21864 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18785 = ((_18770.xy / _18772.xx) + 1.0f.xx) * 0.5f;
                            _21864 = float2(_18785.x - _18408.x, _18759 - _18785.y);
                            break;
                        } while(false);
                        float2 _18423 = abs(_21864);
                        bool2 _18427 = any(bool2(_18423.x > 4.0f.xx.x, _18423.y > 4.0f.xx.y)).xx;
                        _21865 = float2(_18427.x ? 0.0f.xx.x : _21864.x, _18427.y ? 0.0f.xx.y : _21864.y);
                        break;
                    } while(false);
                    bool _18803 = all(bool2(_21848.x > 0.0f.xx.x, _21848.y > 0.0f.xx.y));
                    bool _18809;
                    if (_18803)
                    {
                        _18809 = all(bool2(_21848.x < 1.0f.xx.x, _21848.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18809 = _18803;
                    }
                    float _21877;
                    if (_18809)
                    {
                        _21877 = length(((_21848 + (_21865 * cbFI_Timestep)) - _5545) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21877 = 1000000000.0f;
                    }
                    uint _18836_dummy_parameter;
                    float _18860 = log(((r_depth_tm1.Load(int3(int2(floor(_18408 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18836_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _17373 = _21877 < 0.3499999940395355224609375f;
                    bool _17375 = _21845 < 0.3499999940395355224609375f;
                    bool _17385;
                    if (_17373)
                    {
                        _17385 = (!_17375) || (_18860 > _21898);
                    }
                    else
                    {
                        _17385 = _17373;
                    }
                    bool _17398;
                    if (!_17385)
                    {
                        _17398 = ((!_17373) && (!_17375)) && (_21877 < _21845);
                    }
                    else
                    {
                        _17398 = _17385;
                    }
                    _23786 = _17398 ? _18860 : _21898;
                    bool2 _23787 = _17398.xx;
                    _23788 = float2(_23787.x ? _21848.x : _21846.x, _23787.y ? _21848.y : _21846.y);
                    _23789 = _17398 ? _21877 : _21845;
                }
                float3 _18869 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21824, 0.0f).xyz;
                float3 _18877 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21846, 0.0f).xyz;
                uint _18884_dummy_parameter;
                uint _18915_dummy_parameter;
                float _14938 = exp((_21823 * (-2.0f)) * (_21823 * 2.0f));
                float _14945 = exp((_21845 * (-2.0f)) * (_21845 * 2.0f));
                float _14958 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21846, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18915_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21824, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18884_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14972 = ((_14938 * cbFI_Timestep) * ((1.0f - _14945) + ((_14945 * 2.0f) * _14958))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14982 = 1.0f - _14958;
                float _14989 = ((_14945 * _5770) * ((1.0f - _14938) + ((_14938 * 2.0f) * _14982))) + (9.9999997473787516355514526367188e-05f * _5770);
                float _14998 = (((_14938 * _14945) * 4.0f) * _14958) * _14982;
                float _15016 = (_14998 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18877 - _18869, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14998)) * max(_14938, _14945));
                if (_6918 == 30u)
                {
                    _21997 = _15016;
                    _21996 = _18869;
                    break;
                }
                if (_6918 == 31u)
                {
                    _21997 = _15016;
                    _21996 = _18877;
                    break;
                }
                if (_6918 == 32u)
                {
                    _21997 = _15016;
                    _21996 = float3(_14938, _14945, _14958);
                    break;
                }
                _21997 = _15016;
                _21996 = ((_18869 * _14972) + (_18877 * _14989)) / (_14972 + _14989).xxx;
                break;
            } while(false);
            _23484 = _21997;
            _23408 = _21996;
        }
        else
        {
            _23484 = 1.0f;
            _23408 = _23409;
        }
        uint _7248 = cbFI_pad0 & 255u;
        bool _23208;
        float3 _23407;
        if (_7248 != 0u)
        {
            float3 _7253 = r_present_backbuffer.Load(int3(_5046, 0)).xyz;
            float3 _7257 = r_current_interpolation_source.Load(int3(_5046, 0)).xyz;
            float3 _7261 = abs(_7253 - _7257);
            float3 _22013;
            if (_7248 == 2u)
            {
                _22013 = (abs(_7257) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _22013 = 0.000244140625f.xxx;
            }
            bool _7277 = any(bool3(_7261.x > _22013.x, _7261.y > _22013.y, _7261.z > _22013.z));
            bool3 _23790 = _7277.xxx;
            _23407 = float3(_23790.x ? _7253.x : _23408.x, _23790.y ? _7253.y : _23408.y, _23790.z ? _7253.z : _23408.z);
            _23208 = _7277;
        }
        else
        {
            _23407 = _23408;
            _23208 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18953;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18953);
        }
        float3 _23389;
        if (_6918 == 1u)
        {
            _23389 = lerp(_8750, _8758, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _23390;
            if (_6918 == 2u)
            {
                _23390 = lerp(_8766, _8774, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _23391;
                if (_6918 == 3u)
                {
                    _23391 = float(_23208).xxx;
                }
                else
                {
                    float3 _23392;
                    if (_6918 == 4u)
                    {
                        _23392 = float3(((_19893 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _23393;
                        if (_6918 == 5u)
                        {
                            _23393 = float3(((_8045 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _23394;
                            if (_6918 == 6u)
                            {
                                _23394 = float3(_21399.xy, _21399.z + _21399.w);
                            }
                            else
                            {
                                float3 _23395;
                                if (_6918 == 7u)
                                {
                                    _23395 = r_current_interpolation_source.Load(int3(_5046, 0)).xyz;
                                }
                                else
                                {
                                    float3 _23396;
                                    if (_6918 == 8u)
                                    {
                                        _23396 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5545, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _23397;
                                        if (_6922)
                                        {
                                            uint _18975_dummy_parameter;
                                            uint _19007_dummy_parameter;
                                            _23397 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_5545 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18975_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_5545 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _19007_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _23398;
                                            if (_6925)
                                            {
                                                _23398 = _8766;
                                            }
                                            else
                                            {
                                                float3 _23399;
                                                if (_6918 == 20u)
                                                {
                                                    _23399 = _8750;
                                                }
                                                else
                                                {
                                                    float3 _23400;
                                                    if (_6918 == 21u)
                                                    {
                                                        _23400 = _8758;
                                                    }
                                                    else
                                                    {
                                                        float3 _23401;
                                                        if (_6918 == 22u)
                                                        {
                                                            _23401 = _8774;
                                                        }
                                                        else
                                                        {
                                                            float3 _23402;
                                                            if (_6918 == 18u)
                                                            {
                                                                _23402 = _22635;
                                                            }
                                                            else
                                                            {
                                                                float3 _23403;
                                                                if (_6918 == 19u)
                                                                {
                                                                    _23403 = _22325;
                                                                }
                                                                else
                                                                {
                                                                    float3 _23404;
                                                                    if (_6918 == 23u)
                                                                    {
                                                                        _23404 = _22021;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _23405;
                                                                        if (_6918 == 24u)
                                                                        {
                                                                            uint _7421 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7426 = float(rw_nfru_diagnostics.Load<uint>((_7421 + 35u) * 4 + 0));
                                                                            float _22014;
                                                                            if (_7426 > 0.0f)
                                                                            {
                                                                                _22014 = float(rw_nfru_diagnostics.Load<uint>((_7421 + 34u) * 4 + 0)) / _7426;
                                                                            }
                                                                            else
                                                                            {
                                                                                _22014 = 0.0f;
                                                                            }
                                                                            _23405 = float3(float(rw_nfru_diagnostics.Load<uint>((_7421 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7421 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _22014);
                                                                        }
                                                                        else
                                                                        {
                                                                            _23405 = _23407;
                                                                        }
                                                                        _23404 = _23405;
                                                                    }
                                                                    _23403 = _23404;
                                                                }
                                                                _23402 = _23403;
                                                            }
                                                            _23401 = _23402;
                                                        }
                                                        _23400 = _23401;
                                                    }
                                                    _23399 = _23400;
                                                }
                                                _23398 = _23399;
                                            }
                                            _23397 = _23398;
                                        }
                                        _23396 = _23397;
                                    }
                                    _23395 = _23396;
                                }
                                _23394 = _23395;
                            }
                            _23393 = _23394;
                        }
                        _23392 = _23393;
                    }
                    _23391 = _23392;
                }
                _23390 = _23391;
            }
            _23389 = _23390;
        }
        float3 _23388;
        if ((_6918 >= 9u) && (_6918 <= 11u))
        {
            uint _7486 = 64u + uint((_20116.y * cbFI_MvDepthLaneSize.x) + _20116.x);
            uint _7490 = rw_nfru_diagnostics.Load<uint>(_7486 * 4 + 0) & 15u;
            float3 _23422;
            if (_6918 == 10u)
            {
                float3 _23387;
                if ((rw_nfru_diagnostics.Load<uint>(_7486 * 4 + 0) & 32u) != 0u)
                {
                    _23387 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _23386;
                    if ((rw_nfru_diagnostics.Load<uint>(_7486 * 4 + 0) & 16u) != 0u)
                    {
                        _23386 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7511 = ((rw_nfru_diagnostics.Load<uint>(_7486 * 4 + 0) & 64u) != 0u).xxx;
                        _23386 = float3(_7511.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7511.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7511.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _23387 = _23386;
                }
                _23422 = _23387;
            }
            else
            {
                float3 _23423;
                if (_6918 == 11u)
                {
                    uint _7524 = (rw_nfru_diagnostics.Load<uint>(_7486 * 4 + 0) >> 8u) & 15u;
                    uint _7527 = (rw_nfru_diagnostics.Load<uint>(_7486 * 4 + 0) >> 12u) & 15u;
                    float3 _23379;
                    if ((_7490 == 2u) || (_7490 == 3u))
                    {
                        _23379 = _4746[_7490];
                    }
                    else
                    {
                        bool _7539 = _7524 == 3u;
                        bool _7541 = _7527 == 3u;
                        float3 _23380;
                        if (_7539 && _7541)
                        {
                            _23380 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _23381;
                            if (_7539)
                            {
                                _23381 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _23382;
                                if (_7541)
                                {
                                    _23382 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _23383;
                                    if ((_7524 == 4u) || (_7527 == 4u))
                                    {
                                        _23383 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _23384;
                                        if ((_7524 == 1u) || (_7527 == 1u))
                                        {
                                            _23384 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23792 = (_7490 == 1u).xxx;
                                            _23384 = float3(_23792.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23792.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23792.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _23383 = _23384;
                                    }
                                    _23382 = _23383;
                                }
                                _23381 = _23382;
                            }
                            _23380 = _23381;
                        }
                        _23379 = _23380;
                    }
                    _23423 = _23379;
                }
                else
                {
                    _23423 = _4746[min(_7490, 7u)];
                }
                _23422 = _23423;
            }
            _23388 = _23422;
        }
        else
        {
            _23388 = _23389;
        }
        float4 _23426;
        if ((_6918 >= 14u) && (_6918 <= 16u))
        {
            float2 _23424;
            if (_6918 == 14u)
            {
                uint _7597_dummy_parameter;
                uint _7603_dummy_parameter;
                _23424 = r_flow_tm1.Load(int3(clamp(int2(floor(_5545 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7597_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7603_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _23425;
                if (_6918 == 16u)
                {
                    uint _19083 = r_warped_flow_qdata_tm1.Load(int3(_5561, 0)).x & 2147483647u;
                    uint _19115 = uint(max((int((_19083 >> 16u) & 15u) - 6), 0));
                    _23425 = ((float2(float((1 - (2 * int((_19083 >> 15u) & 1u))) * int(((_19083 >> uint(7)) & 127u) << _19115)), float((1 - (2 * int((_19083 >> 14u) & 1u))) * int((_19083 & 127u) << _19115))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _23425 = _8045 * float2(cbFI_DisplaySize);
                }
                _23424 = _23425;
            }
            uint2 _7636 = uint2(clamp(round(_23424 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7638 = _7636.x;
            uint _7645 = _7636.y;
            _23426 = float4(float(_7638 & 255u), float((_7638 >> 8u) | ((_7645 & 15u) << 4u)), float(_7645 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _23427;
            if (_6918 == 17u)
            {
                _23427 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5561, 0)).x != 0u), _6005, 0.0f, 1.0f);
            }
            else
            {
                _23427 = float4(_23388, 1.0f);
            }
            _23426 = _23427;
        }
        rw_output[_5046] = _23426.xyz;
        if (_7228)
        {
            uint _19160 = uint((_5046.y * cbFI_DisplaySize.x) + _5046.x) * 2u;
            rw_nfru_select.Store<uint>(_19160 * 4 + 0, spvPackHalf2x16(_23426.xy));
            rw_nfru_select.Store<uint>((_19160 + 1u) * 4 + 0, spvPackHalf2x16(float2(_23426.z, (_23208 || (_6918 != 0u)) ? 2.0f : _23484)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7703 = ((uint(_5046.y) * uint(cbFI_DisplaySize.x)) + uint(_5046.x)) * 6u;
            uint _19186 = spvPackHalf2x16(clamp(_8749.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7703 * 4 + 0, (((_19186 & 32767u) >> 4u) | ((((_19186 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8749.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19221 = spvPackHalf2x16(clamp(_8757.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7703 + 1u) * 4 + 0, (((_19221 & 32767u) >> 4u) | ((((_19221 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8757.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19256 = spvPackHalf2x16(clamp(_8765.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7703 + 2u) * 4 + 0, (((_19256 & 32767u) >> 4u) | ((((_19256 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8765.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19291 = spvPackHalf2x16(clamp(_8773.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7703 + 3u) * 4 + 0, (((_19291 & 32767u) >> 4u) | ((((_19291 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8773.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19318 = r_current_interpolation_source.Load(int3(_5046, 0));
            uint _19332 = spvPackHalf2x16(clamp(_19318.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7703 + 4u) * 4 + 0, (((_19332 & 32767u) >> 4u) | ((((_19332 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19318.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _23503;
            if (_23208 || (_6918 != 0u))
            {
                _23503 = 4294967295u;
            }
            else
            {
                uint _19367 = spvPackHalf2x16(clamp(_23426.xy, 0.0f.xx, 65000.0f.xx));
                _23503 = (((_19367 & 32767u) >> 4u) | ((((_19367 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_23426.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7703 + 5u) * 4 + 0, _23503);
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
