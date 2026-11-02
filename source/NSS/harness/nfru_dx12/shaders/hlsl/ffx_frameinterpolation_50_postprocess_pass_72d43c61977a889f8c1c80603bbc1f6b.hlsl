static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19954;

static const int2 _1251[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1260[5] = { 2, 4, 7, 11, 16 };
static const float3 _4765[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _5082 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_5082.x >= cbFI_DisplaySize.x, _5082.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_5082] = float4(r_present_backbuffer.Load(int3(_5082, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_5082] = float4(r_current_interpolation_source.Load(int3(_5082, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7972 = cbFI_DisplaySize - int2(1, 1);
                int2 _7973 = clamp(_5082, int2(0, 0), _7972);
                uint _7983 = uint((_7973.y * cbFI_DisplaySize.x) + _7973.x) * 2u;
                uint _7986 = rw_nfru_select.Load<uint>(_7983 * 4 + 0);
                float2 _7987 = spvUnpackHalf2x16(_7986);
                uint _7991 = rw_nfru_select.Load<uint>((_7983 + 1u) * 4 + 0);
                float2 _7992 = spvUnpackHalf2x16(_7991);
                float _7993 = _7987.x;
                float _7995 = _7992.x;
                if (_7992.y > 1.5f)
                {
                    rw_output[_5082] = float4(_7993, _7987.y, _7995, 1.0f).xyz;
                    break;
                }
                int _23628;
                float _23629;
                float3 _23630;
                float _23631;
                float _23632;
                _23632 = 0.0f;
                _23631 = 0.0f;
                _23630 = 0.0f.xxx;
                _23629 = 0.0f;
                _23628 = -2;
                float3 _23635;
                float _23636;
                float _23637;
                float _23638;
                for (; _23628 <= 2; _23632 = _23638, _23631 = _23637, _23630 = _23635, _23629 = _23636, _23628++)
                {
                    _23638 = _23632;
                    _23637 = _23631;
                    _23636 = _23629;
                    _23635 = _23630;
                    for (int _23633 = -2; _23633 <= 2; )
                    {
                        float _7889 = float((_23633 * _23633) + (_23628 * _23628));
                        float _7894 = exp(_7889 * (-0.319999992847442626953125f));
                        int2 _7899 = int2(_23633, _23628);
                        int2 _8009 = clamp(_5082 + (_7899 * int2(2, 2)), int2(0, 0), _7972);
                        uint _8019 = uint((_8009.y * cbFI_DisplaySize.x) + _8009.x) * 2u;
                        float _7916 = exp(_7889 * (-0.5f));
                        int2 _8041 = clamp(_5082 + (_7899 * int2(6, 6)), int2(0, 0), _7972);
                        _23638 += _7916;
                        _23637 += (_7916 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_8041.y * cbFI_DisplaySize.x) + _8041.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23636 += _7894;
                        _23635 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_8019 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_8019 + 1u) * 4 + 0)).x, _19954).xyz * _7894);
                        _23633++;
                        continue;
                    }
                }
                float3 _7946 = _23630 / _23629.xxx;
                rw_output[_5082] = float4(_7946 + ((float4(_7993, _7987.y, _7995, _7992.y).xyz - _7946) * clamp(_23631 / _23632, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5594 = (float2(_5082) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5596 = float2(cbFI_MvDepthLaneSize);
        int2 _5605 = int2(floor(_5594 * _5596));
        int2 _5610 = int2(floor(_5594 * float2(cbFI_FlowLaneSize)));
        float4 _8112 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5594 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _8118 = r_warped_filled_flow_tm1.Load(int3(_5610, 0)).xy;
        float2 _8124 = r_warped_filled_motion_tp1.Load(int3(_5605, 0)).xy;
        bool _8146 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19955;
        if (_8146)
        {
            float _8159 = ((2.0f * _5594.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19955 = float2(atan(_8159) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5594.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_8159 * _8159))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19955 = _5594;
        }
        bool _5631 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19976;
        bool _20118;
        int2 _20199;
        float3 _22718;
        if (_5631)
        {
            float _19957;
            float _19959;
            _19959 = 2.0f;
            _19957 = -1.0f;
            uint _5181[9];
            float _23639;
            float _23642;
            for (int _19956 = 0; _19956 < 9; _19959 = _23642, _19957 = _23639, _19956++)
            {
                _5181[_19956] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5605 + int2((_19956 % 3) - 1, (_19956 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_5181[_19956] != 0u)
                {
                    float _23623;
                    if (_5181[_19956] == 0u)
                    {
                        _23623 = -1.0f;
                    }
                    else
                    {
                        _23623 = float((_5181[_19956] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23642 = min(_19959, _23623);
                    _23639 = max(_19957, _23623);
                }
                else
                {
                    _23642 = _19959;
                    _23639 = _19957;
                }
            }
            float _5677 = float(_19957 >= 0.0f);
            float3 _19492 = 0.0f.xxx;
            _19492.y = _5677;
            float2 _19977;
            bool _20119;
            int2 _20200;
            float3 _22719;
            if ((_19957 - _19959) > 0.0199999995529651641845703125f)
            {
                float _19965;
                int2 _19966;
                float2 _19967;
                int2 _19969;
                float2 _19975;
                _19975 = _8124;
                _19969 = _5605;
                _19967 = _8124;
                _19966 = _5605;
                _19965 = -1.0f;
                float _23647;
                int2 _23651;
                float2 _23662;
                int2 _23673;
                float2 _23706;
                float _23831;
                int _19964 = 0;
                float _23604 = 1000000000.0f;
                for (; _19964 < 9; _23604 = _23831, _19975 = _23706, _19969 = _23673, _19967 = _23662, _19966 = _23651, _19965 = _23647, _19964++)
                {
                    if (_5181[_19964] == 0u)
                    {
                        _23831 = _23604;
                        _23706 = _19975;
                        _23673 = _19969;
                        _23662 = _19967;
                        _23651 = _19966;
                        _23647 = _19965;
                        continue;
                    }
                    int2 _5712 = clamp(_5605 + int2((_19964 % 3) - 1, (_19964 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8234 = _5181[_19964] & 2147483647u;
                    uint _8266 = uint(max((int((_8234 >> 16u) & 15u) - 6), 0));
                    float2 _5718 = (float2(float((1 - (2 * int((_8234 >> 15u) & 1u))) * int(((_8234 >> uint(7)) & 127u) << _8266)), float((1 - (2 * int((_8234 >> 14u) & 1u))) * int((_8234 & 127u) << _8266))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23590;
                    if (_5181[_19964] == 0u)
                    {
                        _23590 = -1.0f;
                    }
                    else
                    {
                        _23590 = float((_5181[_19964] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5723 = _23590 - 0.100000001490116119384765625f;
                    float2 _23591;
                    if (_8146)
                    {
                        float2 _8343 = clamp((((_19955 + (_5718 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8346 = tan(_8343.x);
                        _23591 = (float2(_8346 / cbFI_DeviceToViewDepth.z, (tan(_8343.y) * sqrt(1.0f + (_8346 * _8346))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23591 = _19955 + (_5718 * cbFI_Timestep);
                    }
                    float _5730 = cbFI_Timestep - 1.0f;
                    float2 _23592;
                    if (_8146)
                    {
                        float2 _8414 = clamp((((_19955 + (_5718 * _5730)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8417 = tan(_8414.x);
                        _23592 = (float2(_8417 / cbFI_DeviceToViewDepth.z, (tan(_8414.y) * sqrt(1.0f + (_8417 * _8417))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23592 = _19955 + (_5718 * _5730);
                    }
                    bool _8450 = all(bool2(_23591.x > 0.0f.xx.x, _23591.y > 0.0f.xx.y));
                    bool _8456;
                    if (_8450)
                    {
                        _8456 = all(bool2(_23591.x < 1.0f.xx.x, _23591.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8456 = _8450;
                    }
                    float _23595;
                    if (_8456)
                    {
                        uint _8463_dummy_parameter;
                        _23595 = max((_5723 - (log(((r_depth_tm1.Load(int3(int2(floor(_23591 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8463_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23595 = 0.0f;
                    }
                    bool _8493 = all(bool2(_23592.x > 0.0f.xx.x, _23592.y > 0.0f.xx.y));
                    bool _8499;
                    if (_8493)
                    {
                        _8499 = all(bool2(_23592.x < 1.0f.xx.x, _23592.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8499 = _8493;
                    }
                    float _23596;
                    if (_8499)
                    {
                        uint _8506_dummy_parameter;
                        _23596 = _23595 + max((_5723 - (log(((r_depth_tp1.Load(int3(int2(floor(_23592 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8506_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23596 = _23595;
                    }
                    float _23648;
                    int2 _23652;
                    float2 _23663;
                    int2 _23674;
                    float2 _23707;
                    float _23832;
                    if (_23596 == 0.0f)
                    {
                        bool _5765 = _5723 > _19965;
                        bool2 _23840 = _5765.xx;
                        _23832 = _23604;
                        _23707 = float2(_23840.x ? _5718.x : _19975.x, _23840.y ? _5718.y : _19975.y);
                        _23674 = int2(_23840.x ? _5712.x : _19969.x, _23840.y ? _5712.y : _19969.y);
                        _23663 = _19967;
                        _23652 = _19966;
                        _23648 = _5765 ? _5723 : _19965;
                    }
                    else
                    {
                        bool _5774 = _23596 < _23604;
                        bool2 _23836 = _5774.xx;
                        _23832 = _5774 ? _23596 : _23604;
                        _23707 = _19975;
                        _23674 = _19969;
                        _23663 = float2(_23836.x ? _5718.x : _19967.x, _23836.y ? _5718.y : _19967.y);
                        _23652 = int2(_23836.x ? _5712.x : _19966.x, _23836.y ? _5712.y : _19966.y);
                        _23648 = _19965;
                    }
                    _23831 = _23832;
                    _23706 = _23707;
                    _23673 = _23674;
                    _23662 = _23663;
                    _23651 = _23652;
                    _23647 = _23648;
                }
                bool _5786 = _19965 < 0.0f;
                bool2 _23846 = _5786.xx;
                int2 _23849 = int2(_23846.x ? _19966.x : _19969.x, _23846.y ? _19966.y : _19969.y);
                _22719 = float3(1.0f, _5677, float(any(bool2(_23849.x != _5605.x, _23849.y != _5605.y))));
                _20200 = _23849;
                _20119 = _5786 ? false : true;
                _19977 = float2(_23846.x ? _19967.x : _19975.x, _23846.y ? _19967.y : _19975.y);
            }
            else
            {
                _22719 = _19492;
                _20200 = _5605;
                _20119 = false;
                _19977 = _8124;
            }
            _22718 = _22719;
            _20199 = _20200;
            _20118 = _20119;
            _19976 = _19977;
        }
        else
        {
            _22718 = 0.0f.xxx;
            _20199 = _5605;
            _20118 = false;
            _19976 = _8124;
        }
        float2 _19978;
        if (_8146)
        {
            float2 _8571 = clamp((((_19955 + (_19976 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8574 = tan(_8571.x);
            _19978 = (float2(_8574 / cbFI_DeviceToViewDepth.z, (tan(_8571.y) * sqrt(1.0f + (_8574 * _8574))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19978 = _19955 + (_19976 * cbFI_Timestep);
        }
        float _5809 = cbFI_Timestep - 1.0f;
        float2 _19980;
        if (_8146)
        {
            float2 _8642 = clamp((((_19955 + (_19976 * _5809)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8645 = tan(_8642.x);
            _19980 = (float2(_8645 / cbFI_DeviceToViewDepth.z, (tan(_8642.y) * sqrt(1.0f + (_8645 * _8645))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19980 = _19955 + (_19976 * _5809);
        }
        float _5814 = -cbFI_Timestep;
        float2 _19981;
        if (_8146)
        {
            float2 _8713 = clamp((((_19955 + (_8118 * _5814)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8716 = tan(_8713.x);
            _19981 = (float2(_8716 / cbFI_DeviceToViewDepth.z, (tan(_8713.y) * sqrt(1.0f + (_8716 * _8716))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19981 = _19955 + (_8118 * _5814);
        }
        float _5819 = 1.0f - cbFI_Timestep;
        float2 _19982;
        if (_8146)
        {
            float2 _8784 = clamp((((_19955 + (_8118 * _5819)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8787 = tan(_8784.x);
            _19982 = (float2(_8787 / cbFI_DeviceToViewDepth.z, (tan(_8784.y) * sqrt(1.0f + (_8787 * _8787))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19982 = _19955 + (_8118 * _5819);
        }
        float4 _8822 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19978, 0.0f);
        float3 _8823 = _8822.xyz;
        float4 _8830 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19980, 0.0f);
        float3 _8831 = _8830.xyz;
        float4 _8838 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19981, 0.0f);
        float3 _8839 = _8838.xyz;
        float4 _8846 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19982, 0.0f);
        float3 _8847 = _8846.xyz;
        float4 _8861 = exp(_8112 - max(max(max(_8112.x, _8112.y), _8112.z), _8112.w).xxxx);
        float4 _8868 = _8861 / (dot(_8861, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5835 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _20189;
        float _21497;
        if (_5835)
        {
            float2 _5841 = 0.5f.xx / _5596;
            float _5844 = _5841.x;
            float _5845 = -_5844;
            float _5847 = _5841.y;
            float _5848 = -_5847;
            float2 _5850 = _5594 + float2(_5845, _5848);
            float2 _5852 = float2(cbFI_DisplaySize);
            bool _19999;
            do
            {
                bool _8948 = all(bool2(_5850.x > 0.0f.xx.x, _5850.y > 0.0f.xx.y));
                bool _8954;
                if (_8948)
                {
                    _8954 = all(bool2(_5850.x < 1.0f.xx.x, _5850.y < 1.0f.xx.y));
                }
                else
                {
                    _8954 = _8948;
                }
                if (!_8954)
                {
                    _19999 = false;
                    break;
                }
                uint _8961_dummy_parameter;
                float4x4 _19997;
                do
                {
                    float4x4 _8975;
                    bool _19996;
                    do
                    {
                        _8975 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19996 = false;
                            break;
                        }
                        uint _9009 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9009 + 32u) * 4 + 0) != 1u)
                        {
                            _19996 = false;
                            break;
                        }
                        uint _19993;
                        _19993 = 0u;
                        for (; _19993 < 4u; _19993++)
                        {
                            for (uint _19994 = 0u; _19994 < 4u; )
                            {
                                _8975[_19993][_19994] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9009 + (_19993 * 4u)) + _19994) * 4 + 0));
                                _19994++;
                                continue;
                            }
                        }
                        _19996 = true;
                        break;
                    } while(false);
                    if (_19996)
                    {
                        _19997 = _8975;
                        break;
                    }
                    _19997 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19998;
                do
                {
                    float _9086 = _5850.x;
                    float _9089 = 1.0f - _5850.y;
                    float4 _9100 = mul(float4((float2(_9086, _9089) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5850 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8961_dummy_parameter))))), 0)).x, 1.0f), _19997);
                    float _9102 = _9100.w;
                    if (!(_9102 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19998 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9115 = ((_9100.xy / _9102.xx) + 1.0f.xx) * 0.5f;
                    _19998 = float2(_9115.x - _9086, _9089 - _9115.y);
                    break;
                } while(false);
                float2 _8912 = abs(_19998);
                if (any(bool2(_8912.x > 100000.0f.xx.x, _8912.y > 100000.0f.xx.y)))
                {
                    _19999 = false;
                    break;
                }
                float _8920 = length(_19998 * _5852);
                uint _9135_dummy_parameter;
                bool _8934 = _8920 > ((8.0f * _5852.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8941;
                if (_8934)
                {
                    _8941 = length((r_motion_tp1.Load(int3(int2(floor(_5850 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9135_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5852) < (0.20000000298023223876953125f * _8920);
                }
                else
                {
                    _8941 = _8934;
                }
                _19999 = _8941;
                break;
            } while(false);
            float2 _5862 = _5594 + float2(_5844, _5848);
            bool _20006;
            do
            {
                bool _9221 = all(bool2(_5862.x > 0.0f.xx.x, _5862.y > 0.0f.xx.y));
                bool _9227;
                if (_9221)
                {
                    _9227 = all(bool2(_5862.x < 1.0f.xx.x, _5862.y < 1.0f.xx.y));
                }
                else
                {
                    _9227 = _9221;
                }
                if (!_9227)
                {
                    _20006 = false;
                    break;
                }
                uint _9234_dummy_parameter;
                float4x4 _20004;
                do
                {
                    float4x4 _9248;
                    bool _20003;
                    do
                    {
                        _9248 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20003 = false;
                            break;
                        }
                        uint _9282 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9282 + 32u) * 4 + 0) != 1u)
                        {
                            _20003 = false;
                            break;
                        }
                        uint _20000;
                        _20000 = 0u;
                        for (; _20000 < 4u; _20000++)
                        {
                            for (uint _20001 = 0u; _20001 < 4u; )
                            {
                                _9248[_20000][_20001] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9282 + (_20000 * 4u)) + _20001) * 4 + 0));
                                _20001++;
                                continue;
                            }
                        }
                        _20003 = true;
                        break;
                    } while(false);
                    if (_20003)
                    {
                        _20004 = _9248;
                        break;
                    }
                    _20004 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _20005;
                do
                {
                    float _9359 = _5862.x;
                    float _9362 = 1.0f - _5862.y;
                    float4 _9373 = mul(float4((float2(_9359, _9362) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5862 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9234_dummy_parameter))))), 0)).x, 1.0f), _20004);
                    float _9375 = _9373.w;
                    if (!(_9375 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20005 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9388 = ((_9373.xy / _9375.xx) + 1.0f.xx) * 0.5f;
                    _20005 = float2(_9388.x - _9359, _9362 - _9388.y);
                    break;
                } while(false);
                float2 _9185 = abs(_20005);
                if (any(bool2(_9185.x > 100000.0f.xx.x, _9185.y > 100000.0f.xx.y)))
                {
                    _20006 = false;
                    break;
                }
                float _9193 = length(_20005 * _5852);
                uint _9408_dummy_parameter;
                bool _9207 = _9193 > ((8.0f * _5852.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9214;
                if (_9207)
                {
                    _9214 = length((r_motion_tp1.Load(int3(int2(floor(_5862 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9408_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5852) < (0.20000000298023223876953125f * _9193);
                }
                else
                {
                    _9214 = _9207;
                }
                _20006 = _9214;
                break;
            } while(false);
            float2 _5875 = _5594 + float2(_5845, _5847);
            bool _20013;
            do
            {
                bool _9494 = all(bool2(_5875.x > 0.0f.xx.x, _5875.y > 0.0f.xx.y));
                bool _9500;
                if (_9494)
                {
                    _9500 = all(bool2(_5875.x < 1.0f.xx.x, _5875.y < 1.0f.xx.y));
                }
                else
                {
                    _9500 = _9494;
                }
                if (!_9500)
                {
                    _20013 = false;
                    break;
                }
                uint _9507_dummy_parameter;
                float4x4 _20011;
                do
                {
                    float4x4 _9521;
                    bool _20010;
                    do
                    {
                        _9521 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20010 = false;
                            break;
                        }
                        uint _9555 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9555 + 32u) * 4 + 0) != 1u)
                        {
                            _20010 = false;
                            break;
                        }
                        uint _20007;
                        _20007 = 0u;
                        for (; _20007 < 4u; _20007++)
                        {
                            for (uint _20008 = 0u; _20008 < 4u; )
                            {
                                _9521[_20007][_20008] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9555 + (_20007 * 4u)) + _20008) * 4 + 0));
                                _20008++;
                                continue;
                            }
                        }
                        _20010 = true;
                        break;
                    } while(false);
                    if (_20010)
                    {
                        _20011 = _9521;
                        break;
                    }
                    _20011 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _20012;
                do
                {
                    float _9632 = _5875.x;
                    float _9635 = 1.0f - _5875.y;
                    float4 _9646 = mul(float4((float2(_9632, _9635) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5875 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9507_dummy_parameter))))), 0)).x, 1.0f), _20011);
                    float _9648 = _9646.w;
                    if (!(_9648 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20012 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9661 = ((_9646.xy / _9648.xx) + 1.0f.xx) * 0.5f;
                    _20012 = float2(_9661.x - _9632, _9635 - _9661.y);
                    break;
                } while(false);
                float2 _9458 = abs(_20012);
                if (any(bool2(_9458.x > 100000.0f.xx.x, _9458.y > 100000.0f.xx.y)))
                {
                    _20013 = false;
                    break;
                }
                float _9466 = length(_20012 * _5852);
                uint _9681_dummy_parameter;
                bool _9480 = _9466 > ((8.0f * _5852.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9487;
                if (_9480)
                {
                    _9487 = length((r_motion_tp1.Load(int3(int2(floor(_5875 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9681_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5852) < (0.20000000298023223876953125f * _9466);
                }
                else
                {
                    _9487 = _9480;
                }
                _20013 = _9487;
                break;
            } while(false);
            float2 _5887 = _5594 + _5841;
            bool _20020;
            do
            {
                bool _9767 = all(bool2(_5887.x > 0.0f.xx.x, _5887.y > 0.0f.xx.y));
                bool _9773;
                if (_9767)
                {
                    _9773 = all(bool2(_5887.x < 1.0f.xx.x, _5887.y < 1.0f.xx.y));
                }
                else
                {
                    _9773 = _9767;
                }
                if (!_9773)
                {
                    _20020 = false;
                    break;
                }
                uint _9780_dummy_parameter;
                float4x4 _20018;
                do
                {
                    float4x4 _9794;
                    bool _20017;
                    do
                    {
                        _9794 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20017 = false;
                            break;
                        }
                        uint _9828 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9828 + 32u) * 4 + 0) != 1u)
                        {
                            _20017 = false;
                            break;
                        }
                        uint _20014;
                        _20014 = 0u;
                        for (; _20014 < 4u; _20014++)
                        {
                            for (uint _20015 = 0u; _20015 < 4u; )
                            {
                                _9794[_20014][_20015] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9828 + (_20014 * 4u)) + _20015) * 4 + 0));
                                _20015++;
                                continue;
                            }
                        }
                        _20017 = true;
                        break;
                    } while(false);
                    if (_20017)
                    {
                        _20018 = _9794;
                        break;
                    }
                    _20018 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _20019;
                do
                {
                    float _9905 = _5887.x;
                    float _9908 = 1.0f - _5887.y;
                    float4 _9919 = mul(float4((float2(_9905, _9908) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5887 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9780_dummy_parameter))))), 0)).x, 1.0f), _20018);
                    float _9921 = _9919.w;
                    if (!(_9921 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20019 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9934 = ((_9919.xy / _9921.xx) + 1.0f.xx) * 0.5f;
                    _20019 = float2(_9934.x - _9905, _9908 - _9934.y);
                    break;
                } while(false);
                float2 _9731 = abs(_20019);
                if (any(bool2(_9731.x > 100000.0f.xx.x, _9731.y > 100000.0f.xx.y)))
                {
                    _20020 = false;
                    break;
                }
                float _9739 = length(_20019 * _5852);
                uint _9954_dummy_parameter;
                bool _9753 = _9739 > ((8.0f * _5852.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9760;
                if (_9753)
                {
                    _9760 = length((r_motion_tp1.Load(int3(int2(floor(_5887 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9954_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5852) < (0.20000000298023223876953125f * _9739);
                }
                else
                {
                    _9760 = _9753;
                }
                _20020 = _9760;
                break;
            } while(false);
            float _5893 = 0.25f * (((float(_19999) + float(_20006)) + float(_20013)) + float(_20020));
            float4 _20190;
            if (_5893 < 1.0f)
            {
                bool _20027;
                do
                {
                    bool _10040 = all(bool2(_19978.x > 0.0f.xx.x, _19978.y > 0.0f.xx.y));
                    bool _10046;
                    if (_10040)
                    {
                        _10046 = all(bool2(_19978.x < 1.0f.xx.x, _19978.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10046 = _10040;
                    }
                    if (!_10046)
                    {
                        _20027 = false;
                        break;
                    }
                    uint _10053_dummy_parameter;
                    float4x4 _20025;
                    do
                    {
                        float4x4 _10067;
                        bool _20024;
                        do
                        {
                            _10067 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20024 = false;
                                break;
                            }
                            uint _10101 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10101 + 32u) * 4 + 0) != 1u)
                            {
                                _20024 = false;
                                break;
                            }
                            uint _20021;
                            _20021 = 0u;
                            for (; _20021 < 4u; _20021++)
                            {
                                for (uint _20022 = 0u; _20022 < 4u; )
                                {
                                    _10067[_20021][_20022] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10101 + (_20021 * 4u)) + _20022) * 4 + 0));
                                    _20022++;
                                    continue;
                                }
                            }
                            _20024 = true;
                            break;
                        } while(false);
                        if (_20024)
                        {
                            _20025 = _10067;
                            break;
                        }
                        _20025 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _20026;
                    do
                    {
                        float _10181 = 1.0f - _19978.y;
                        float4 _10192 = mul(float4((float2(_19978.x, _10181) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19978 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10053_dummy_parameter))))), 0)).x, 1.0f), _20025);
                        float _10194 = _10192.w;
                        if (!(_10194 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20026 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10207 = ((_10192.xy / _10194.xx) + 1.0f.xx) * 0.5f;
                        _20026 = float2(_10207.x - _19978.x, _10181 - _10207.y);
                        break;
                    } while(false);
                    float2 _10004 = abs(_20026);
                    if (any(bool2(_10004.x > 100000.0f.xx.x, _10004.y > 100000.0f.xx.y)))
                    {
                        _20027 = false;
                        break;
                    }
                    float _10012 = length(_20026 * _5852);
                    uint _10227_dummy_parameter;
                    bool _10026 = _10012 > ((8.0f * _5852.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10033;
                    if (_10026)
                    {
                        _10033 = length((r_motion_tp1.Load(int3(int2(floor(_19978 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10227_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5852) < (0.20000000298023223876953125f * _10012);
                    }
                    else
                    {
                        _10033 = _10026;
                    }
                    _20027 = _10033;
                    break;
                } while(false);
                bool _20034;
                do
                {
                    bool _10313 = all(bool2(_19980.x > 0.0f.xx.x, _19980.y > 0.0f.xx.y));
                    bool _10319;
                    if (_10313)
                    {
                        _10319 = all(bool2(_19980.x < 1.0f.xx.x, _19980.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10319 = _10313;
                    }
                    if (!_10319)
                    {
                        _20034 = false;
                        break;
                    }
                    uint _10326_dummy_parameter;
                    float4x4 _20032;
                    do
                    {
                        float4x4 _10340;
                        bool _20031;
                        do
                        {
                            _10340 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20031 = false;
                                break;
                            }
                            uint _10374 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10374 + 32u) * 4 + 0) != 1u)
                            {
                                _20031 = false;
                                break;
                            }
                            uint _20028;
                            _20028 = 0u;
                            for (; _20028 < 4u; _20028++)
                            {
                                for (uint _20029 = 0u; _20029 < 4u; )
                                {
                                    _10340[_20028][_20029] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10374 + (_20028 * 4u)) + _20029) * 4 + 0));
                                    _20029++;
                                    continue;
                                }
                            }
                            _20031 = true;
                            break;
                        } while(false);
                        if (_20031)
                        {
                            _20032 = _10340;
                            break;
                        }
                        _20032 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _20033;
                    do
                    {
                        float _10454 = 1.0f - _19980.y;
                        float4 _10465 = mul(float4((float2(_19980.x, _10454) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19980 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10326_dummy_parameter))))), 0)).x, 1.0f), _20032);
                        float _10467 = _10465.w;
                        if (!(_10467 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20033 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10480 = ((_10465.xy / _10467.xx) + 1.0f.xx) * 0.5f;
                        _20033 = float2(_10480.x - _19980.x, _10454 - _10480.y);
                        break;
                    } while(false);
                    float2 _10277 = abs(_20033);
                    if (any(bool2(_10277.x > 100000.0f.xx.x, _10277.y > 100000.0f.xx.y)))
                    {
                        _20034 = false;
                        break;
                    }
                    float _10285 = length(_20033 * _5852);
                    uint _10500_dummy_parameter;
                    bool _10299 = _10285 > ((8.0f * _5852.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10306;
                    if (_10299)
                    {
                        _10306 = length((r_motion_tp1.Load(int3(int2(floor(_19980 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10500_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5852) < (0.20000000298023223876953125f * _10285);
                    }
                    else
                    {
                        _10306 = _10299;
                    }
                    _20034 = _10306;
                    break;
                } while(false);
                bool _20041;
                do
                {
                    bool _10586 = all(bool2(_19981.x > 0.0f.xx.x, _19981.y > 0.0f.xx.y));
                    bool _10592;
                    if (_10586)
                    {
                        _10592 = all(bool2(_19981.x < 1.0f.xx.x, _19981.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10592 = _10586;
                    }
                    if (!_10592)
                    {
                        _20041 = false;
                        break;
                    }
                    uint _10599_dummy_parameter;
                    float4x4 _20039;
                    do
                    {
                        float4x4 _10613;
                        bool _20038;
                        do
                        {
                            _10613 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20038 = false;
                                break;
                            }
                            uint _10647 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10647 + 32u) * 4 + 0) != 1u)
                            {
                                _20038 = false;
                                break;
                            }
                            uint _20035;
                            _20035 = 0u;
                            for (; _20035 < 4u; _20035++)
                            {
                                for (uint _20036 = 0u; _20036 < 4u; )
                                {
                                    _10613[_20035][_20036] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10647 + (_20035 * 4u)) + _20036) * 4 + 0));
                                    _20036++;
                                    continue;
                                }
                            }
                            _20038 = true;
                            break;
                        } while(false);
                        if (_20038)
                        {
                            _20039 = _10613;
                            break;
                        }
                        _20039 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _20040;
                    do
                    {
                        float _10727 = 1.0f - _19981.y;
                        float4 _10738 = mul(float4((float2(_19981.x, _10727) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19981 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10599_dummy_parameter))))), 0)).x, 1.0f), _20039);
                        float _10740 = _10738.w;
                        if (!(_10740 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20040 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10753 = ((_10738.xy / _10740.xx) + 1.0f.xx) * 0.5f;
                        _20040 = float2(_10753.x - _19981.x, _10727 - _10753.y);
                        break;
                    } while(false);
                    float2 _10550 = abs(_20040);
                    if (any(bool2(_10550.x > 100000.0f.xx.x, _10550.y > 100000.0f.xx.y)))
                    {
                        _20041 = false;
                        break;
                    }
                    float _10558 = length(_20040 * _5852);
                    uint _10773_dummy_parameter;
                    bool _10572 = _10558 > ((8.0f * _5852.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10579;
                    if (_10572)
                    {
                        _10579 = length((r_motion_tp1.Load(int3(int2(floor(_19981 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10773_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5852) < (0.20000000298023223876953125f * _10558);
                    }
                    else
                    {
                        _10579 = _10572;
                    }
                    _20041 = _10579;
                    break;
                } while(false);
                bool _20048;
                do
                {
                    bool _10859 = all(bool2(_19982.x > 0.0f.xx.x, _19982.y > 0.0f.xx.y));
                    bool _10865;
                    if (_10859)
                    {
                        _10865 = all(bool2(_19982.x < 1.0f.xx.x, _19982.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10865 = _10859;
                    }
                    if (!_10865)
                    {
                        _20048 = false;
                        break;
                    }
                    uint _10872_dummy_parameter;
                    float4x4 _20046;
                    do
                    {
                        float4x4 _10886;
                        bool _20045;
                        do
                        {
                            _10886 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20045 = false;
                                break;
                            }
                            uint _10920 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10920 + 32u) * 4 + 0) != 1u)
                            {
                                _20045 = false;
                                break;
                            }
                            uint _20042;
                            _20042 = 0u;
                            for (; _20042 < 4u; _20042++)
                            {
                                for (uint _20043 = 0u; _20043 < 4u; )
                                {
                                    _10886[_20042][_20043] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10920 + (_20042 * 4u)) + _20043) * 4 + 0));
                                    _20043++;
                                    continue;
                                }
                            }
                            _20045 = true;
                            break;
                        } while(false);
                        if (_20045)
                        {
                            _20046 = _10886;
                            break;
                        }
                        _20046 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _20047;
                    do
                    {
                        float _11000 = 1.0f - _19982.y;
                        float4 _11011 = mul(float4((float2(_19982.x, _11000) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19982 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10872_dummy_parameter))))), 0)).x, 1.0f), _20046);
                        float _11013 = _11011.w;
                        if (!(_11013 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20047 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11026 = ((_11011.xy / _11013.xx) + 1.0f.xx) * 0.5f;
                        _20047 = float2(_11026.x - _19982.x, _11000 - _11026.y);
                        break;
                    } while(false);
                    float2 _10823 = abs(_20047);
                    if (any(bool2(_10823.x > 100000.0f.xx.x, _10823.y > 100000.0f.xx.y)))
                    {
                        _20048 = false;
                        break;
                    }
                    float _10831 = length(_20047 * _5852);
                    uint _11046_dummy_parameter;
                    bool _10845 = _10831 > ((8.0f * _5852.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10852;
                    if (_10845)
                    {
                        _10852 = length((r_motion_tp1.Load(int3(int2(floor(_19982 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _11046_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5852) < (0.20000000298023223876953125f * _10831);
                    }
                    else
                    {
                        _10852 = _10845;
                    }
                    _20048 = _10852;
                    break;
                } while(false);
                float4 _5920 = _8868 * float4(_20027 ? 0.0f : 1.0f, _20034 ? 0.0f : 1.0f, _20041 ? 0.0f : 1.0f, _20048 ? 0.0f : 1.0f);
                float _5922 = dot(_5920, 1.0f.xxxx);
                float4 _20191;
                if (_5922 > 0.001000000047497451305389404296875f)
                {
                    _20191 = _5920 / _5922.xxxx;
                }
                else
                {
                    _20191 = _8868;
                }
                _20190 = _20191;
            }
            else
            {
                _20190 = _8868;
            }
            _21497 = _5893;
            _20189 = _20190;
        }
        else
        {
            _21497 = 0.0f;
            _20189 = _8868;
        }
        bool _5939 = _5631 && (!_20118);
        bool _5948;
        if (_5939)
        {
            _5948 = (_20189.z + _20189.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5948 = _5939;
        }
        bool _5959;
        if (_5948)
        {
            _5959 = length((_19981 - _19978) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5959 = _5948;
        }
        bool _20278;
        if (_5959)
        {
            uint4 _11075 = r_warped_motion_qdata_tp1.Load(int3(_20199, 0));
            uint _11076 = _11075.x;
            bool _20281;
            if (_11076 != 0u)
            {
                float _20267;
                if (_11076 == 0u)
                {
                    _20267 = -1.0f;
                }
                else
                {
                    _20267 = float((_11076 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5969 = _20267 - 0.12000000476837158203125f;
                bool _11095 = all(bool2(_19981.x > 0.0f.xx.x, _19981.y > 0.0f.xx.y));
                bool _11101;
                if (_11095)
                {
                    _11101 = all(bool2(_19981.x < 1.0f.xx.x, _19981.y < 1.0f.xx.y));
                }
                else
                {
                    _11101 = _11095;
                }
                bool _5979;
                if (_11101)
                {
                    uint _11108_dummy_parameter;
                    _5979 = (log(((r_depth_tm1.Load(int3(int2(floor(_19981 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11108_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5969;
                }
                else
                {
                    _5979 = _11101;
                }
                bool _5993;
                if (!_5979)
                {
                    bool _11138 = all(bool2(_19982.x > 0.0f.xx.x, _19982.y > 0.0f.xx.y));
                    bool _11144;
                    if (_11138)
                    {
                        _11144 = all(bool2(_19982.x < 1.0f.xx.x, _19982.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11144 = _11138;
                    }
                    bool _5991;
                    if (_11144)
                    {
                        uint _11151_dummy_parameter;
                        _5991 = (log(((r_depth_tp1.Load(int3(int2(floor(_19982 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11151_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5969;
                    }
                    else
                    {
                        _5991 = _11144;
                    }
                    _5993 = _5991;
                }
                else
                {
                    _5993 = _5979;
                }
                _20281 = _5993;
            }
            else
            {
                _20281 = false;
            }
            _20278 = _20281;
        }
        else
        {
            _20278 = false;
        }
        bool _5998 = _20118 || _20278;
        bool _6003;
        if (_5998)
        {
            bool _11181 = all(bool2(_19978.x > 0.0f.xx.x, _19978.y > 0.0f.xx.y));
            bool _11187;
            if (_11181)
            {
                _11187 = all(bool2(_19978.x < 1.0f.xx.x, _19978.y < 1.0f.xx.y));
            }
            else
            {
                _11187 = _11181;
            }
            _6003 = _11187;
        }
        else
        {
            _6003 = _5998;
        }
        bool _6008;
        if (_6003)
        {
            bool _11192 = all(bool2(_19980.x > 0.0f.xx.x, _19980.y > 0.0f.xx.y));
            bool _11198;
            if (_11192)
            {
                _11198 = all(bool2(_19980.x < 1.0f.xx.x, _19980.y < 1.0f.xx.y));
            }
            else
            {
                _11198 = _11192;
            }
            _6008 = _11198;
        }
        else
        {
            _6008 = _6003;
        }
        float4 _20401;
        if (_6008)
        {
            float _6014 = _20189.x + _20189.y;
            float _6019 = _20189.z + _20189.w;
            float _20296;
            if (_6014 > 0.001000000047497451305389404296875f)
            {
                _20296 = _20189.x / _6014;
            }
            else
            {
                _20296 = _5819;
            }
            _20401 = float4(_20189.x + (_6019 * _20296), _20189.y + (_6019 * (1.0f - _20296)), 0.0f, 0.0f);
        }
        else
        {
            _20401 = _20189;
        }
        bool _11226 = (cbFI_pad0 & 1024u) != 0u;
        bool _11202 = !_11226;
        bool _11203 = !_11202;
        bool _11220;
        if (_11203)
        {
            _11220 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_20199.y * cbFI_MvDepthLaneSize.x) + _20199.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11220 = _11202;
        }
        bool _11252;
        if (_11203)
        {
            _11252 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5610.y * cbFI_FlowLaneSize.x) + _5610.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11252 = _11202;
        }
        float _6054 = float(_11252);
        bool _20422;
        float4 _20461;
        float3 _22408;
        if (_11226)
        {
            bool _6064;
            if (_11220)
            {
                _6064 = all(bool2(_19978.x > 0.0f.xx.x, _19978.y > 0.0f.xx.y));
            }
            else
            {
                _6064 = _11220;
            }
            bool _6070;
            if (_6064)
            {
                _6070 = all(bool2(_19978.x < 1.0f.xx.x, _19978.y < 1.0f.xx.y));
            }
            else
            {
                _6070 = _6064;
            }
            bool _6077;
            if (_11220)
            {
                _6077 = all(bool2(_19980.x > 0.0f.xx.x, _19980.y > 0.0f.xx.y));
            }
            else
            {
                _6077 = _11220;
            }
            bool _6083;
            if (_6077)
            {
                _6083 = all(bool2(_19980.x < 1.0f.xx.x, _19980.y < 1.0f.xx.y));
            }
            else
            {
                _6083 = _6077;
            }
            bool _6090;
            if (_11252)
            {
                _6090 = all(bool2(_19981.x > 0.0f.xx.x, _19981.y > 0.0f.xx.y));
            }
            else
            {
                _6090 = _11252;
            }
            bool _6096;
            if (_6090)
            {
                _6096 = all(bool2(_19981.x < 1.0f.xx.x, _19981.y < 1.0f.xx.y));
            }
            else
            {
                _6096 = _6090;
            }
            bool _6103;
            if (_11252)
            {
                _6103 = all(bool2(_19982.x > 0.0f.xx.x, _19982.y > 0.0f.xx.y));
            }
            else
            {
                _6103 = _11252;
            }
            bool _6109;
            if (_6103)
            {
                _6109 = all(bool2(_19982.x < 1.0f.xx.x, _19982.y < 1.0f.xx.y));
            }
            else
            {
                _6109 = _6103;
            }
            bool _6111 = !_11220;
            if (_6111)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11294;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11294);
                }
            }
            bool _6116 = !_11252;
            if (_6116)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11304;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11304);
                }
            }
            if (_11220 && _6116)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11314;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11314);
                }
            }
            if (_6111 && _11252)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11324;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11324);
                }
            }
            float _6135 = float(_6070);
            float _6137 = float(_6083);
            bool _6140 = _6096 && _6109;
            float _20330;
            if (_6140)
            {
                _20330 = 1.0f;
            }
            else
            {
                _20330 = (_6096 || _6109) ? 0.5f : 0.0f;
            }
            bool _20345;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_6070)) && (!_6083))
            {
                bool _6170;
                if (_6140)
                {
                    float _20338;
                    do
                    {
                        bool _11408 = all(bool2(_19981.x > 0.0f.xx.x, _19981.y > 0.0f.xx.y));
                        bool _11414;
                        if (_11408)
                        {
                            _11414 = all(bool2(_19981.x < 1.0f.xx.x, _19981.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11414 = _11408;
                        }
                        bool _11345 = !_11414;
                        bool _11352;
                        if (!_11345)
                        {
                            bool _11419 = all(bool2(_19982.x > 0.0f.xx.x, _19982.y > 0.0f.xx.y));
                            bool _11425;
                            if (_11419)
                            {
                                _11425 = all(bool2(_19982.x < 1.0f.xx.x, _19982.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11425 = _11419;
                            }
                            _11352 = !_11425;
                        }
                        else
                        {
                            _11352 = _11345;
                        }
                        if (_11352)
                        {
                            _20338 = 0.0f;
                            break;
                        }
                        uint _11432_dummy_parameter;
                        uint _11448_dummy_parameter;
                        float4x4 _20337;
                        do
                        {
                            float4x4 _11462;
                            bool _20336;
                            do
                            {
                                _11462 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20336 = false;
                                    break;
                                }
                                uint _11496 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11496 + 32u) * 4 + 0) != 1u)
                                {
                                    _20336 = false;
                                    break;
                                }
                                uint _20333;
                                _20333 = 0u;
                                for (; _20333 < 4u; _20333++)
                                {
                                    for (uint _20334 = 0u; _20334 < 4u; )
                                    {
                                        _11462[_20333][_20334] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11496 + 16u) + (_20333 * 4u)) + _20334) * 4 + 0));
                                        _20334++;
                                        continue;
                                    }
                                }
                                _20336 = true;
                                break;
                            } while(false);
                            if (_20336)
                            {
                                _20337 = _11462;
                                break;
                            }
                            _20337 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11373 = mul(float4((float2(_19981.x, 1.0f - _19981.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19981 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11432_dummy_parameter))))), 0)).x, 1.0f), _20337);
                        float _11375 = _11373.w;
                        if (abs(_11375) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20338 = 0.0f;
                            break;
                        }
                        float _11386 = abs(cbFI_DeviceToViewDepth.y / ((_11373.z / _11375) - cbFI_DeviceToViewDepth.x));
                        float _11389 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19982 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11448_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20338 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11386 - _11389) / max(max(_11386, _11389), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _6170 = _20338 >= 0.5f;
                }
                else
                {
                    _6170 = _6140;
                }
                bool _6178;
                if (_6170)
                {
                    _6178 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _6178 = _6170;
                }
                bool _20346;
                if (_6178)
                {
                    uint _11600_dummy_parameter;
                    float4x4 _20343;
                    do
                    {
                        float4x4 _11614;
                        bool _20342;
                        do
                        {
                            _11614 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20342 = false;
                                break;
                            }
                            uint _11648 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11648 + 32u) * 4 + 0) != 1u)
                            {
                                _20342 = false;
                                break;
                            }
                            uint _20339;
                            _20339 = 0u;
                            for (; _20339 < 4u; _20339++)
                            {
                                for (uint _20340 = 0u; _20340 < 4u; )
                                {
                                    _11614[_20339][_20340] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11648 + 16u) + (_20339 * 4u)) + _20340) * 4 + 0));
                                    _20340++;
                                    continue;
                                }
                            }
                            _20342 = true;
                            break;
                        } while(false);
                        if (_20342)
                        {
                            _20343 = _11614;
                            break;
                        }
                        _20343 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20344;
                    do
                    {
                        float _11728 = 1.0f - _19981.y;
                        float4 _11739 = mul(float4((float2(_19981.x, _11728) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19981 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11600_dummy_parameter))))), 0)).x, 1.0f), _20343);
                        float _11741 = _11739.w;
                        if (!(_11741 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20344 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11754 = ((_11739.xy / _11741.xx) + 1.0f.xx) * 0.5f;
                        _20344 = float2(_11754.x - _19981.x, _11728 - _11754.y);
                        break;
                    } while(false);
                    float2 _6191 = float2(cbFI_DisplaySize);
                    _20346 = length(((_19981 + _20344) - _19982) * _6191) <= ((0.100000001490116119384765625f * length(_20344 * _6191)) + 8.0f);
                }
                else
                {
                    _20346 = _6170;
                }
                _20345 = _20346;
            }
            else
            {
                _20345 = true;
            }
            bool _6205 = !_20345;
            bool _23850 = _6205 ? false : _6109;
            bool _23851 = _6205 ? false : _6096;
            bool _20423;
            float4 _20462;
            if (!(((_6070 && _6083) && _23851) && _23850))
            {
                float4 _6227 = _20401 * float4(_6135, _6137, float(_23851), float(_23850));
                float _6229 = dot(_6227, 1.0f.xxxx);
                bool _6232 = !(_6229 > 0.0f);
                float4 _20463;
                if (!_6232)
                {
                    _20463 = _6227 / _6229.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11776;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11776);
                    }
                    _20463 = 0.0f.xxxx;
                }
                _20462 = _20463;
                _20423 = _6232;
            }
            else
            {
                _20462 = _20401;
                _20423 = false;
            }
            _22408 = float3(_6135, _6137, _20330);
            _20461 = _20462;
            _20422 = _20423;
        }
        else
        {
            _22408 = float3(float(_11220), _6054, 0.0f);
            _20461 = _20401;
            _20422 = false;
        }
        bool _6250 = !_20422;
        float4 _20554;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6250)
        {
            float _6257 = _20461.x + _20461.y;
            float4 _20555;
            if (_6257 > 0.001000000047497451305389404296875f)
            {
                _20555 = float4(_20461.x / _6257, _20461.y / _6257, 0.0f, 0.0f);
            }
            else
            {
                _20555 = float4(_5819, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20554 = _20555;
        }
        else
        {
            _20554 = _20461;
        }
        float4 _20731;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6250) && _11220)
        {
            float _20528;
            do
            {
                uint4 _11916 = r_warped_motion_qdata_tp1.Load(int3(_20199, 0));
                uint _11917 = _11916.x;
                if (_11917 != 0u)
                {
                    float _20527;
                    if (_11917 == 0u)
                    {
                        _20527 = -1.0f;
                    }
                    else
                    {
                        _20527 = float((_11917 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20528 = _20527;
                    break;
                }
                int _20510;
                uint _20511;
                _20511 = _11917;
                _20510 = -1;
                uint _20526;
                for (; _20510 <= 1; _20511 = _20526, _20510++)
                {
                    _20526 = _20511;
                    for (int _20524 = -1; _20524 <= 1; )
                    {
                        _20526 = max(_20526, r_warped_motion_qdata_tp1.Load(int3(clamp(_20199 + int2(_20524, _20510), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20524++;
                        continue;
                    }
                }
                if (_20511 != 0u)
                {
                    float _20523;
                    if (_20511 == 0u)
                    {
                        _20523 = -1.0f;
                    }
                    else
                    {
                        _20523 = float((_20511 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20528 = _20523;
                    break;
                }
                uint _20513;
                _20513 = 4294967295u;
                uint _23743;
                for (int _20512 = 0; _20512 < 8; _20513 = _23743, _20512++)
                {
                    int _20516 = 0;
                    for (;;)
                    {
                        if (_20516 < 5)
                        {
                            int2 _11867 = _20199 + (_1251[_20512] * _1260[_20516].xx);
                            bool _11870 = any(bool2(_11867.x < int2(0, 0).x, _11867.y < int2(0, 0).y));
                            bool _11878;
                            if (!_11870)
                            {
                                _11878 = any(bool2(_11867.x >= cbFI_MvDepthLaneSize.x, _11867.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11878 = _11870;
                            }
                            if (_11878)
                            {
                                _23743 = _20513;
                                break;
                            }
                            uint4 _11956 = r_warped_motion_qdata_tp1.Load(int3(_11867, 0));
                            uint _11957 = _11956.x;
                            if (_11957 != 0u)
                            {
                                _23743 = min(_20513, _11957);
                                break;
                            }
                            _20516++;
                            continue;
                        }
                        else
                        {
                            _23743 = _20513;
                            break;
                        }
                    }
                }
                float _20515;
                if (_20513 == 4294967295u)
                {
                    _20515 = -1.0f;
                }
                else
                {
                    float _20514;
                    if (_20513 == 0u)
                    {
                        _20514 = -1.0f;
                    }
                    else
                    {
                        _20514 = float((_20513 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20515 = _20514;
                }
                _20528 = _20515;
                break;
            } while(false);
            float _6293 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6296 = r_warped_motion_qdata_tp1.Load(int3(_20199, 0)).x == 0u;
            bool _6302;
            if (_6296)
            {
                bool _11982 = all(bool2(_19978.x > 0.0f.xx.x, _19978.y > 0.0f.xx.y));
                bool _11988;
                if (_11982)
                {
                    _11988 = all(bool2(_19978.x < 1.0f.xx.x, _19978.y < 1.0f.xx.y));
                }
                else
                {
                    _11988 = _11982;
                }
                _6302 = _11988;
            }
            else
            {
                _6302 = _6296;
            }
            bool _6307;
            if (_6302)
            {
                bool _11993 = all(bool2(_19980.x > 0.0f.xx.x, _19980.y > 0.0f.xx.y));
                bool _11999;
                if (_11993)
                {
                    _11999 = all(bool2(_19980.x < 1.0f.xx.x, _19980.y < 1.0f.xx.y));
                }
                else
                {
                    _11999 = _11993;
                }
                _6307 = _11999;
            }
            else
            {
                _6307 = _6302;
            }
            bool _20540;
            float4 _20549;
            if (_6307)
            {
                uint _12006_dummy_parameter;
                float _12030 = log(((r_depth_tm1.Load(int3(int2(floor(_19978 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12006_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _12038_dummy_parameter;
                float _12062 = log(((r_depth_tp1.Load(int3(int2(floor(_19980 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12038_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _6318 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6325;
                if (_6318)
                {
                    _6325 = _12062 > (_12030 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6325 = _6318;
                }
                bool _20545;
                float4 _20567;
                if (_6325)
                {
                    _20567 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20545 = true;
                }
                else
                {
                    bool _6331 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6338;
                    if (_6331)
                    {
                        _6338 = _12030 > (_12062 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6338 = _6331;
                    }
                    bool4 _23852 = _6338.xxxx;
                    _20567 = float4(_23852.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20554.x, _23852.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20554.y, _23852.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20554.z, _23852.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20554.w);
                    _20545 = _6338 ? true : false;
                }
                _20549 = _20567;
                _20540 = _20545;
            }
            else
            {
                _20549 = _20554;
                _20540 = false;
            }
            float4 _20622;
            if (_20540)
            {
                _20622 = 1.0f.xxxx;
            }
            else
            {
                bool _6349 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6355;
                if (_6349)
                {
                    _6355 = _20549.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6355 = _6349;
                }
                bool _6360;
                if (_6355)
                {
                    bool _12068 = all(bool2(_19980.x > 0.0f.xx.x, _19980.y > 0.0f.xx.y));
                    bool _12074;
                    if (_12068)
                    {
                        _12074 = all(bool2(_19980.x < 1.0f.xx.x, _19980.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12074 = _12068;
                    }
                    _6360 = _12074;
                }
                else
                {
                    _6360 = _6355;
                }
                float4 _20623;
                if (_6360)
                {
                    float _20576;
                    if (_20528 >= 0.0f)
                    {
                        _20576 = _20528 - _6293;
                    }
                    else
                    {
                        float _20572;
                        _20572 = 2.0f;
                        float _12131;
                        for (int _20571 = 0; _20571 < 24; _20572 = _12131, _20571++)
                        {
                            float _12095 = float(_20571 & 7) * 0.785398185253143310546875f;
                            int _12097 = _20571 >> 3;
                            int _20573;
                            if (_12097 == 0)
                            {
                                _20573 = 16;
                            }
                            else
                            {
                                _20573 = (_12097 == 1) ? 48 : 96;
                            }
                            uint _12163_dummy_parameter;
                            _12131 = min(_20572, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19980 + ((cbFI_MvDepthLaneSizeRcp * float(_20573)) * float2(cos(_12095), sin(_12095))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12163_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20576 = _20572;
                    }
                    uint _12195_dummy_parameter;
                    float4 _20624;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_19980 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12195_dummy_parameter))))), 0)).x) > ((exp((_20576 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20624 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20624 = 1.0f.xxxx;
                    }
                    _20623 = _20624;
                }
                else
                {
                    _20623 = 1.0f.xxxx;
                }
                _20622 = _20623;
            }
            bool _6388 = _20528 >= 0.0f;
            bool _6389 = (!_20540) && _6388;
            bool _6396;
            if (_6389)
            {
                _6396 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6396 = _6389;
            }
            bool _6402;
            if (_6396)
            {
                _6402 = _20549.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6402 = _6396;
            }
            bool _6407;
            if (_6402)
            {
                bool _12220 = all(bool2(_19978.x > 0.0f.xx.x, _19978.y > 0.0f.xx.y));
                bool _12226;
                if (_12220)
                {
                    _12226 = all(bool2(_19978.x < 1.0f.xx.x, _19978.y < 1.0f.xx.y));
                }
                else
                {
                    _12226 = _12220;
                }
                _6407 = _12226;
            }
            else
            {
                _6407 = _6402;
            }
            float4 _20647;
            if (_6407)
            {
                float _20616;
                if (_6388)
                {
                    _20616 = _20528 - _6293;
                }
                else
                {
                    float _20612;
                    _20612 = 2.0f;
                    float _12283;
                    for (int _20611 = 0; _20611 < 24; _20612 = _12283, _20611++)
                    {
                        float _12247 = float(_20611 & 7) * 0.785398185253143310546875f;
                        int _12249 = _20611 >> 3;
                        int _20613;
                        if (_12249 == 0)
                        {
                            _20613 = 16;
                        }
                        else
                        {
                            _20613 = (_12249 == 1) ? 48 : 96;
                        }
                        uint _12299_dummy_parameter;
                        _12283 = min(_20612, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19978 + ((cbFI_MvDepthLaneSizeRcp * float(_20613)) * float2(cos(_12247), sin(_12247))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12299_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20616 = _20612;
                }
                uint _12347_dummy_parameter;
                float4 _20648;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_19978 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12347_dummy_parameter))))), 0)).x) > ((exp((_20616 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19644 = _20622;
                    _19644.x = 0.0f;
                    _20648 = _19644;
                }
                else
                {
                    _20648 = _20622;
                }
                _20647 = _20648;
            }
            else
            {
                _20647 = _20622;
            }
            float4 _20660;
            if (_6389)
            {
                float _12374 = (exp(((_20528 - _6293) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6445 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6451;
                if (_6445)
                {
                    _6451 = _20549.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6451 = _6445;
                }
                bool _6456;
                if (_6451)
                {
                    bool _12379 = all(bool2(_19982.x > 0.0f.xx.x, _19982.y > 0.0f.xx.y));
                    bool _12385;
                    if (_12379)
                    {
                        _12385 = all(bool2(_19982.x < 1.0f.xx.x, _19982.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12385 = _12379;
                    }
                    _6456 = _12385;
                }
                else
                {
                    _6456 = _6451;
                }
                bool _6464;
                if (_6456)
                {
                    uint _12392_dummy_parameter;
                    _6464 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19982 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12392_dummy_parameter))))), 0)).x) > _12374;
                }
                else
                {
                    _6464 = _6456;
                }
                float4 _20658;
                if (_6464)
                {
                    float4 _19647 = _20647;
                    _19647.w = 0.0f;
                    _20658 = _19647;
                }
                else
                {
                    _20658 = _20647;
                }
                bool _6471 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6477;
                if (_6471)
                {
                    _6477 = _20549.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6477 = _6471;
                }
                bool _6482;
                if (_6477)
                {
                    bool _12410 = all(bool2(_19981.x > 0.0f.xx.x, _19981.y > 0.0f.xx.y));
                    bool _12416;
                    if (_12410)
                    {
                        _12416 = all(bool2(_19981.x < 1.0f.xx.x, _19981.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12416 = _12410;
                    }
                    _6482 = _12416;
                }
                else
                {
                    _6482 = _6477;
                }
                bool _6490;
                if (_6482)
                {
                    uint _12423_dummy_parameter;
                    _6490 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19981 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12423_dummy_parameter))))), 0)).x) > _12374;
                }
                else
                {
                    _6490 = _6482;
                }
                float4 _20661;
                if (_6490)
                {
                    float4 _19650 = _20658;
                    _19650.z = 0.0f;
                    _20661 = _19650;
                }
                else
                {
                    _20661 = _20658;
                }
                _20660 = _20661;
            }
            else
            {
                _20660 = _20647;
            }
            float4 _20732;
            if (any(bool4(_20660.x < 1.0f.xxxx.x, _20660.y < 1.0f.xxxx.y, _20660.z < 1.0f.xxxx.z, _20660.w < 1.0f.xxxx.w)))
            {
                float4 _6501 = _20549 * _20660;
                float _6503 = dot(_6501, 1.0f.xxxx);
                float4 _20733;
                if (_6503 > 0.0f)
                {
                    _20733 = _6501 / _6503.xxxx;
                }
                else
                {
                    bool _6514 = _20660.y == 0.0f;
                    bool _6520;
                    if (_6514)
                    {
                        _6520 = _20660.x > 0.0f;
                    }
                    else
                    {
                        _6520 = _6514;
                    }
                    bool _6525;
                    if (_6520)
                    {
                        bool _12441 = all(bool2(_19978.x > 0.0f.xx.x, _19978.y > 0.0f.xx.y));
                        bool _12447;
                        if (_12441)
                        {
                            _12447 = all(bool2(_19978.x < 1.0f.xx.x, _19978.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12447 = _12441;
                        }
                        _6525 = _12447;
                    }
                    else
                    {
                        _6525 = _6520;
                    }
                    float4 _20734;
                    if (_6525)
                    {
                        _20734 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6530 = _20660.x == 0.0f;
                        bool _6536;
                        if (_6530)
                        {
                            _6536 = _20660.y > 0.0f;
                        }
                        else
                        {
                            _6536 = _6530;
                        }
                        bool _6541;
                        if (_6536)
                        {
                            bool _12452 = all(bool2(_19980.x > 0.0f.xx.x, _19980.y > 0.0f.xx.y));
                            bool _12458;
                            if (_12452)
                            {
                                _12458 = all(bool2(_19980.x < 1.0f.xx.x, _19980.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12458 = _12452;
                            }
                            _6541 = _12458;
                        }
                        else
                        {
                            _6541 = _6536;
                        }
                        bool4 _23855 = _6541.xxxx;
                        _20734 = float4(_23855.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20549.x, _23855.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20549.y, _23855.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20549.z, _23855.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20549.w);
                    }
                    _20733 = _20734;
                }
                _20732 = _20733;
            }
            else
            {
                _20732 = _20549;
            }
            _20731 = _20732;
        }
        else
        {
            _20731 = _20554;
        }
        float4 _21461;
        bool _21767;
        float3 _22104;
        if (((cbFI_pad0 & 32768u) != 0u) && _6250)
        {
            bool _6558 = _20731.x > 0.00999999977648258209228515625f;
            bool _6561 = _20731.y > 0.00999999977648258209228515625f;
            bool _6570 = (_20731.z + _20731.w) > 0.0199999995529651641845703125f;
            bool _6576;
            if (_6570)
            {
                bool _12463 = all(bool2(_19981.x > 0.0f.xx.x, _19981.y > 0.0f.xx.y));
                bool _12469;
                if (_12463)
                {
                    _12469 = all(bool2(_19981.x < 1.0f.xx.x, _19981.y < 1.0f.xx.y));
                }
                else
                {
                    _12469 = _12463;
                }
                _6576 = _12469;
            }
            else
            {
                _6576 = _6570;
            }
            bool _6581;
            if (_6576)
            {
                bool _12474 = all(bool2(_19982.x > 0.0f.xx.x, _19982.y > 0.0f.xx.y));
                bool _12480;
                if (_12474)
                {
                    _12480 = all(bool2(_19982.x < 1.0f.xx.x, _19982.y < 1.0f.xx.y));
                }
                else
                {
                    _12480 = _12474;
                }
                _6581 = _12480;
            }
            else
            {
                _6581 = _6576;
            }
            bool _6588;
            if (_6581)
            {
                float _20747;
                do
                {
                    bool _12563 = all(bool2(_19981.x > 0.0f.xx.x, _19981.y > 0.0f.xx.y));
                    bool _12569;
                    if (_12563)
                    {
                        _12569 = all(bool2(_19981.x < 1.0f.xx.x, _19981.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12569 = _12563;
                    }
                    bool _12500 = !_12569;
                    bool _12507;
                    if (!_12500)
                    {
                        bool _12574 = all(bool2(_19982.x > 0.0f.xx.x, _19982.y > 0.0f.xx.y));
                        bool _12580;
                        if (_12574)
                        {
                            _12580 = all(bool2(_19982.x < 1.0f.xx.x, _19982.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12580 = _12574;
                        }
                        _12507 = !_12580;
                    }
                    else
                    {
                        _12507 = _12500;
                    }
                    if (_12507)
                    {
                        _20747 = 0.0f;
                        break;
                    }
                    uint _12587_dummy_parameter;
                    uint _12603_dummy_parameter;
                    float4x4 _20746;
                    do
                    {
                        float4x4 _12617;
                        bool _20745;
                        do
                        {
                            _12617 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20745 = false;
                                break;
                            }
                            uint _12651 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12651 + 32u) * 4 + 0) != 1u)
                            {
                                _20745 = false;
                                break;
                            }
                            uint _20742;
                            _20742 = 0u;
                            for (; _20742 < 4u; _20742++)
                            {
                                for (uint _20743 = 0u; _20743 < 4u; )
                                {
                                    _12617[_20742][_20743] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12651 + 16u) + (_20742 * 4u)) + _20743) * 4 + 0));
                                    _20743++;
                                    continue;
                                }
                            }
                            _20745 = true;
                            break;
                        } while(false);
                        if (_20745)
                        {
                            _20746 = _12617;
                            break;
                        }
                        _20746 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12528 = mul(float4((float2(_19981.x, 1.0f - _19981.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19981 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12587_dummy_parameter))))), 0)).x, 1.0f), _20746);
                    float _12530 = _12528.w;
                    if (abs(_12530) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20747 = 0.0f;
                        break;
                    }
                    float _12541 = abs(cbFI_DeviceToViewDepth.y / ((_12528.z / _12530) - cbFI_DeviceToViewDepth.x));
                    float _12544 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19982 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12603_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20747 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12541 - _12544) / max(max(_12541, _12544), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6588 = _20747 < 0.5f;
            }
            else
            {
                _6588 = _6581;
            }
            float4 _20766;
            if (_6588)
            {
                uint _12755_dummy_parameter;
                uint _12786_dummy_parameter;
                float4 _20767;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19981 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12755_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19982 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12786_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20767 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20767 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20766 = _20767;
            }
            else
            {
                _20766 = 1.0f.xxxx;
            }
            bool _6612;
            if (_11220)
            {
                bool _12815 = all(bool2(_19978.x > 0.0f.xx.x, _19978.y > 0.0f.xx.y));
                bool _12821;
                if (_12815)
                {
                    _12821 = all(bool2(_19978.x < 1.0f.xx.x, _19978.y < 1.0f.xx.y));
                }
                else
                {
                    _12821 = _12815;
                }
                _6612 = _12821;
            }
            else
            {
                _6612 = _11220;
            }
            bool _6618;
            if (_11220)
            {
                bool _12826 = all(bool2(_19980.x > 0.0f.xx.x, _19980.y > 0.0f.xx.y));
                bool _12832;
                if (_12826)
                {
                    _12832 = all(bool2(_19980.x < 1.0f.xx.x, _19980.y < 1.0f.xx.y));
                }
                else
                {
                    _12832 = _12826;
                }
                _6618 = _12832;
            }
            else
            {
                _6618 = _11220;
            }
            bool _6624;
            if (_11252)
            {
                bool _12837 = all(bool2(_19981.x > 0.0f.xx.x, _19981.y > 0.0f.xx.y));
                bool _12843;
                if (_12837)
                {
                    _12843 = all(bool2(_19981.x < 1.0f.xx.x, _19981.y < 1.0f.xx.y));
                }
                else
                {
                    _12843 = _12837;
                }
                _6624 = _12843;
            }
            else
            {
                _6624 = _11252;
            }
            bool _6630;
            if (_11252)
            {
                bool _12848 = all(bool2(_19982.x > 0.0f.xx.x, _19982.y > 0.0f.xx.y));
                bool _12854;
                if (_12848)
                {
                    _12854 = all(bool2(_19982.x < 1.0f.xx.x, _19982.y < 1.0f.xx.y));
                }
                else
                {
                    _12854 = _12848;
                }
                _6630 = _12854;
            }
            else
            {
                _6630 = _11252;
            }
            bool _6633 = _6624 != _6630;
            bool _6639;
            if (_6633)
            {
                _6639 = _6612 || _6618;
            }
            else
            {
                _6639 = _6633;
            }
            float4 _20869;
            if (_6639)
            {
                float4 _19677 = _20766;
                _19677.z = 0.0f;
                _19677.w = 0.0f;
                _20869 = _19677;
            }
            else
            {
                _20869 = _20766;
            }
            bool _6646 = _6612 && _6558;
            bool _6649 = _6618 && _6561;
            float4 _20974;
            float3 _22213;
            if (_6646 || _6649)
            {
                float _20864;
                do
                {
                    uint4 _12993 = r_warped_motion_qdata_tp1.Load(int3(_20199, 0));
                    uint _12994 = _12993.x;
                    if (_12994 != 0u)
                    {
                        float _20863;
                        if (_12994 == 0u)
                        {
                            _20863 = -1.0f;
                        }
                        else
                        {
                            _20863 = float((_12994 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20864 = _20863;
                        break;
                    }
                    int _20846;
                    uint _20847;
                    _20847 = _12994;
                    _20846 = -1;
                    uint _20862;
                    for (; _20846 <= 1; _20847 = _20862, _20846++)
                    {
                        _20862 = _20847;
                        for (int _20860 = -1; _20860 <= 1; )
                        {
                            _20862 = max(_20862, r_warped_motion_qdata_tp1.Load(int3(clamp(_20199 + int2(_20860, _20846), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20860++;
                            continue;
                        }
                    }
                    if (_20847 != 0u)
                    {
                        float _20859;
                        if (_20847 == 0u)
                        {
                            _20859 = -1.0f;
                        }
                        else
                        {
                            _20859 = float((_20847 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20864 = _20859;
                        break;
                    }
                    uint _20849;
                    _20849 = 4294967295u;
                    uint _23744;
                    for (int _20848 = 0; _20848 < 8; _20849 = _23744, _20848++)
                    {
                        int _20852 = 0;
                        for (;;)
                        {
                            if (_20852 < 5)
                            {
                                int2 _12944 = _20199 + (_1251[_20848] * _1260[_20852].xx);
                                bool _12947 = any(bool2(_12944.x < int2(0, 0).x, _12944.y < int2(0, 0).y));
                                bool _12955;
                                if (!_12947)
                                {
                                    _12955 = any(bool2(_12944.x >= cbFI_MvDepthLaneSize.x, _12944.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12955 = _12947;
                                }
                                if (_12955)
                                {
                                    _23744 = _20849;
                                    break;
                                }
                                uint4 _13033 = r_warped_motion_qdata_tp1.Load(int3(_12944, 0));
                                uint _13034 = _13033.x;
                                if (_13034 != 0u)
                                {
                                    _23744 = min(_20849, _13034);
                                    break;
                                }
                                _20852++;
                                continue;
                            }
                            else
                            {
                                _23744 = _20849;
                                break;
                            }
                        }
                    }
                    float _20851;
                    if (_20849 == 4294967295u)
                    {
                        _20851 = -1.0f;
                    }
                    else
                    {
                        float _20850;
                        if (_20849 == 0u)
                        {
                            _20850 = -1.0f;
                        }
                        else
                        {
                            _20850 = float((_20849 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20851 = _20850;
                    }
                    _20864 = _20851;
                    break;
                } while(false);
                bool _6657 = _20864 < 0.0f;
                float _20865;
                if (_6657)
                {
                    _20865 = 0.0f;
                }
                else
                {
                    _20865 = _20864 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _13055_dummy_parameter;
                uint _13087_dummy_parameter;
                float4 _20902;
                if ((_6657 && _6646) && _6649)
                {
                    uint _13119_dummy_parameter;
                    float _13143 = log(((r_depth_tm1.Load(int3(int2(floor(_19978 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13119_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _13151_dummy_parameter;
                    float _13175 = log(((r_depth_tp1.Load(int3(int2(floor(_19980 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13151_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20903;
                    if (_13143 > (_13175 + 0.07999999821186065673828125f))
                    {
                        float4 _19681 = _20869;
                        _19681.x = 0.0f;
                        _20903 = _19681;
                    }
                    else
                    {
                        float4 _20904;
                        if (_13175 > (_13143 + 0.07999999821186065673828125f))
                        {
                            float4 _19683 = _20869;
                            _19683.y = 0.0f;
                            _20904 = _19683;
                        }
                        else
                        {
                            _20904 = _20869;
                        }
                        _20903 = _20904;
                    }
                    _20902 = _20903;
                }
                else
                {
                    _20902 = _20869;
                }
                float _6709 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6711 = _20864 >= 0.0f;
                float _20885;
                if (_6711)
                {
                    _20885 = _20864 - _6709;
                }
                else
                {
                    float _20881;
                    if (_6646)
                    {
                        float _20880;
                        _20880 = 2.0f;
                        float _13233;
                        for (int _20879 = 0; _20879 < 24; _20880 = _13233, _20879++)
                        {
                            float _13197 = float(_20879 & 7) * 0.785398185253143310546875f;
                            int _13199 = _20879 >> 3;
                            int _20882;
                            if (_13199 == 0)
                            {
                                _20882 = 16;
                            }
                            else
                            {
                                _20882 = (_13199 == 1) ? 48 : 96;
                            }
                            uint _13249_dummy_parameter;
                            _13233 = min(_20880, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19978 + ((cbFI_MvDepthLaneSizeRcp * float(_20882)) * float2(cos(_13197), sin(_13197))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13249_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20881 = _20880;
                    }
                    else
                    {
                        _20881 = 0.0f;
                    }
                    _20885 = _20881;
                }
                float _20892;
                if (_6711)
                {
                    _20892 = _20864 - _6709;
                }
                else
                {
                    float _20888;
                    if (_6649)
                    {
                        float _20887;
                        _20887 = 2.0f;
                        float _13347;
                        for (int _20886 = 0; _20886 < 24; _20887 = _13347, _20886++)
                        {
                            float _13311 = float(_20886 & 7) * 0.785398185253143310546875f;
                            int _13313 = _20886 >> 3;
                            int _20889;
                            if (_13313 == 0)
                            {
                                _20889 = 16;
                            }
                            else
                            {
                                _20889 = (_13313 == 1) ? 48 : 96;
                            }
                            uint _13379_dummy_parameter;
                            _13347 = min(_20887, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19980 + ((cbFI_MvDepthLaneSizeRcp * float(_20889)) * float2(cos(_13311), sin(_13311))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13379_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20888 = _20887;
                    }
                    else
                    {
                        _20888 = 0.0f;
                    }
                    _20892 = _20888;
                }
                float _20893;
                if (_6646)
                {
                    uint _13411_dummy_parameter;
                    _20893 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_19978 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13411_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20893 = 0.0f;
                }
                float _20894;
                if (_6649)
                {
                    uint _13431_dummy_parameter;
                    _20894 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_19980 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13431_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20894 = 0.0f;
                }
                bool _6766;
                if (_6646)
                {
                    _6766 = _20893 > ((exp((_20885 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6766 = _6646;
                }
                float4 _20910;
                if (_6766)
                {
                    float4 _19685 = _20902;
                    _19685.x = 0.0f;
                    _20910 = _19685;
                }
                else
                {
                    _20910 = _20902;
                }
                bool _6778;
                if (_6649)
                {
                    _6778 = _20894 > ((exp((_20892 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6778 = _6649;
                }
                float4 _20912;
                if (_6778)
                {
                    float4 _19687 = _20910;
                    _19687.y = 0.0f;
                    _20912 = _19687;
                }
                else
                {
                    _20912 = _20910;
                }
                float4 _20975;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6711)
                {
                    bool _6798;
                    if (_6646)
                    {
                        _6798 = _20893 < ((exp((_20885 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6798 = _6646;
                    }
                    float4 _20914;
                    if (_6798)
                    {
                        float4 _19689 = _20912;
                        _19689.x = 0.0f;
                        _20914 = _19689;
                    }
                    else
                    {
                        _20914 = _20912;
                    }
                    bool _6810;
                    if (_6649)
                    {
                        _6810 = _20894 < ((exp((_20892 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6810 = _6649;
                    }
                    float4 _20976;
                    if (_6810)
                    {
                        float4 _19691 = _20914;
                        _19691.y = 0.0f;
                        _20976 = _19691;
                    }
                    else
                    {
                        _20976 = _20914;
                    }
                    _20975 = _20976;
                }
                else
                {
                    _20975 = _20912;
                }
                _22213 = float3(_20865, log(((r_depth_tm1.Load(int3(int2(floor(_19978 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13055_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_19980 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13087_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _20974 = _20975;
            }
            else
            {
                _22213 = float3(0.0f, 0.0f, 0.5f);
                _20974 = _20869;
            }
            bool _6821 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6570;
            bool _6827;
            if (_6821)
            {
                _6827 = _6624 || _6630;
            }
            else
            {
                _6827 = _6821;
            }
            float4 _21017;
            if (_6827)
            {
                float _20969;
                do
                {
                    uint4 _13611 = r_warped_motion_qdata_tp1.Load(int3(_20199, 0));
                    uint _13612 = _13611.x;
                    if (_13612 != 0u)
                    {
                        float _20968;
                        if (_13612 == 0u)
                        {
                            _20968 = -1.0f;
                        }
                        else
                        {
                            _20968 = float((_13612 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20969 = _20968;
                        break;
                    }
                    int _20951;
                    uint _20952;
                    _20952 = _13612;
                    _20951 = -1;
                    uint _20967;
                    for (; _20951 <= 1; _20952 = _20967, _20951++)
                    {
                        _20967 = _20952;
                        for (int _20965 = -1; _20965 <= 1; )
                        {
                            _20967 = max(_20967, r_warped_motion_qdata_tp1.Load(int3(clamp(_20199 + int2(_20965, _20951), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20965++;
                            continue;
                        }
                    }
                    if (_20952 != 0u)
                    {
                        float _20964;
                        if (_20952 == 0u)
                        {
                            _20964 = -1.0f;
                        }
                        else
                        {
                            _20964 = float((_20952 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20969 = _20964;
                        break;
                    }
                    uint _20954;
                    _20954 = 4294967295u;
                    uint _23745;
                    for (int _20953 = 0; _20953 < 8; _20954 = _23745, _20953++)
                    {
                        int _20957 = 0;
                        for (;;)
                        {
                            if (_20957 < 5)
                            {
                                int2 _13562 = _20199 + (_1251[_20953] * _1260[_20957].xx);
                                bool _13565 = any(bool2(_13562.x < int2(0, 0).x, _13562.y < int2(0, 0).y));
                                bool _13573;
                                if (!_13565)
                                {
                                    _13573 = any(bool2(_13562.x >= cbFI_MvDepthLaneSize.x, _13562.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13573 = _13565;
                                }
                                if (_13573)
                                {
                                    _23745 = _20954;
                                    break;
                                }
                                uint4 _13651 = r_warped_motion_qdata_tp1.Load(int3(_13562, 0));
                                uint _13652 = _13651.x;
                                if (_13652 != 0u)
                                {
                                    _23745 = min(_20954, _13652);
                                    break;
                                }
                                _20957++;
                                continue;
                            }
                            else
                            {
                                _23745 = _20954;
                                break;
                            }
                        }
                    }
                    float _20956;
                    if (_20954 == 4294967295u)
                    {
                        _20956 = -1.0f;
                    }
                    else
                    {
                        float _20955;
                        if (_20954 == 0u)
                        {
                            _20955 = -1.0f;
                        }
                        else
                        {
                            _20955 = float((_20954 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20956 = _20955;
                    }
                    _20969 = _20956;
                    break;
                } while(false);
                float4 _21018;
                if (_20969 >= 0.0f)
                {
                    float _13673 = (exp((_20969 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6846;
                    if (_6624)
                    {
                        uint _13680_dummy_parameter;
                        _6846 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19981 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13680_dummy_parameter))))), 0)).x) > _13673;
                    }
                    else
                    {
                        _6846 = _6624;
                    }
                    float4 _20987;
                    if (_6846)
                    {
                        float4 _19693 = _20974;
                        _19693.z = 0.0f;
                        _20987 = _19693;
                    }
                    else
                    {
                        _20987 = _20974;
                    }
                    bool _6858;
                    if (_6630)
                    {
                        uint _13700_dummy_parameter;
                        _6858 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19982 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13700_dummy_parameter))))), 0)).x) > _13673;
                    }
                    else
                    {
                        _6858 = _6630;
                    }
                    float4 _21019;
                    if (_6858)
                    {
                        float4 _19695 = _20987;
                        _19695.w = 0.0f;
                        _21019 = _19695;
                    }
                    else
                    {
                        _21019 = _20987;
                    }
                    _21018 = _21019;
                }
                else
                {
                    _21018 = _20974;
                }
                _21017 = _21018;
            }
            else
            {
                _21017 = _20974;
            }
            bool _6866 = _6612 != _6618;
            bool _6873;
            if (_6866)
            {
                _6873 = _6612 ? _6558 : _6561;
            }
            else
            {
                _6873 = _6866;
            }
            bool _6880;
            if (_6873)
            {
                _6880 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6880 = _6873;
            }
            float4 _21120;
            if (_6880)
            {
                bool2 _6885 = _6612.xx;
                float2 _6886 = float2(_6885.x ? _19978.x : _19980.x, _6885.y ? _19978.y : _19980.y);
                float _21001;
                if (_6612)
                {
                    uint _13720_dummy_parameter;
                    _21001 = r_depth_tm1.Load(int3(int2(floor(_6886 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13720_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13736_dummy_parameter;
                    _21001 = r_depth_tp1.Load(int3(int2(floor(_6886 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13736_dummy_parameter))))), 0)).x;
                }
                float4x4 _21008;
                if (_6612)
                {
                    float4x4 _20997;
                    do
                    {
                        float4x4 _13750;
                        bool _20996;
                        do
                        {
                            _13750 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20996 = false;
                                break;
                            }
                            uint _13784 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13784 + 32u) * 4 + 0) != 1u)
                            {
                                _20996 = false;
                                break;
                            }
                            uint _20993;
                            _20993 = 0u;
                            for (; _20993 < 4u; _20993++)
                            {
                                for (uint _20994 = 0u; _20994 < 4u; )
                                {
                                    _13750[_20993][_20994] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13784 + 16u) + (_20993 * 4u)) + _20994) * 4 + 0));
                                    _20994++;
                                    continue;
                                }
                            }
                            _20996 = true;
                            break;
                        } while(false);
                        if (_20996)
                        {
                            _20997 = _13750;
                            break;
                        }
                        _20997 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _21008 = _20997;
                }
                else
                {
                    float4x4 _20992;
                    do
                    {
                        float4x4 _13856;
                        bool _20991;
                        do
                        {
                            _13856 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20991 = false;
                                break;
                            }
                            uint _13890 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13890 + 32u) * 4 + 0) != 1u)
                            {
                                _20991 = false;
                                break;
                            }
                            uint _20988;
                            _20988 = 0u;
                            for (; _20988 < 4u; _20988++)
                            {
                                for (uint _20989 = 0u; _20989 < 4u; )
                                {
                                    _13856[_20988][_20989] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13890 + (_20988 * 4u)) + _20989) * 4 + 0));
                                    _20989++;
                                    continue;
                                }
                            }
                            _20991 = true;
                            break;
                        } while(false);
                        if (_20991)
                        {
                            _20992 = _13856;
                            break;
                        }
                        _20992 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _21008 = _20992;
                }
                float2 _21009;
                do
                {
                    float _13967 = _6886.x;
                    float _13970 = 1.0f - _6886.y;
                    float4 _13981 = mul(float4((float2(_13967, _13970) * 2.0f) - 1.0f.xx, _21001, 1.0f), _21008);
                    float _13983 = _13981.w;
                    if (!(_13983 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21009 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13996 = ((_13981.xy / _13983.xx) + 1.0f.xx) * 0.5f;
                    _21009 = float2(_13996.x - _13967, _13970 - _13996.y);
                    break;
                } while(false);
                float2 _6916 = float2(cbFI_DisplaySize);
                float4 _21121;
                if (!(length(((_6886 + _21009) - float2(_6885.x ? _19980.x : _19978.x, _6885.y ? _19980.y : _19978.y)) * _6916) <= ((0.100000001490116119384765625f * length(_21009 * _6916)) + 8.0f)))
                {
                    float4 _21122;
                    if (_6612)
                    {
                        float4 _19705 = _21017;
                        _19705.x = 0.0f;
                        _21122 = _19705;
                    }
                    else
                    {
                        float4 _19707 = _21017;
                        _19707.y = 0.0f;
                        _21122 = _19707;
                    }
                    _21121 = _21122;
                }
                else
                {
                    _21121 = _21017;
                }
                _21120 = _21121;
            }
            else
            {
                _21120 = _21017;
            }
            float4 _6941 = _20731 * _21120;
            float _6943 = dot(_6941, 1.0f.xxxx);
            float4 _21462;
            bool _21768;
            if (_6943 > 0.0f)
            {
                _21768 = _20422;
                _21462 = _6941 / _6943.xxxx;
            }
            else
            {
                bool _6954 = any(bool4(_21120.x < 1.0f.xxxx.x, _21120.y < 1.0f.xxxx.y, _21120.z < 1.0f.xxxx.z, _21120.w < 1.0f.xxxx.w));
                if (_6954)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14018;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _14018);
                    }
                }
                bool4 _23858 = _6954.xxxx;
                _21768 = _6954 ? true : _20422;
                _21462 = float4(_23858.x ? 0.0f.xxxx.x : _20731.x, _23858.y ? 0.0f.xxxx.y : _20731.y, _23858.z ? 0.0f.xxxx.z : _20731.z, _23858.w ? 0.0f.xxxx.w : _20731.w);
            }
            _22104 = _22213;
            _21767 = _21768;
            _21461 = _21462;
        }
        else
        {
            _22104 = float3(0.0f, 0.0f, 0.5f);
            _21767 = _20422;
            _21461 = _20731;
        }
        uint _6963 = (cbFI_pad0 >> 24u) & 31u;
        uint _6967 = (cbFI_pad0 >> 16u) & 255u;
        bool _6969 = _6963 != 0u;
        bool _6971 = _6967 == 12u;
        bool _6974 = _6967 == 13u;
        float4 _21482;
        if ((_6969 || _6971) || _6974)
        {
            float _21128;
            do
            {
                bool _14102 = all(bool2(_19981.x > 0.0f.xx.x, _19981.y > 0.0f.xx.y));
                bool _14108;
                if (_14102)
                {
                    _14108 = all(bool2(_19981.x < 1.0f.xx.x, _19981.y < 1.0f.xx.y));
                }
                else
                {
                    _14108 = _14102;
                }
                bool _14039 = !_14108;
                bool _14046;
                if (!_14039)
                {
                    bool _14113 = all(bool2(_19982.x > 0.0f.xx.x, _19982.y > 0.0f.xx.y));
                    bool _14119;
                    if (_14113)
                    {
                        _14119 = all(bool2(_19982.x < 1.0f.xx.x, _19982.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _14119 = _14113;
                    }
                    _14046 = !_14119;
                }
                else
                {
                    _14046 = _14039;
                }
                if (_14046)
                {
                    _21128 = 0.0f;
                    break;
                }
                uint _14126_dummy_parameter;
                uint _14142_dummy_parameter;
                float4x4 _21127;
                do
                {
                    float4x4 _14156;
                    bool _21126;
                    do
                    {
                        _14156 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _21126 = false;
                            break;
                        }
                        uint _14190 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14190 + 32u) * 4 + 0) != 1u)
                        {
                            _21126 = false;
                            break;
                        }
                        uint _21123;
                        _21123 = 0u;
                        for (; _21123 < 4u; _21123++)
                        {
                            for (uint _21124 = 0u; _21124 < 4u; )
                            {
                                _14156[_21123][_21124] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14190 + 16u) + (_21123 * 4u)) + _21124) * 4 + 0));
                                _21124++;
                                continue;
                            }
                        }
                        _21126 = true;
                        break;
                    } while(false);
                    if (_21126)
                    {
                        _21127 = _14156;
                        break;
                    }
                    _21127 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _14067 = mul(float4((float2(_19981.x, 1.0f - _19981.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19981 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14126_dummy_parameter))))), 0)).x, 1.0f), _21127);
                float _14069 = _14067.w;
                if (abs(_14069) < 9.9999999747524270787835121154785e-07f)
                {
                    _21128 = 0.0f;
                    break;
                }
                float _14080 = abs(cbFI_DeviceToViewDepth.y / ((_14067.z / _14069) - cbFI_DeviceToViewDepth.x));
                float _14083 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19982 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _14142_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _21128 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_14080 - _14083) / max(max(_14080, _14083), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14292 = all(bool2(_19982.x > 0.0f.xx.x, _19982.y > 0.0f.xx.y));
            bool _14298;
            if (_14292)
            {
                _14298 = all(bool2(_19982.x < 1.0f.xx.x, _19982.y < 1.0f.xx.y));
            }
            else
            {
                _14298 = _14292;
            }
            float _21129;
            if (_14298)
            {
                uint _14305_dummy_parameter;
                _21129 = length((_8118 + (r_motion_tp1.Load(int3(int2(floor(_19982 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14305_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _21129 = 1000000.0f;
            }
            float _21144;
            if ((_6963 & 1u) != 0u)
            {
                _21144 = _21128;
            }
            else
            {
                _21144 = 1.0f;
            }
            float _21145;
            if ((_6963 & 2u) != 0u)
            {
                _21145 = _21144 * (1.0f - smoothstep(2.0f, 8.0f, _21129));
            }
            else
            {
                _21145 = _21144;
            }
            float _21146;
            if ((_6963 & 4u) != 0u)
            {
                _21146 = _21145 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8839 - _8847) - length(_8823 - _8831))));
            }
            else
            {
                _21146 = _21145;
            }
            float _21476;
            if ((_6963 & 8u) != 0u)
            {
                _21476 = lerp(1.0f, _21146, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8823 - _8831)));
            }
            else
            {
                _21476 = _21146;
            }
            bool _7049 = (_6963 & 16u) != 0u;
            bool _7058;
            if (_7049)
            {
                _7058 = length(_19976 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _7058 = _7049;
            }
            float _23860 = _7058 ? 1.0f : _21476;
            bool _7064 = _6969 && _11220;
            bool _7069;
            if (_7064)
            {
                bool _14330 = all(bool2(_19978.x > 0.0f.xx.x, _19978.y > 0.0f.xx.y));
                bool _14336;
                if (_14330)
                {
                    _14336 = all(bool2(_19978.x < 1.0f.xx.x, _19978.y < 1.0f.xx.y));
                }
                else
                {
                    _14336 = _14330;
                }
                _7069 = _14336;
            }
            else
            {
                _7069 = _7064;
            }
            bool _7074;
            if (_7069)
            {
                bool _14341 = all(bool2(_19980.x > 0.0f.xx.x, _19980.y > 0.0f.xx.y));
                bool _14347;
                if (_14341)
                {
                    _14347 = all(bool2(_19980.x < 1.0f.xx.x, _19980.y < 1.0f.xx.y));
                }
                else
                {
                    _14347 = _14341;
                }
                _7074 = _14347;
            }
            else
            {
                _7074 = _7069;
            }
            float4 _21483;
            if (_7074)
            {
                float _7080 = _21461.x + _21461.y;
                float _7089 = (_21461.z + _21461.w) * (1.0f - _23860);
                float _21479;
                if (_7080 > 9.9999997473787516355514526367188e-06f)
                {
                    _21479 = _21461.x / _7080;
                }
                else
                {
                    _21479 = _5819;
                }
                _21483 = float4(_21461.x + (_7089 * _21479), _21461.y + (_7089 * (1.0f - _21479)), _21461.zw * _23860);
            }
            else
            {
                _21483 = _21461;
            }
            _21482 = _21483;
        }
        else
        {
            _21482 = _21461;
        }
        float3 _7150 = (((_8823 * _21482.x) + (_8831 * _21482.y)) + (_8839 * _21482.z)) + (_8847 * _21482.w);
        float3 _23493;
        if (_5835 && (_21497 > 0.0f))
        {
            uint _14354_dummy_parameter;
            float2 _14369 = r_motion_tp1.Load(int3(int2(floor(_5594 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14354_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21759;
            if (_8146)
            {
                float2 _14414 = clamp((((_19955 + (_14369 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14417 = tan(_14414.x);
                _21759 = (float2(_14417 / cbFI_DeviceToViewDepth.z, (tan(_14414.y) * sqrt(1.0f + (_14417 * _14417))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21759 = _19955 + (_14369 * cbFI_Timestep);
            }
            float2 _21760;
            if (_8146)
            {
                float2 _14493 = clamp((((_19955 + (_14369 * _5809)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14496 = tan(_14493.x);
                _21760 = (float2(_14496 / cbFI_DeviceToViewDepth.z, (tan(_14493.y) * sqrt(1.0f + (_14496 * _14496))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21760 = _19955 + (_14369 * _5809);
            }
            _23493 = lerp(_7150, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21759, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21760, 0.0f).xyz, cbFI_Timestep.xxx), _21497.xxx);
        }
        else
        {
            _23493 = _7150;
        }
        float3 _23492;
        if (_21767)
        {
            float3 _14538 = r_current_interpolation_source.Load(int3(_5082, 0)).xyz;
            float3 _23494;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11220)
            {
                uint _14545_dummy_parameter;
                float _21890;
                _21890 = r_depth_tm1.Load(int3(int2(floor(_19978 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14545_dummy_parameter))))), 0)).x;
                float _7231;
                for (int _21889 = 0; _21889 < 24; _21890 = _7231, _21889++)
                {
                    float _7203 = float(_21889 & 7) * 0.785398185253143310546875f;
                    int _7205 = _21889 >> 3;
                    int _23587;
                    if (_7205 == 0)
                    {
                        _23587 = 16;
                    }
                    else
                    {
                        _23587 = (_7205 == 1) ? 48 : 96;
                    }
                    uint _14565_dummy_parameter;
                    _7231 = max(_21890, r_depth_tm1.Load(int3(int2(floor(clamp(_19978 + ((cbFI_MvDepthLaneSizeRcp * float(_23587)) * float2(cos(_7203), sin(_7203))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14565_dummy_parameter))))), 0)).x);
                }
                float2 _21891;
                do
                {
                    float _14587 = 1.0f - _19978.y;
                    float4 _14598 = mul(float4((float2(_19978.x, _14587) * 2.0f) - 1.0f.xx, _21890, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14600 = _14598.w;
                    if (!(_14600 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21891 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14613 = ((_14598.xy / _14600.xx) + 1.0f.xx) * 0.5f;
                    _21891 = float2(_14613.x - _19978.x, _14587 - _14613.y);
                    break;
                } while(false);
                float2 _7242 = _19978 + _21891;
                bool _14631 = all(bool2(_7242.x > 0.0f.xx.x, _7242.y > 0.0f.xx.y));
                bool _14637;
                if (_14631)
                {
                    _14637 = all(bool2(_7242.x < 1.0f.xx.x, _7242.y < 1.0f.xx.y));
                }
                else
                {
                    _14637 = _14631;
                }
                float3 _23495;
                if (_14637)
                {
                    float _7248 = abs(cbFI_DeviceToViewDepth.y / (_21890 - cbFI_DeviceToViewDepth.x));
                    uint _14657_dummy_parameter;
                    int2 _14657 = int2(spvTextureSize(r_depth_m2, uint(0), _14657_dummy_parameter));
                    float _7252 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7242 * float2(_14657))), int2(0, 0), _14657 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _23500;
                    if (abs(_7252 - _7248) <= (0.20000000298023223876953125f * max(_7252, _7248)))
                    {
                        uint _14691_dummy_parameter;
                        int2 _14691 = int2(spvTextureSize(r_colour_m2, uint(0), _14691_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14714;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14714);
                        }
                        _23500 = r_colour_m2.Load(int3(clamp(int2(floor(_7242 * float2(_14691))), int2(0, 0), _14691 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14724;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14724);
                        }
                        _23500 = _14538;
                    }
                    _23495 = _23500;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14734;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14734);
                    }
                    _23495 = _14538;
                }
                _23494 = _23495;
            }
            else
            {
                _23494 = _14538;
            }
            _23492 = _23494;
        }
        else
        {
            _23492 = _23493;
        }
        bool _7277 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _23491;
        float _23567;
        if (_7277)
        {
            float2 _7281 = float2(cbFI_DisplaySize);
            float3 _22079;
            float _22080;
            do
            {
                bool _15150;
                float4x4 _21898;
                do
                {
                    float4x4 _15126;
                    bool _21897;
                    do
                    {
                        _15126 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _15150 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_15150)
                        {
                            _21897 = false;
                            break;
                        }
                        uint _15160 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_15160 + 32u) * 4 + 0) != 1u)
                        {
                            _21897 = false;
                            break;
                        }
                        uint _21894;
                        _21894 = 0u;
                        for (; _21894 < 4u; _21894++)
                        {
                            for (uint _21895 = 0u; _21895 < 4u; )
                            {
                                _15126[_21894][_21895] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15160 + (_21894 * 4u)) + _21895) * 4 + 0));
                                _21895++;
                                continue;
                            }
                        }
                        _21897 = true;
                        break;
                    } while(false);
                    if (_21897)
                    {
                        _21898 = _15126;
                        break;
                    }
                    _21898 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float4x4 _14738 = _21898;
                float4x4 _14810 = spvInverse(_21898);
                float4x4 _14739 = _14810;
                if (_6967 == 35u)
                {
                    int2 _14817 = int2(_5594 * _7281);
                    bool _14824 = _14817.y != (int(_7281.y) / 2);
                    bool _14831;
                    if (!_14824)
                    {
                        _14831 = _14817.x >= 80;
                    }
                    else
                    {
                        _14831 = _14824;
                    }
                    if (_14831)
                    {
                        _22080 = 2.0f;
                        _22079 = 0.0f.xxx;
                        break;
                    }
                    int _14835 = _14817.x;
                    int _14836 = _14835 / 2;
                    float _22073;
                    if (_14836 < 16)
                    {
                        _22073 = _14738[_14836 / 4][_14836 % 4];
                    }
                    else
                    {
                        float _22074;
                        if (_14836 < 32)
                        {
                            int _14851 = _14836 - 16;
                            _22074 = _14739[_14851 / 4][_14851 % 4];
                        }
                        else
                        {
                            float _22075;
                            if (_14836 < 36)
                            {
                                _22075 = cbFI_DeviceToViewDepth[_14836 - 32];
                            }
                            else
                            {
                                float _22076;
                                if (_14836 == 36)
                                {
                                    _22076 = float(cbFI_RenderSize.x);
                                }
                                else
                                {
                                    float _22077;
                                    if (_14836 == 37)
                                    {
                                        _22077 = float(cbFI_RenderSize.y);
                                    }
                                    else
                                    {
                                        _22077 = 0.0f;
                                    }
                                    _22076 = _22077;
                                }
                                _22075 = _22076;
                            }
                            _22074 = _22075;
                        }
                        _22073 = _22074;
                    }
                    uint _14886 = asuint(_22073);
                    uint _22078;
                    if ((_14835 & 1) == 0)
                    {
                        _22078 = _14886 >> 16u;
                    }
                    else
                    {
                        _22078 = _14886 & 65535u;
                    }
                    _22080 = 2.0f;
                    _22079 = float3(float(_22078 >> 8u) * 0.0039215688593685626983642578125f, float(_22078 & 255u) * 0.0039215688593685626983642578125f, 0.0f);
                    break;
                }
                bool _14910 = _6967 == 33u;
                if (_14910 || (_6967 == 34u))
                {
                    uint _15248_dummy_parameter;
                    float2 _15263 = r_motion_tp1.Load(int3(int2(floor(clamp(_5594, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15248_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
                    float2 _22065;
                    if (_14910)
                    {
                        uint _15275_dummy_parameter;
                        float2 _22064;
                        do
                        {
                            float _15294 = _5594.x;
                            float _15297 = 1.0f - _5594.y;
                            float4 _15308 = mul(float4((float2(_15294, _15297) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5594 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15275_dummy_parameter))))), 0)).x, 1.0f), _21898);
                            float _15310 = _15308.w;
                            if (!(_15310 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22064 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15323 = ((_15308.xy / _15310.xx) + 1.0f.xx) * 0.5f;
                            _22064 = float2(_15323.x - _15294, _15297 - _15323.y);
                            break;
                        } while(false);
                        _22065 = _22064 - _15263;
                    }
                    else
                    {
                        float2 _14930 = _5594 + _15263;
                        bool _15341 = all(bool2(_14930.x > 0.0f.xx.x, _14930.y > 0.0f.xx.y));
                        bool _15347;
                        if (_15341)
                        {
                            _15347 = all(bool2(_14930.x < 1.0f.xx.x, _14930.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15347 = _15341;
                        }
                        float2 _22063;
                        if (_15347)
                        {
                            uint _15354_dummy_parameter;
                            float2 _22062;
                            do
                            {
                                float _15373 = _14930.x;
                                float _15376 = 1.0f - _14930.y;
                                float4 _15387 = mul(float4((float2(_15373, _15376) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14930 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _15354_dummy_parameter))))), 0)).x, 1.0f), _14810);
                                float _15389 = _15387.w;
                                if (!(_15389 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22062 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _15402 = ((_15387.xy / _15389.xx) + 1.0f.xx) * 0.5f;
                                _22062 = float2(_15402.x - _15373, _15376 - _15402.y);
                                break;
                            } while(false);
                            _22063 = _22062 + _15263;
                        }
                        else
                        {
                            _22063 = 0.0f.xx;
                        }
                        _22065 = _22063;
                    }
                    bool _22072;
                    do
                    {
                        bool _15481 = all(bool2(_5594.x > 0.0f.xx.x, _5594.y > 0.0f.xx.y));
                        bool _15487;
                        if (_15481)
                        {
                            _15487 = all(bool2(_5594.x < 1.0f.xx.x, _5594.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15487 = _15481;
                        }
                        if (!_15487)
                        {
                            _22072 = false;
                            break;
                        }
                        uint _15494_dummy_parameter;
                        float4x4 _22070;
                        do
                        {
                            float4x4 _15508;
                            bool _22069;
                            do
                            {
                                _15508 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_15150)
                                {
                                    _22069 = false;
                                    break;
                                }
                                uint _15542 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_15542 + 32u) * 4 + 0) != 1u)
                                {
                                    _22069 = false;
                                    break;
                                }
                                uint _22066;
                                _22066 = 0u;
                                for (; _22066 < 4u; _22066++)
                                {
                                    for (uint _22067 = 0u; _22067 < 4u; )
                                    {
                                        _15508[_22066][_22067] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15542 + (_22066 * 4u)) + _22067) * 4 + 0));
                                        _22067++;
                                        continue;
                                    }
                                }
                                _22069 = true;
                                break;
                            } while(false);
                            if (_22069)
                            {
                                _22070 = _15508;
                                break;
                            }
                            _22070 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _22071;
                        do
                        {
                            float _15619 = _5594.x;
                            float _15622 = 1.0f - _5594.y;
                            float4 _15633 = mul(float4((float2(_15619, _15622) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5594 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15494_dummy_parameter))))), 0)).x, 1.0f), _22070);
                            float _15635 = _15633.w;
                            if (!(_15635 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22071 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15648 = ((_15633.xy / _15635.xx) + 1.0f.xx) * 0.5f;
                            _22071 = float2(_15648.x - _15619, _15622 - _15648.y);
                            break;
                        } while(false);
                        float2 _15445 = abs(_22071);
                        if (any(bool2(_15445.x > 100000.0f.xx.x, _15445.y > 100000.0f.xx.y)))
                        {
                            _22072 = false;
                            break;
                        }
                        float _15453 = length(_22071 * _7281);
                        uint _15668_dummy_parameter;
                        bool _15467 = _15453 > ((8.0f * _7281.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _15474;
                        if (_15467)
                        {
                            _15474 = length((r_motion_tp1.Load(int3(int2(floor(_5594 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15668_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7281) < (0.20000000298023223876953125f * _15453);
                        }
                        else
                        {
                            _15474 = _15467;
                        }
                        _22072 = _15474;
                        break;
                    } while(false);
                    _22080 = 2.0f;
                    _22079 = float3(clamp(length(_22065 * float2(cbFI_RenderSize)) * 0.25f, 0.0f, 1.0f), float(_22072), 0.0f);
                    break;
                }
                float _15702;
                float _15705;
                float4 _15715;
                float2 _21899;
                do
                {
                    _15702 = _5594.x;
                    _15705 = 1.0f - _5594.y;
                    _15715 = float4((float2(_15702, _15705) * 2.0f) - 1.0f.xx, 0.99999988079071044921875f, 1.0f);
                    float4 _15716 = mul(_15715, _21898);
                    float _15718 = _15716.w;
                    if (!(_15718 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21899 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15731 = ((_15716.xy / _15718.xx) + 1.0f.xx) * 0.5f;
                    _21899 = float2(_15731.x - _15702, _15705 - _15731.y);
                    break;
                } while(false);
                float2 _21900;
                do
                {
                    float4 _15768 = mul(_15715, _14810);
                    float _15770 = _15768.w;
                    if (!(_15770 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21900 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15783 = ((_15768.xy / _15770.xx) + 1.0f.xx) * 0.5f;
                    _21900 = float2(_15783.x - _15702, _15705 - _15783.y);
                    break;
                } while(false);
                float2 _14965 = abs(_21899);
                bool2 _23861 = any(bool2(_14965.x > 4.0f.xx.x, _14965.y > 4.0f.xx.y)).xx;
                float2 _14971 = abs(_21900);
                bool2 _23863 = any(bool2(_14971.x > 4.0f.xx.x, _14971.y > 4.0f.xx.y)).xx;
                float2 _15797[3];
                _15797[0] = _5594;
                float2 _15917 = clamp(_5594, 0.0f.xx, 1.0f.xx);
                uint _15925_dummy_parameter;
                _15797[1] = _5594 - ((r_motion_tp1.Load(int3(int2(floor(_15917 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15925_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5819);
                _15797[2] = _5594 - (float2(_23861.x ? 0.0f.xx.x : _21899.x, _23861.y ? 0.0f.xx.y : _21899.y) * _5819);
                float _21906;
                float2 _21907;
                _21907 = _5594;
                _21906 = 1000000000.0f;
                float _23865;
                float2 _23867;
                float _23868;
                int _21905 = 0;
                float _22054 = -1.0f;
                for (; _21905 < 3; _22054 = _23865, _21907 = _23867, _21906 = _23868, _21905++)
                {
                    float2 _22044;
                    _22044 = _15797[_21905];
                    for (int _22043 = 0; _22043 < 30; )
                    {
                        uint _16439_dummy_parameter;
                        _22044 += (((_5594 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_22044, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16439_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5819)) - _22044) * 0.699999988079071044921875f);
                        _22043++;
                        continue;
                    }
                    float2 _16869 = clamp(_22044, 0.0f.xx, 1.0f.xx);
                    uint _16877_dummy_parameter;
                    bool _17307 = all(bool2(_22044.x > 0.0f.xx.x, _22044.y > 0.0f.xx.y));
                    bool _17313;
                    if (_17307)
                    {
                        _17313 = all(bool2(_22044.x < 1.0f.xx.x, _22044.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17313 = _17307;
                    }
                    float _22046;
                    if (_17313)
                    {
                        _22046 = length(((_22044 + ((r_motion_tp1.Load(int3(int2(floor(_16869 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16877_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5819)) - _5594) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22046 = 1000000000.0f;
                    }
                    uint _17324_dummy_parameter;
                    float _17364 = log(((r_depth_tp1.Load(int3(int2(floor(_16869 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17324_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15877 = _22046 < 0.3499999940395355224609375f;
                    bool _15879 = _21906 < 0.3499999940395355224609375f;
                    bool _15889;
                    if (_15877)
                    {
                        _15889 = (!_15879) || (_17364 > _22054);
                    }
                    else
                    {
                        _15889 = _15877;
                    }
                    bool _15902;
                    if (!_15889)
                    {
                        _15902 = ((!_15877) && (!_15879)) && (_22046 < _21906);
                    }
                    else
                    {
                        _15902 = _15889;
                    }
                    _23865 = _15902 ? _17364 : _22054;
                    bool2 _23866 = _15902.xx;
                    _23867 = float2(_23866.x ? _22044.x : _21907.x, _23866.y ? _22044.y : _21907.y);
                    _23868 = _15902 ? _22046 : _21906;
                }
                float2 _17366[3];
                _17366[0] = _5594;
                float2 _21926;
                do
                {
                    bool _21916;
                    do
                    {
                        bool _17613 = all(bool2(_15917.x > 0.0f.xx.x, _15917.y > 0.0f.xx.y));
                        bool _17619;
                        if (_17613)
                        {
                            _17619 = all(bool2(_15917.x < 1.0f.xx.x, _15917.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17619 = _17613;
                        }
                        if (!_17619)
                        {
                            _21916 = false;
                            break;
                        }
                        uint _17626_dummy_parameter;
                        float4x4 _21914;
                        do
                        {
                            float4x4 _17640;
                            bool _21913;
                            do
                            {
                                _17640 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_15150)
                                {
                                    _21913 = false;
                                    break;
                                }
                                uint _17674 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17674 + 32u) * 4 + 0) != 1u)
                                {
                                    _21913 = false;
                                    break;
                                }
                                uint _21910;
                                _21910 = 0u;
                                for (; _21910 < 4u; _21910++)
                                {
                                    for (uint _21911 = 0u; _21911 < 4u; )
                                    {
                                        _17640[_21910][_21911] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17674 + (_21910 * 4u)) + _21911) * 4 + 0));
                                        _21911++;
                                        continue;
                                    }
                                }
                                _21913 = true;
                                break;
                            } while(false);
                            if (_21913)
                            {
                                _21914 = _17640;
                                break;
                            }
                            _21914 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21915;
                        do
                        {
                            float _17751 = _15917.x;
                            float _17754 = 1.0f - _15917.y;
                            float4 _17765 = mul(float4((float2(_17751, _17754) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15917 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17626_dummy_parameter))))), 0)).x, 1.0f), _21914);
                            float _17767 = _17765.w;
                            if (!(_17767 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21915 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17780 = ((_17765.xy / _17767.xx) + 1.0f.xx) * 0.5f;
                            _21915 = float2(_17780.x - _17751, _17754 - _17780.y);
                            break;
                        } while(false);
                        float2 _17577 = abs(_21915);
                        if (any(bool2(_17577.x > 100000.0f.xx.x, _17577.y > 100000.0f.xx.y)))
                        {
                            _21916 = false;
                            break;
                        }
                        float _17585 = length(_21915 * _7281);
                        uint _17800_dummy_parameter;
                        bool _17599 = _17585 > ((8.0f * _7281.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17606;
                        if (_17599)
                        {
                            _17606 = length((r_motion_tp1.Load(int3(int2(floor(_15917 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17800_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7281) < (0.20000000298023223876953125f * _17585);
                        }
                        else
                        {
                            _17606 = _17599;
                        }
                        _21916 = _17606;
                        break;
                    } while(false);
                    if (_21916)
                    {
                        uint _17831_dummy_parameter;
                        _21926 = -(r_motion_tp1.Load(int3(int2(floor(_15917 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17831_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17858_dummy_parameter;
                    float2 _21925;
                    do
                    {
                        float _17877 = _15917.x;
                        float _17880 = 1.0f - _15917.y;
                        float4 _17891 = mul(float4((float2(_17877, _17880) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15917 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17858_dummy_parameter))))), 0)).x, 1.0f), _14810);
                        float _17893 = _17891.w;
                        if (!(_17893 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21925 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17906 = ((_17891.xy / _17893.xx) + 1.0f.xx) * 0.5f;
                        _21925 = float2(_17906.x - _17877, _17880 - _17906.y);
                        break;
                    } while(false);
                    float2 _17544 = abs(_21925);
                    bool2 _17548 = any(bool2(_17544.x > 4.0f.xx.x, _17544.y > 4.0f.xx.y)).xx;
                    _21926 = float2(_17548.x ? 0.0f.xx.x : _21925.x, _17548.y ? 0.0f.xx.y : _21925.y);
                    break;
                } while(false);
                _17366[1] = _5594 - (_21926 * cbFI_Timestep);
                _17366[2] = _5594 - (float2(_23863.x ? 0.0f.xx.x : _21900.x, _23863.y ? 0.0f.xx.y : _21900.y) * cbFI_Timestep);
                float _21928;
                float2 _21929;
                _21929 = _5594;
                _21928 = 1000000000.0f;
                float _23869;
                float2 _23871;
                float _23872;
                float4x4 _18154;
                float4x4 _18592;
                int _21927 = 0;
                float _21981 = -1.0f;
                for (; _21927 < 3; _21981 = _23869, _21929 = _23871, _21928 = _23872, _21927++)
                {
                    float2 _21931;
                    _21931 = _17366[_21927];
                    float2 _17963;
                    for (int _21930 = 0; _21930 < 30; _21931 = _17963, _21930++)
                    {
                        float2 _22022;
                        do
                        {
                            float2 _18043 = clamp(_21931, 0.0f.xx, 1.0f.xx);
                            bool _22012;
                            do
                            {
                                bool _18127 = all(bool2(_18043.x > 0.0f.xx.x, _18043.y > 0.0f.xx.y));
                                bool _18133;
                                if (_18127)
                                {
                                    _18133 = all(bool2(_18043.x < 1.0f.xx.x, _18043.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _18133 = _18127;
                                }
                                if (!_18133)
                                {
                                    _22012 = false;
                                    break;
                                }
                                uint _18140_dummy_parameter;
                                float4x4 _22010;
                                do
                                {
                                    bool _22009;
                                    do
                                    {
                                        _18154 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_15150)
                                        {
                                            _22009 = false;
                                            break;
                                        }
                                        uint _18188 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_18188 + 32u) * 4 + 0) != 1u)
                                        {
                                            _22009 = false;
                                            break;
                                        }
                                        uint _22006;
                                        _22006 = 0u;
                                        for (; _22006 < 4u; _22006++)
                                        {
                                            for (uint _22007 = 0u; _22007 < 4u; )
                                            {
                                                _18154[_22006][_22007] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18188 + (_22006 * 4u)) + _22007) * 4 + 0));
                                                _22007++;
                                                continue;
                                            }
                                        }
                                        _22009 = true;
                                        break;
                                    } while(false);
                                    if (_22009)
                                    {
                                        _22010 = _18154;
                                        break;
                                    }
                                    _22010 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _22011;
                                do
                                {
                                    float _18265 = _18043.x;
                                    float _18268 = 1.0f - _18043.y;
                                    float4 _18279 = mul(float4((float2(_18265, _18268) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18043 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18140_dummy_parameter))))), 0)).x, 1.0f), _22010);
                                    float _18281 = _18279.w;
                                    if (!(_18281 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _22011 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _18294 = ((_18279.xy / _18281.xx) + 1.0f.xx) * 0.5f;
                                    _22011 = float2(_18294.x - _18265, _18268 - _18294.y);
                                    break;
                                } while(false);
                                float2 _18091 = abs(_22011);
                                if (any(bool2(_18091.x > 100000.0f.xx.x, _18091.y > 100000.0f.xx.y)))
                                {
                                    _22012 = false;
                                    break;
                                }
                                float _18099 = length(_22011 * _7281);
                                uint _18314_dummy_parameter;
                                bool _18113 = _18099 > ((8.0f * _7281.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _18120;
                                if (_18113)
                                {
                                    _18120 = length((r_motion_tp1.Load(int3(int2(floor(_18043 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18314_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7281) < (0.20000000298023223876953125f * _18099);
                                }
                                else
                                {
                                    _18120 = _18113;
                                }
                                _22012 = _18120;
                                break;
                            } while(false);
                            if (_22012)
                            {
                                uint _18345_dummy_parameter;
                                _22022 = -(r_motion_tp1.Load(int3(int2(floor(_18043 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18345_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _18372_dummy_parameter;
                            float2 _22021;
                            do
                            {
                                float _18391 = _18043.x;
                                float _18394 = 1.0f - _18043.y;
                                float4 _18405 = mul(float4((float2(_18391, _18394) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18043 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18372_dummy_parameter))))), 0)).x, 1.0f), _14810);
                                float _18407 = _18405.w;
                                if (!(_18407 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22021 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18420 = ((_18405.xy / _18407.xx) + 1.0f.xx) * 0.5f;
                                _22021 = float2(_18420.x - _18391, _18394 - _18420.y);
                                break;
                            } while(false);
                            float2 _18058 = abs(_22021);
                            bool2 _18062 = any(bool2(_18058.x > 4.0f.xx.x, _18058.y > 4.0f.xx.y)).xx;
                            _22022 = float2(_18062.x ? 0.0f.xx.x : _22021.x, _18062.y ? 0.0f.xx.y : _22021.y);
                            break;
                        } while(false);
                        _17963 = _21931 + (((_5594 - (_22022 * cbFI_Timestep)) - _21931) * 0.699999988079071044921875f);
                    }
                    float2 _18481;
                    float2 _21948;
                    do
                    {
                        _18481 = clamp(_21931, 0.0f.xx, 1.0f.xx);
                        bool _21938;
                        do
                        {
                            bool _18565 = all(bool2(_18481.x > 0.0f.xx.x, _18481.y > 0.0f.xx.y));
                            bool _18571;
                            if (_18565)
                            {
                                _18571 = all(bool2(_18481.x < 1.0f.xx.x, _18481.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18571 = _18565;
                            }
                            if (!_18571)
                            {
                                _21938 = false;
                                break;
                            }
                            uint _18578_dummy_parameter;
                            float4x4 _21936;
                            do
                            {
                                bool _21935;
                                do
                                {
                                    _18592 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_15150)
                                    {
                                        _21935 = false;
                                        break;
                                    }
                                    uint _18626 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18626 + 32u) * 4 + 0) != 1u)
                                    {
                                        _21935 = false;
                                        break;
                                    }
                                    uint _21932;
                                    _21932 = 0u;
                                    for (; _21932 < 4u; _21932++)
                                    {
                                        for (uint _21933 = 0u; _21933 < 4u; )
                                        {
                                            _18592[_21932][_21933] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18626 + (_21932 * 4u)) + _21933) * 4 + 0));
                                            _21933++;
                                            continue;
                                        }
                                    }
                                    _21935 = true;
                                    break;
                                } while(false);
                                if (_21935)
                                {
                                    _21936 = _18592;
                                    break;
                                }
                                _21936 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _21937;
                            do
                            {
                                float _18706 = 1.0f - _18481.y;
                                float4 _18717 = mul(float4((float2(_18481.x, _18706) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18481 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18578_dummy_parameter))))), 0)).x, 1.0f), _21936);
                                float _18719 = _18717.w;
                                if (!(_18719 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21937 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18732 = ((_18717.xy / _18719.xx) + 1.0f.xx) * 0.5f;
                                _21937 = float2(_18732.x - _18481.x, _18706 - _18732.y);
                                break;
                            } while(false);
                            float2 _18529 = abs(_21937);
                            if (any(bool2(_18529.x > 100000.0f.xx.x, _18529.y > 100000.0f.xx.y)))
                            {
                                _21938 = false;
                                break;
                            }
                            float _18537 = length(_21937 * _7281);
                            uint _18752_dummy_parameter;
                            bool _18551 = _18537 > ((8.0f * _7281.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18558;
                            if (_18551)
                            {
                                _18558 = length((r_motion_tp1.Load(int3(int2(floor(_18481 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18752_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7281) < (0.20000000298023223876953125f * _18537);
                            }
                            else
                            {
                                _18558 = _18551;
                            }
                            _21938 = _18558;
                            break;
                        } while(false);
                        if (_21938)
                        {
                            uint _18783_dummy_parameter;
                            _21948 = -(r_motion_tp1.Load(int3(int2(floor(_18481 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18783_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18810_dummy_parameter;
                        float2 _21947;
                        do
                        {
                            float _18832 = 1.0f - _18481.y;
                            float4 _18843 = mul(float4((float2(_18481.x, _18832) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18481 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18810_dummy_parameter))))), 0)).x, 1.0f), _14810);
                            float _18845 = _18843.w;
                            if (!(_18845 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21947 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18858 = ((_18843.xy / _18845.xx) + 1.0f.xx) * 0.5f;
                            _21947 = float2(_18858.x - _18481.x, _18832 - _18858.y);
                            break;
                        } while(false);
                        float2 _18496 = abs(_21947);
                        bool2 _18500 = any(bool2(_18496.x > 4.0f.xx.x, _18496.y > 4.0f.xx.y)).xx;
                        _21948 = float2(_18500.x ? 0.0f.xx.x : _21947.x, _18500.y ? 0.0f.xx.y : _21947.y);
                        break;
                    } while(false);
                    bool _18876 = all(bool2(_21931.x > 0.0f.xx.x, _21931.y > 0.0f.xx.y));
                    bool _18882;
                    if (_18876)
                    {
                        _18882 = all(bool2(_21931.x < 1.0f.xx.x, _21931.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18882 = _18876;
                    }
                    float _21960;
                    if (_18882)
                    {
                        _21960 = length(((_21931 + (_21948 * cbFI_Timestep)) - _5594) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21960 = 1000000000.0f;
                    }
                    uint _18909_dummy_parameter;
                    float _18933 = log(((r_depth_tm1.Load(int3(int2(floor(_18481 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18909_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _17446 = _21960 < 0.3499999940395355224609375f;
                    bool _17448 = _21928 < 0.3499999940395355224609375f;
                    bool _17458;
                    if (_17446)
                    {
                        _17458 = (!_17448) || (_18933 > _21981);
                    }
                    else
                    {
                        _17458 = _17446;
                    }
                    bool _17471;
                    if (!_17458)
                    {
                        _17471 = ((!_17446) && (!_17448)) && (_21960 < _21928);
                    }
                    else
                    {
                        _17471 = _17458;
                    }
                    _23869 = _17471 ? _18933 : _21981;
                    bool2 _23870 = _17471.xx;
                    _23871 = float2(_23870.x ? _21931.x : _21929.x, _23870.y ? _21931.y : _21929.y);
                    _23872 = _17471 ? _21960 : _21928;
                }
                float3 _18942 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21907, 0.0f).xyz;
                float3 _18950 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21929, 0.0f).xyz;
                uint _18957_dummy_parameter;
                uint _18988_dummy_parameter;
                float _15011 = exp((_21906 * (-2.0f)) * (_21906 * 2.0f));
                float _15018 = exp((_21928 * (-2.0f)) * (_21928 * 2.0f));
                float _15031 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21929, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18988_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21907, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18957_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _15045 = ((_15011 * cbFI_Timestep) * ((1.0f - _15018) + ((_15018 * 2.0f) * _15031))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _15055 = 1.0f - _15031;
                float _15062 = ((_15018 * _5819) * ((1.0f - _15011) + ((_15011 * 2.0f) * _15055))) + (9.9999997473787516355514526367188e-05f * _5819);
                float _15071 = (((_15011 * _15018) * 4.0f) * _15031) * _15055;
                float _15089 = (_15071 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18950 - _18942, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _15071)) * max(_15011, _15018));
                if (_6967 == 30u)
                {
                    _22080 = _15089;
                    _22079 = _18942;
                    break;
                }
                if (_6967 == 31u)
                {
                    _22080 = _15089;
                    _22079 = _18950;
                    break;
                }
                if (_6967 == 32u)
                {
                    _22080 = _15089;
                    _22079 = float3(_15011, _15018, _15031);
                    break;
                }
                _22080 = _15089;
                _22079 = ((_18942 * _15045) + (_18950 * _15062)) / (_15045 + _15062).xxx;
                break;
            } while(false);
            _23567 = _22080;
            _23491 = _22079;
        }
        else
        {
            _23567 = 1.0f;
            _23491 = _23492;
        }
        uint _7297 = cbFI_pad0 & 255u;
        bool _23291;
        float3 _23490;
        if (_7297 != 0u)
        {
            float3 _7302 = r_present_backbuffer.Load(int3(_5082, 0)).xyz;
            float3 _7306 = r_current_interpolation_source.Load(int3(_5082, 0)).xyz;
            float3 _7310 = abs(_7302 - _7306);
            float3 _22096;
            if (_7297 == 2u)
            {
                _22096 = (abs(_7306) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _22096 = 0.000244140625f.xxx;
            }
            bool _7326 = any(bool3(_7310.x > _22096.x, _7310.y > _22096.y, _7310.z > _22096.z));
            bool3 _23873 = _7326.xxx;
            _23490 = float3(_23873.x ? _7302.x : _23491.x, _23873.y ? _7302.y : _23491.y, _23873.z ? _7302.z : _23491.z);
            _23291 = _7326;
        }
        else
        {
            _23490 = _23491;
            _23291 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _19026;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _19026);
        }
        float3 _23472;
        if (_6967 == 1u)
        {
            _23472 = lerp(_8823, _8831, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _23473;
            if (_6967 == 2u)
            {
                _23473 = lerp(_8839, _8847, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _23474;
                if (_6967 == 3u)
                {
                    _23474 = float(_23291).xxx;
                }
                else
                {
                    float3 _23475;
                    if (_6967 == 4u)
                    {
                        _23475 = float3(((_19976 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _23476;
                        if (_6967 == 5u)
                        {
                            _23476 = float3(((_8118 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _23477;
                            if (_6967 == 6u)
                            {
                                _23477 = float3(_21482.xy, _21482.z + _21482.w);
                            }
                            else
                            {
                                float3 _23478;
                                if (_6967 == 7u)
                                {
                                    _23478 = r_current_interpolation_source.Load(int3(_5082, 0)).xyz;
                                }
                                else
                                {
                                    float3 _23479;
                                    if (_6967 == 8u)
                                    {
                                        _23479 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5594, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _23480;
                                        if (_6971)
                                        {
                                            uint _19048_dummy_parameter;
                                            uint _19080_dummy_parameter;
                                            _23480 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_5594 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _19048_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_5594 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _19080_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _23481;
                                            if (_6974)
                                            {
                                                _23481 = _8839;
                                            }
                                            else
                                            {
                                                float3 _23482;
                                                if (_6967 == 20u)
                                                {
                                                    _23482 = _8823;
                                                }
                                                else
                                                {
                                                    float3 _23483;
                                                    if (_6967 == 21u)
                                                    {
                                                        _23483 = _8831;
                                                    }
                                                    else
                                                    {
                                                        float3 _23484;
                                                        if (_6967 == 22u)
                                                        {
                                                            _23484 = _8847;
                                                        }
                                                        else
                                                        {
                                                            float3 _23485;
                                                            if (_6967 == 18u)
                                                            {
                                                                _23485 = _22718;
                                                            }
                                                            else
                                                            {
                                                                float3 _23486;
                                                                if (_6967 == 19u)
                                                                {
                                                                    _23486 = _22408;
                                                                }
                                                                else
                                                                {
                                                                    float3 _23487;
                                                                    if (_6967 == 23u)
                                                                    {
                                                                        _23487 = _22104;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _23488;
                                                                        if (_6967 == 24u)
                                                                        {
                                                                            uint _7470 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7475 = float(rw_nfru_diagnostics.Load<uint>((_7470 + 35u) * 4 + 0));
                                                                            float _22097;
                                                                            if (_7475 > 0.0f)
                                                                            {
                                                                                _22097 = float(rw_nfru_diagnostics.Load<uint>((_7470 + 34u) * 4 + 0)) / _7475;
                                                                            }
                                                                            else
                                                                            {
                                                                                _22097 = 0.0f;
                                                                            }
                                                                            _23488 = float3(float(rw_nfru_diagnostics.Load<uint>((_7470 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7470 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _22097);
                                                                        }
                                                                        else
                                                                        {
                                                                            _23488 = _23490;
                                                                        }
                                                                        _23487 = _23488;
                                                                    }
                                                                    _23486 = _23487;
                                                                }
                                                                _23485 = _23486;
                                                            }
                                                            _23484 = _23485;
                                                        }
                                                        _23483 = _23484;
                                                    }
                                                    _23482 = _23483;
                                                }
                                                _23481 = _23482;
                                            }
                                            _23480 = _23481;
                                        }
                                        _23479 = _23480;
                                    }
                                    _23478 = _23479;
                                }
                                _23477 = _23478;
                            }
                            _23476 = _23477;
                        }
                        _23475 = _23476;
                    }
                    _23474 = _23475;
                }
                _23473 = _23474;
            }
            _23472 = _23473;
        }
        float3 _23471;
        if ((_6967 >= 9u) && (_6967 <= 11u))
        {
            uint _7535 = 64u + uint((_20199.y * cbFI_MvDepthLaneSize.x) + _20199.x);
            uint _7539 = rw_nfru_diagnostics.Load<uint>(_7535 * 4 + 0) & 15u;
            float3 _23505;
            if (_6967 == 10u)
            {
                float3 _23470;
                if ((rw_nfru_diagnostics.Load<uint>(_7535 * 4 + 0) & 32u) != 0u)
                {
                    _23470 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _23469;
                    if ((rw_nfru_diagnostics.Load<uint>(_7535 * 4 + 0) & 16u) != 0u)
                    {
                        _23469 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7560 = ((rw_nfru_diagnostics.Load<uint>(_7535 * 4 + 0) & 64u) != 0u).xxx;
                        _23469 = float3(_7560.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7560.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7560.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _23470 = _23469;
                }
                _23505 = _23470;
            }
            else
            {
                float3 _23506;
                if (_6967 == 11u)
                {
                    uint _7573 = (rw_nfru_diagnostics.Load<uint>(_7535 * 4 + 0) >> 8u) & 15u;
                    uint _7576 = (rw_nfru_diagnostics.Load<uint>(_7535 * 4 + 0) >> 12u) & 15u;
                    float3 _23462;
                    if ((_7539 == 2u) || (_7539 == 3u))
                    {
                        _23462 = _4765[_7539];
                    }
                    else
                    {
                        bool _7588 = _7573 == 3u;
                        bool _7590 = _7576 == 3u;
                        float3 _23463;
                        if (_7588 && _7590)
                        {
                            _23463 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _23464;
                            if (_7588)
                            {
                                _23464 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _23465;
                                if (_7590)
                                {
                                    _23465 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _23466;
                                    if ((_7573 == 4u) || (_7576 == 4u))
                                    {
                                        _23466 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _23467;
                                        if ((_7573 == 1u) || (_7576 == 1u))
                                        {
                                            _23467 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23875 = (_7539 == 1u).xxx;
                                            _23467 = float3(_23875.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23875.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23875.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _23466 = _23467;
                                    }
                                    _23465 = _23466;
                                }
                                _23464 = _23465;
                            }
                            _23463 = _23464;
                        }
                        _23462 = _23463;
                    }
                    _23506 = _23462;
                }
                else
                {
                    _23506 = _4765[min(_7539, 7u)];
                }
                _23505 = _23506;
            }
            _23471 = _23505;
        }
        else
        {
            _23471 = _23472;
        }
        float4 _23509;
        if ((_6967 >= 14u) && (_6967 <= 16u))
        {
            float2 _23507;
            if (_6967 == 14u)
            {
                uint _7646_dummy_parameter;
                uint _7652_dummy_parameter;
                _23507 = r_flow_tm1.Load(int3(clamp(int2(floor(_5594 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7646_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7652_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _23508;
                if (_6967 == 16u)
                {
                    uint _19156 = r_warped_flow_qdata_tm1.Load(int3(_5610, 0)).x & 2147483647u;
                    uint _19188 = uint(max((int((_19156 >> 16u) & 15u) - 6), 0));
                    _23508 = ((float2(float((1 - (2 * int((_19156 >> 15u) & 1u))) * int(((_19156 >> uint(7)) & 127u) << _19188)), float((1 - (2 * int((_19156 >> 14u) & 1u))) * int((_19156 & 127u) << _19188))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _23508 = _8118 * float2(cbFI_DisplaySize);
                }
                _23507 = _23508;
            }
            uint2 _7685 = uint2(clamp(round(_23507 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7687 = _7685.x;
            uint _7694 = _7685.y;
            _23509 = float4(float(_7687 & 255u), float((_7687 >> 8u) | ((_7694 & 15u) << 4u)), float(_7694 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _23510;
            if (_6967 == 17u)
            {
                _23510 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5610, 0)).x != 0u), _6054, 0.0f, 1.0f);
            }
            else
            {
                _23510 = float4(_23471, 1.0f);
            }
            _23509 = _23510;
        }
        rw_output[_5082] = _23509.xyz;
        if (_7277)
        {
            uint _19233 = uint((_5082.y * cbFI_DisplaySize.x) + _5082.x) * 2u;
            rw_nfru_select.Store<uint>(_19233 * 4 + 0, spvPackHalf2x16(_23509.xy));
            rw_nfru_select.Store<uint>((_19233 + 1u) * 4 + 0, spvPackHalf2x16(float2(_23509.z, (_23291 || (_6967 != 0u)) ? 2.0f : _23567)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7752 = ((uint(_5082.y) * uint(cbFI_DisplaySize.x)) + uint(_5082.x)) * 6u;
            uint _19259 = spvPackHalf2x16(clamp(_8822.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7752 * 4 + 0, (((_19259 & 32767u) >> 4u) | ((((_19259 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8822.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19294 = spvPackHalf2x16(clamp(_8830.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7752 + 1u) * 4 + 0, (((_19294 & 32767u) >> 4u) | ((((_19294 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8830.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19329 = spvPackHalf2x16(clamp(_8838.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7752 + 2u) * 4 + 0, (((_19329 & 32767u) >> 4u) | ((((_19329 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8838.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19364 = spvPackHalf2x16(clamp(_8846.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7752 + 3u) * 4 + 0, (((_19364 & 32767u) >> 4u) | ((((_19364 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8846.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19391 = r_current_interpolation_source.Load(int3(_5082, 0));
            uint _19405 = spvPackHalf2x16(clamp(_19391.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7752 + 4u) * 4 + 0, (((_19405 & 32767u) >> 4u) | ((((_19405 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19391.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _23586;
            if (_23291 || (_6967 != 0u))
            {
                _23586 = 4294967295u;
            }
            else
            {
                uint _19440 = spvPackHalf2x16(clamp(_23509.xy, 0.0f.xx, 65000.0f.xx));
                _23586 = (((_19440 & 32767u) >> 4u) | ((((_19440 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_23509.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7752 + 5u) * 4 + 0, _23586);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_5082] = float4(r_current_interpolation_source.Load(int3(_5082, 0)).xyz, 1.0f).xyz;
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
