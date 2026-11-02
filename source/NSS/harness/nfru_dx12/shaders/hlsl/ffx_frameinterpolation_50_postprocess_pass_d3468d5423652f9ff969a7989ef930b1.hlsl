static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19726;

static const int2 _1251[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1260[5] = { 2, 4, 7, 11, 16 };
static const float3 _4653[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4971 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4971.x >= cbFI_DisplaySize.x, _4971.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4971] = float4(r_present_backbuffer.Load(int3(_4971, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4971] = float4(r_current_interpolation_source.Load(int3(_4971, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7861 = cbFI_DisplaySize - int2(1, 1);
                int2 _7862 = clamp(_4971, int2(0, 0), _7861);
                uint _7872 = uint((_7862.y * cbFI_DisplaySize.x) + _7862.x) * 2u;
                uint _7875 = rw_nfru_select.Load<uint>(_7872 * 4 + 0);
                float2 _7876 = spvUnpackHalf2x16(_7875);
                uint _7880 = rw_nfru_select.Load<uint>((_7872 + 1u) * 4 + 0);
                float2 _7881 = spvUnpackHalf2x16(_7880);
                float _7882 = _7876.x;
                float _7884 = _7881.x;
                if (_7881.y > 1.5f)
                {
                    rw_output[_4971] = float4(_7882, _7876.y, _7884, 1.0f).xyz;
                    break;
                }
                int _23345;
                float _23346;
                float3 _23347;
                float _23348;
                float _23349;
                _23349 = 0.0f;
                _23348 = 0.0f;
                _23347 = 0.0f.xxx;
                _23346 = 0.0f;
                _23345 = -2;
                float3 _23352;
                float _23353;
                float _23354;
                float _23355;
                for (; _23345 <= 2; _23349 = _23355, _23348 = _23354, _23347 = _23352, _23346 = _23353, _23345++)
                {
                    _23355 = _23349;
                    _23354 = _23348;
                    _23353 = _23346;
                    _23352 = _23347;
                    for (int _23350 = -2; _23350 <= 2; )
                    {
                        float _7778 = float((_23350 * _23350) + (_23345 * _23345));
                        float _7783 = exp(_7778 * (-0.319999992847442626953125f));
                        int2 _7788 = int2(_23350, _23345);
                        int2 _7898 = clamp(_4971 + (_7788 * int2(2, 2)), int2(0, 0), _7861);
                        uint _7908 = uint((_7898.y * cbFI_DisplaySize.x) + _7898.x) * 2u;
                        float _7805 = exp(_7778 * (-0.5f));
                        int2 _7930 = clamp(_4971 + (_7788 * int2(6, 6)), int2(0, 0), _7861);
                        _23355 += _7805;
                        _23354 += (_7805 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7930.y * cbFI_DisplaySize.x) + _7930.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23353 += _7783;
                        _23352 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7908 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7908 + 1u) * 4 + 0)).x, _19726).xyz * _7783);
                        _23350++;
                        continue;
                    }
                }
                float3 _7835 = _23347 / _23346.xxx;
                rw_output[_4971] = float4(_7835 + ((float4(_7882, _7876.y, _7884, _7881.y).xyz - _7835) * clamp(_23348 / _23349, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5483 = (float2(_4971) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5485 = float2(cbFI_MvDepthLaneSize);
        int2 _5494 = int2(floor(_5483 * _5485));
        int2 _5499 = int2(floor(_5483 * float2(cbFI_FlowLaneSize)));
        float4 _8001 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5483 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _8007 = r_warped_filled_flow_tm1.Load(int3(_5499, 0)).xy;
        float2 _8013 = r_warped_filled_motion_tp1.Load(int3(_5494, 0)).xy;
        bool _8035 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19727;
        if (_8035)
        {
            float _8048 = ((2.0f * _5483.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19727 = float2(atan(_8048) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5483.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_8048 * _8048))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19727 = _5483;
        }
        bool _5520 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19748;
        bool _19890;
        int2 _19971;
        float3 _22463;
        if (_5520)
        {
            float _19729;
            float _19731;
            _19731 = 2.0f;
            _19729 = -1.0f;
            uint _5070[9];
            float _23356;
            float _23359;
            for (int _19728 = 0; _19728 < 9; _19731 = _23359, _19729 = _23356, _19728++)
            {
                _5070[_19728] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5494 + int2((_19728 % 3) - 1, (_19728 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_5070[_19728] != 0u)
                {
                    float _23340;
                    if (_5070[_19728] == 0u)
                    {
                        _23340 = -1.0f;
                    }
                    else
                    {
                        _23340 = float((_5070[_19728] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23359 = min(_19731, _23340);
                    _23356 = max(_19729, _23340);
                }
                else
                {
                    _23359 = _19731;
                    _23356 = _19729;
                }
            }
            float _5566 = float(_19729 >= 0.0f);
            float3 _19269 = 0.0f.xxx;
            _19269.y = _5566;
            float2 _19749;
            bool _19891;
            int2 _19972;
            float3 _22464;
            if ((_19729 - _19731) > 0.0199999995529651641845703125f)
            {
                float _19737;
                int2 _19738;
                float2 _19739;
                int2 _19741;
                float2 _19747;
                _19747 = _8013;
                _19741 = _5494;
                _19739 = _8013;
                _19738 = _5494;
                _19737 = -1.0f;
                float _23364;
                int2 _23368;
                float2 _23379;
                int2 _23390;
                float2 _23423;
                float _23548;
                int _19736 = 0;
                float _23321 = 1000000000.0f;
                for (; _19736 < 9; _23321 = _23548, _19747 = _23423, _19741 = _23390, _19739 = _23379, _19738 = _23368, _19737 = _23364, _19736++)
                {
                    if (_5070[_19736] == 0u)
                    {
                        _23548 = _23321;
                        _23423 = _19747;
                        _23390 = _19741;
                        _23379 = _19739;
                        _23368 = _19738;
                        _23364 = _19737;
                        continue;
                    }
                    int2 _5601 = clamp(_5494 + int2((_19736 % 3) - 1, (_19736 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8123 = _5070[_19736] & 2147483647u;
                    uint _8155 = uint(max((int((_8123 >> 16u) & 15u) - 6), 0));
                    float2 _5607 = (float2(float((1 - (2 * int((_8123 >> 15u) & 1u))) * int(((_8123 >> uint(7)) & 127u) << _8155)), float((1 - (2 * int((_8123 >> 14u) & 1u))) * int((_8123 & 127u) << _8155))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23307;
                    if (_5070[_19736] == 0u)
                    {
                        _23307 = -1.0f;
                    }
                    else
                    {
                        _23307 = float((_5070[_19736] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5612 = _23307 - 0.100000001490116119384765625f;
                    float2 _23308;
                    if (_8035)
                    {
                        float2 _8232 = clamp((((_19727 + (_5607 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8235 = tan(_8232.x);
                        _23308 = (float2(_8235 / cbFI_DeviceToViewDepth.z, (tan(_8232.y) * sqrt(1.0f + (_8235 * _8235))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23308 = _19727 + (_5607 * cbFI_Timestep);
                    }
                    float _5619 = cbFI_Timestep - 1.0f;
                    float2 _23309;
                    if (_8035)
                    {
                        float2 _8303 = clamp((((_19727 + (_5607 * _5619)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8306 = tan(_8303.x);
                        _23309 = (float2(_8306 / cbFI_DeviceToViewDepth.z, (tan(_8303.y) * sqrt(1.0f + (_8306 * _8306))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23309 = _19727 + (_5607 * _5619);
                    }
                    bool _8339 = all(bool2(_23308.x > 0.0f.xx.x, _23308.y > 0.0f.xx.y));
                    bool _8345;
                    if (_8339)
                    {
                        _8345 = all(bool2(_23308.x < 1.0f.xx.x, _23308.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8345 = _8339;
                    }
                    float _23312;
                    if (_8345)
                    {
                        uint _8352_dummy_parameter;
                        _23312 = max((_5612 - (log(((r_depth_tm1.Load(int3(int2(floor(_23308 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8352_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23312 = 0.0f;
                    }
                    bool _8382 = all(bool2(_23309.x > 0.0f.xx.x, _23309.y > 0.0f.xx.y));
                    bool _8388;
                    if (_8382)
                    {
                        _8388 = all(bool2(_23309.x < 1.0f.xx.x, _23309.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8388 = _8382;
                    }
                    float _23313;
                    if (_8388)
                    {
                        uint _8395_dummy_parameter;
                        _23313 = _23312 + max((_5612 - (log(((r_depth_tp1.Load(int3(int2(floor(_23309 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8395_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23313 = _23312;
                    }
                    float _23365;
                    int2 _23369;
                    float2 _23380;
                    int2 _23391;
                    float2 _23424;
                    float _23549;
                    if (_23313 == 0.0f)
                    {
                        bool _5654 = _5612 > _19737;
                        bool2 _23557 = _5654.xx;
                        _23549 = _23321;
                        _23424 = float2(_23557.x ? _5607.x : _19747.x, _23557.y ? _5607.y : _19747.y);
                        _23391 = int2(_23557.x ? _5601.x : _19741.x, _23557.y ? _5601.y : _19741.y);
                        _23380 = _19739;
                        _23369 = _19738;
                        _23365 = _5654 ? _5612 : _19737;
                    }
                    else
                    {
                        bool _5663 = _23313 < _23321;
                        bool2 _23553 = _5663.xx;
                        _23549 = _5663 ? _23313 : _23321;
                        _23424 = _19747;
                        _23391 = _19741;
                        _23380 = float2(_23553.x ? _5607.x : _19739.x, _23553.y ? _5607.y : _19739.y);
                        _23369 = int2(_23553.x ? _5601.x : _19738.x, _23553.y ? _5601.y : _19738.y);
                        _23365 = _19737;
                    }
                    _23548 = _23549;
                    _23423 = _23424;
                    _23390 = _23391;
                    _23379 = _23380;
                    _23368 = _23369;
                    _23364 = _23365;
                }
                bool _5675 = _19737 < 0.0f;
                bool2 _23563 = _5675.xx;
                int2 _23566 = int2(_23563.x ? _19738.x : _19741.x, _23563.y ? _19738.y : _19741.y);
                _22464 = float3(1.0f, _5566, float(any(bool2(_23566.x != _5494.x, _23566.y != _5494.y))));
                _19972 = _23566;
                _19891 = _5675 ? false : true;
                _19749 = float2(_23563.x ? _19739.x : _19747.x, _23563.y ? _19739.y : _19747.y);
            }
            else
            {
                _22464 = _19269;
                _19972 = _5494;
                _19891 = false;
                _19749 = _8013;
            }
            _22463 = _22464;
            _19971 = _19972;
            _19890 = _19891;
            _19748 = _19749;
        }
        else
        {
            _22463 = 0.0f.xxx;
            _19971 = _5494;
            _19890 = false;
            _19748 = _8013;
        }
        float2 _19750;
        if (_8035)
        {
            float2 _8460 = clamp((((_19727 + (_19748 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8463 = tan(_8460.x);
            _19750 = (float2(_8463 / cbFI_DeviceToViewDepth.z, (tan(_8460.y) * sqrt(1.0f + (_8463 * _8463))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19750 = _19727 + (_19748 * cbFI_Timestep);
        }
        float _5698 = cbFI_Timestep - 1.0f;
        float2 _19752;
        if (_8035)
        {
            float2 _8531 = clamp((((_19727 + (_19748 * _5698)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8534 = tan(_8531.x);
            _19752 = (float2(_8534 / cbFI_DeviceToViewDepth.z, (tan(_8531.y) * sqrt(1.0f + (_8534 * _8534))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19752 = _19727 + (_19748 * _5698);
        }
        float _5703 = -cbFI_Timestep;
        float2 _19753;
        if (_8035)
        {
            float2 _8602 = clamp((((_19727 + (_8007 * _5703)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8605 = tan(_8602.x);
            _19753 = (float2(_8605 / cbFI_DeviceToViewDepth.z, (tan(_8602.y) * sqrt(1.0f + (_8605 * _8605))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19753 = _19727 + (_8007 * _5703);
        }
        float _5708 = 1.0f - cbFI_Timestep;
        float2 _19754;
        if (_8035)
        {
            float2 _8673 = clamp((((_19727 + (_8007 * _5708)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8676 = tan(_8673.x);
            _19754 = (float2(_8676 / cbFI_DeviceToViewDepth.z, (tan(_8673.y) * sqrt(1.0f + (_8676 * _8676))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19754 = _19727 + (_8007 * _5708);
        }
        float4 _8711 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19750, 0.0f);
        float3 _8712 = _8711.xyz;
        float4 _8719 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19752, 0.0f);
        float3 _8720 = _8719.xyz;
        float4 _8727 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19753, 0.0f);
        float3 _8728 = _8727.xyz;
        float4 _8735 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19754, 0.0f);
        float3 _8736 = _8735.xyz;
        float4 _8750 = exp(_8001 - max(max(max(_8001.x, _8001.y), _8001.z), _8001.w).xxxx);
        float4 _8757 = _8750 / (dot(_8750, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5724 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19961;
        float _21269;
        if (_5724)
        {
            float2 _5730 = 0.5f.xx / _5485;
            float _5733 = _5730.x;
            float _5734 = -_5733;
            float _5736 = _5730.y;
            float _5737 = -_5736;
            float2 _5739 = _5483 + float2(_5734, _5737);
            float2 _5741 = float2(cbFI_DisplaySize);
            bool _19771;
            do
            {
                bool _8837 = all(bool2(_5739.x > 0.0f.xx.x, _5739.y > 0.0f.xx.y));
                bool _8843;
                if (_8837)
                {
                    _8843 = all(bool2(_5739.x < 1.0f.xx.x, _5739.y < 1.0f.xx.y));
                }
                else
                {
                    _8843 = _8837;
                }
                if (!_8843)
                {
                    _19771 = false;
                    break;
                }
                uint _8850_dummy_parameter;
                float4x4 _19769;
                do
                {
                    float4x4 _8864;
                    bool _19768;
                    do
                    {
                        _8864 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19768 = false;
                            break;
                        }
                        uint _8898 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8898 + 32u) * 4 + 0) != 1u)
                        {
                            _19768 = false;
                            break;
                        }
                        uint _19765;
                        _19765 = 0u;
                        for (; _19765 < 4u; _19765++)
                        {
                            for (uint _19766 = 0u; _19766 < 4u; )
                            {
                                _8864[_19765][_19766] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8898 + (_19765 * 4u)) + _19766) * 4 + 0));
                                _19766++;
                                continue;
                            }
                        }
                        _19768 = true;
                        break;
                    } while(false);
                    if (_19768)
                    {
                        _19769 = _8864;
                        break;
                    }
                    _19769 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19770;
                do
                {
                    float _8975 = _5739.x;
                    float _8978 = 1.0f - _5739.y;
                    float4 _8989 = mul(float4((float2(_8975, _8978) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5739 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8850_dummy_parameter))))), 0)).x, 1.0f), _19769);
                    float _8991 = _8989.w;
                    if (!(_8991 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19770 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9004 = ((_8989.xy / _8991.xx) + 1.0f.xx) * 0.5f;
                    _19770 = float2(_9004.x - _8975, _8978 - _9004.y);
                    break;
                } while(false);
                float2 _8801 = abs(_19770);
                if (any(bool2(_8801.x > 100000.0f.xx.x, _8801.y > 100000.0f.xx.y)))
                {
                    _19771 = false;
                    break;
                }
                float _8809 = length(_19770 * _5741);
                uint _9024_dummy_parameter;
                bool _8823 = _8809 > ((8.0f * _5741.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8830;
                if (_8823)
                {
                    _8830 = length((r_motion_tp1.Load(int3(int2(floor(_5739 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9024_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5741) < (0.20000000298023223876953125f * _8809);
                }
                else
                {
                    _8830 = _8823;
                }
                _19771 = _8830;
                break;
            } while(false);
            float2 _5751 = _5483 + float2(_5733, _5737);
            bool _19778;
            do
            {
                bool _9110 = all(bool2(_5751.x > 0.0f.xx.x, _5751.y > 0.0f.xx.y));
                bool _9116;
                if (_9110)
                {
                    _9116 = all(bool2(_5751.x < 1.0f.xx.x, _5751.y < 1.0f.xx.y));
                }
                else
                {
                    _9116 = _9110;
                }
                if (!_9116)
                {
                    _19778 = false;
                    break;
                }
                uint _9123_dummy_parameter;
                float4x4 _19776;
                do
                {
                    float4x4 _9137;
                    bool _19775;
                    do
                    {
                        _9137 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19775 = false;
                            break;
                        }
                        uint _9171 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9171 + 32u) * 4 + 0) != 1u)
                        {
                            _19775 = false;
                            break;
                        }
                        uint _19772;
                        _19772 = 0u;
                        for (; _19772 < 4u; _19772++)
                        {
                            for (uint _19773 = 0u; _19773 < 4u; )
                            {
                                _9137[_19772][_19773] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9171 + (_19772 * 4u)) + _19773) * 4 + 0));
                                _19773++;
                                continue;
                            }
                        }
                        _19775 = true;
                        break;
                    } while(false);
                    if (_19775)
                    {
                        _19776 = _9137;
                        break;
                    }
                    _19776 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19777;
                do
                {
                    float _9248 = _5751.x;
                    float _9251 = 1.0f - _5751.y;
                    float4 _9262 = mul(float4((float2(_9248, _9251) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5751 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9123_dummy_parameter))))), 0)).x, 1.0f), _19776);
                    float _9264 = _9262.w;
                    if (!(_9264 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19777 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9277 = ((_9262.xy / _9264.xx) + 1.0f.xx) * 0.5f;
                    _19777 = float2(_9277.x - _9248, _9251 - _9277.y);
                    break;
                } while(false);
                float2 _9074 = abs(_19777);
                if (any(bool2(_9074.x > 100000.0f.xx.x, _9074.y > 100000.0f.xx.y)))
                {
                    _19778 = false;
                    break;
                }
                float _9082 = length(_19777 * _5741);
                uint _9297_dummy_parameter;
                bool _9096 = _9082 > ((8.0f * _5741.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9103;
                if (_9096)
                {
                    _9103 = length((r_motion_tp1.Load(int3(int2(floor(_5751 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9297_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5741) < (0.20000000298023223876953125f * _9082);
                }
                else
                {
                    _9103 = _9096;
                }
                _19778 = _9103;
                break;
            } while(false);
            float2 _5764 = _5483 + float2(_5734, _5736);
            bool _19785;
            do
            {
                bool _9383 = all(bool2(_5764.x > 0.0f.xx.x, _5764.y > 0.0f.xx.y));
                bool _9389;
                if (_9383)
                {
                    _9389 = all(bool2(_5764.x < 1.0f.xx.x, _5764.y < 1.0f.xx.y));
                }
                else
                {
                    _9389 = _9383;
                }
                if (!_9389)
                {
                    _19785 = false;
                    break;
                }
                uint _9396_dummy_parameter;
                float4x4 _19783;
                do
                {
                    float4x4 _9410;
                    bool _19782;
                    do
                    {
                        _9410 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19782 = false;
                            break;
                        }
                        uint _9444 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9444 + 32u) * 4 + 0) != 1u)
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
                                _9410[_19779][_19780] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9444 + (_19779 * 4u)) + _19780) * 4 + 0));
                                _19780++;
                                continue;
                            }
                        }
                        _19782 = true;
                        break;
                    } while(false);
                    if (_19782)
                    {
                        _19783 = _9410;
                        break;
                    }
                    _19783 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19784;
                do
                {
                    float _9521 = _5764.x;
                    float _9524 = 1.0f - _5764.y;
                    float4 _9535 = mul(float4((float2(_9521, _9524) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5764 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9396_dummy_parameter))))), 0)).x, 1.0f), _19783);
                    float _9537 = _9535.w;
                    if (!(_9537 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19784 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9550 = ((_9535.xy / _9537.xx) + 1.0f.xx) * 0.5f;
                    _19784 = float2(_9550.x - _9521, _9524 - _9550.y);
                    break;
                } while(false);
                float2 _9347 = abs(_19784);
                if (any(bool2(_9347.x > 100000.0f.xx.x, _9347.y > 100000.0f.xx.y)))
                {
                    _19785 = false;
                    break;
                }
                float _9355 = length(_19784 * _5741);
                uint _9570_dummy_parameter;
                bool _9369 = _9355 > ((8.0f * _5741.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9376;
                if (_9369)
                {
                    _9376 = length((r_motion_tp1.Load(int3(int2(floor(_5764 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9570_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5741) < (0.20000000298023223876953125f * _9355);
                }
                else
                {
                    _9376 = _9369;
                }
                _19785 = _9376;
                break;
            } while(false);
            float2 _5776 = _5483 + _5730;
            bool _19792;
            do
            {
                bool _9656 = all(bool2(_5776.x > 0.0f.xx.x, _5776.y > 0.0f.xx.y));
                bool _9662;
                if (_9656)
                {
                    _9662 = all(bool2(_5776.x < 1.0f.xx.x, _5776.y < 1.0f.xx.y));
                }
                else
                {
                    _9662 = _9656;
                }
                if (!_9662)
                {
                    _19792 = false;
                    break;
                }
                uint _9669_dummy_parameter;
                float4x4 _19790;
                do
                {
                    float4x4 _9683;
                    bool _19789;
                    do
                    {
                        _9683 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19789 = false;
                            break;
                        }
                        uint _9717 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9717 + 32u) * 4 + 0) != 1u)
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
                                _9683[_19786][_19787] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9717 + (_19786 * 4u)) + _19787) * 4 + 0));
                                _19787++;
                                continue;
                            }
                        }
                        _19789 = true;
                        break;
                    } while(false);
                    if (_19789)
                    {
                        _19790 = _9683;
                        break;
                    }
                    _19790 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19791;
                do
                {
                    float _9794 = _5776.x;
                    float _9797 = 1.0f - _5776.y;
                    float4 _9808 = mul(float4((float2(_9794, _9797) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5776 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9669_dummy_parameter))))), 0)).x, 1.0f), _19790);
                    float _9810 = _9808.w;
                    if (!(_9810 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19791 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9823 = ((_9808.xy / _9810.xx) + 1.0f.xx) * 0.5f;
                    _19791 = float2(_9823.x - _9794, _9797 - _9823.y);
                    break;
                } while(false);
                float2 _9620 = abs(_19791);
                if (any(bool2(_9620.x > 100000.0f.xx.x, _9620.y > 100000.0f.xx.y)))
                {
                    _19792 = false;
                    break;
                }
                float _9628 = length(_19791 * _5741);
                uint _9843_dummy_parameter;
                bool _9642 = _9628 > ((8.0f * _5741.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9649;
                if (_9642)
                {
                    _9649 = length((r_motion_tp1.Load(int3(int2(floor(_5776 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9843_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5741) < (0.20000000298023223876953125f * _9628);
                }
                else
                {
                    _9649 = _9642;
                }
                _19792 = _9649;
                break;
            } while(false);
            float _5782 = 0.25f * (((float(_19771) + float(_19778)) + float(_19785)) + float(_19792));
            float4 _19962;
            if (_5782 < 1.0f)
            {
                bool _19799;
                do
                {
                    bool _9929 = all(bool2(_19750.x > 0.0f.xx.x, _19750.y > 0.0f.xx.y));
                    bool _9935;
                    if (_9929)
                    {
                        _9935 = all(bool2(_19750.x < 1.0f.xx.x, _19750.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9935 = _9929;
                    }
                    if (!_9935)
                    {
                        _19799 = false;
                        break;
                    }
                    uint _9942_dummy_parameter;
                    float4x4 _19797;
                    do
                    {
                        float4x4 _9956;
                        bool _19796;
                        do
                        {
                            _9956 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19796 = false;
                                break;
                            }
                            uint _9990 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9990 + 32u) * 4 + 0) != 1u)
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
                                    _9956[_19793][_19794] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9990 + (_19793 * 4u)) + _19794) * 4 + 0));
                                    _19794++;
                                    continue;
                                }
                            }
                            _19796 = true;
                            break;
                        } while(false);
                        if (_19796)
                        {
                            _19797 = _9956;
                            break;
                        }
                        _19797 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19798;
                    do
                    {
                        float _10070 = 1.0f - _19750.y;
                        float4 _10081 = mul(float4((float2(_19750.x, _10070) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19750 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9942_dummy_parameter))))), 0)).x, 1.0f), _19797);
                        float _10083 = _10081.w;
                        if (!(_10083 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19798 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10096 = ((_10081.xy / _10083.xx) + 1.0f.xx) * 0.5f;
                        _19798 = float2(_10096.x - _19750.x, _10070 - _10096.y);
                        break;
                    } while(false);
                    float2 _9893 = abs(_19798);
                    if (any(bool2(_9893.x > 100000.0f.xx.x, _9893.y > 100000.0f.xx.y)))
                    {
                        _19799 = false;
                        break;
                    }
                    float _9901 = length(_19798 * _5741);
                    uint _10116_dummy_parameter;
                    bool _9915 = _9901 > ((8.0f * _5741.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9922;
                    if (_9915)
                    {
                        _9922 = length((r_motion_tp1.Load(int3(int2(floor(_19750 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10116_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5741) < (0.20000000298023223876953125f * _9901);
                    }
                    else
                    {
                        _9922 = _9915;
                    }
                    _19799 = _9922;
                    break;
                } while(false);
                bool _19806;
                do
                {
                    bool _10202 = all(bool2(_19752.x > 0.0f.xx.x, _19752.y > 0.0f.xx.y));
                    bool _10208;
                    if (_10202)
                    {
                        _10208 = all(bool2(_19752.x < 1.0f.xx.x, _19752.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10208 = _10202;
                    }
                    if (!_10208)
                    {
                        _19806 = false;
                        break;
                    }
                    uint _10215_dummy_parameter;
                    float4x4 _19804;
                    do
                    {
                        float4x4 _10229;
                        bool _19803;
                        do
                        {
                            _10229 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19803 = false;
                                break;
                            }
                            uint _10263 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10263 + 32u) * 4 + 0) != 1u)
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
                                    _10229[_19800][_19801] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10263 + (_19800 * 4u)) + _19801) * 4 + 0));
                                    _19801++;
                                    continue;
                                }
                            }
                            _19803 = true;
                            break;
                        } while(false);
                        if (_19803)
                        {
                            _19804 = _10229;
                            break;
                        }
                        _19804 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19805;
                    do
                    {
                        float _10343 = 1.0f - _19752.y;
                        float4 _10354 = mul(float4((float2(_19752.x, _10343) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19752 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10215_dummy_parameter))))), 0)).x, 1.0f), _19804);
                        float _10356 = _10354.w;
                        if (!(_10356 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19805 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10369 = ((_10354.xy / _10356.xx) + 1.0f.xx) * 0.5f;
                        _19805 = float2(_10369.x - _19752.x, _10343 - _10369.y);
                        break;
                    } while(false);
                    float2 _10166 = abs(_19805);
                    if (any(bool2(_10166.x > 100000.0f.xx.x, _10166.y > 100000.0f.xx.y)))
                    {
                        _19806 = false;
                        break;
                    }
                    float _10174 = length(_19805 * _5741);
                    uint _10389_dummy_parameter;
                    bool _10188 = _10174 > ((8.0f * _5741.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10195;
                    if (_10188)
                    {
                        _10195 = length((r_motion_tp1.Load(int3(int2(floor(_19752 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10389_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5741) < (0.20000000298023223876953125f * _10174);
                    }
                    else
                    {
                        _10195 = _10188;
                    }
                    _19806 = _10195;
                    break;
                } while(false);
                bool _19813;
                do
                {
                    bool _10475 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                    bool _10481;
                    if (_10475)
                    {
                        _10481 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10481 = _10475;
                    }
                    if (!_10481)
                    {
                        _19813 = false;
                        break;
                    }
                    uint _10488_dummy_parameter;
                    float4x4 _19811;
                    do
                    {
                        float4x4 _10502;
                        bool _19810;
                        do
                        {
                            _10502 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19810 = false;
                                break;
                            }
                            uint _10536 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10536 + 32u) * 4 + 0) != 1u)
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
                                    _10502[_19807][_19808] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10536 + (_19807 * 4u)) + _19808) * 4 + 0));
                                    _19808++;
                                    continue;
                                }
                            }
                            _19810 = true;
                            break;
                        } while(false);
                        if (_19810)
                        {
                            _19811 = _10502;
                            break;
                        }
                        _19811 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19812;
                    do
                    {
                        float _10616 = 1.0f - _19753.y;
                        float4 _10627 = mul(float4((float2(_19753.x, _10616) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10488_dummy_parameter))))), 0)).x, 1.0f), _19811);
                        float _10629 = _10627.w;
                        if (!(_10629 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19812 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10642 = ((_10627.xy / _10629.xx) + 1.0f.xx) * 0.5f;
                        _19812 = float2(_10642.x - _19753.x, _10616 - _10642.y);
                        break;
                    } while(false);
                    float2 _10439 = abs(_19812);
                    if (any(bool2(_10439.x > 100000.0f.xx.x, _10439.y > 100000.0f.xx.y)))
                    {
                        _19813 = false;
                        break;
                    }
                    float _10447 = length(_19812 * _5741);
                    uint _10662_dummy_parameter;
                    bool _10461 = _10447 > ((8.0f * _5741.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10468;
                    if (_10461)
                    {
                        _10468 = length((r_motion_tp1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10662_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5741) < (0.20000000298023223876953125f * _10447);
                    }
                    else
                    {
                        _10468 = _10461;
                    }
                    _19813 = _10468;
                    break;
                } while(false);
                bool _19820;
                do
                {
                    bool _10748 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                    bool _10754;
                    if (_10748)
                    {
                        _10754 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10754 = _10748;
                    }
                    if (!_10754)
                    {
                        _19820 = false;
                        break;
                    }
                    uint _10761_dummy_parameter;
                    float4x4 _19818;
                    do
                    {
                        float4x4 _10775;
                        bool _19817;
                        do
                        {
                            _10775 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19817 = false;
                                break;
                            }
                            uint _10809 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10809 + 32u) * 4 + 0) != 1u)
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
                                    _10775[_19814][_19815] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10809 + (_19814 * 4u)) + _19815) * 4 + 0));
                                    _19815++;
                                    continue;
                                }
                            }
                            _19817 = true;
                            break;
                        } while(false);
                        if (_19817)
                        {
                            _19818 = _10775;
                            break;
                        }
                        _19818 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19819;
                    do
                    {
                        float _10889 = 1.0f - _19754.y;
                        float4 _10900 = mul(float4((float2(_19754.x, _10889) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10761_dummy_parameter))))), 0)).x, 1.0f), _19818);
                        float _10902 = _10900.w;
                        if (!(_10902 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19819 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10915 = ((_10900.xy / _10902.xx) + 1.0f.xx) * 0.5f;
                        _19819 = float2(_10915.x - _19754.x, _10889 - _10915.y);
                        break;
                    } while(false);
                    float2 _10712 = abs(_19819);
                    if (any(bool2(_10712.x > 100000.0f.xx.x, _10712.y > 100000.0f.xx.y)))
                    {
                        _19820 = false;
                        break;
                    }
                    float _10720 = length(_19819 * _5741);
                    uint _10935_dummy_parameter;
                    bool _10734 = _10720 > ((8.0f * _5741.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10741;
                    if (_10734)
                    {
                        _10741 = length((r_motion_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10935_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5741) < (0.20000000298023223876953125f * _10720);
                    }
                    else
                    {
                        _10741 = _10734;
                    }
                    _19820 = _10741;
                    break;
                } while(false);
                float4 _5809 = _8757 * float4(_19799 ? 0.0f : 1.0f, _19806 ? 0.0f : 1.0f, _19813 ? 0.0f : 1.0f, _19820 ? 0.0f : 1.0f);
                float _5811 = dot(_5809, 1.0f.xxxx);
                float4 _19963;
                if (_5811 > 0.001000000047497451305389404296875f)
                {
                    _19963 = _5809 / _5811.xxxx;
                }
                else
                {
                    _19963 = _8757;
                }
                _19962 = _19963;
            }
            else
            {
                _19962 = _8757;
            }
            _21269 = _5782;
            _19961 = _19962;
        }
        else
        {
            _21269 = 0.0f;
            _19961 = _8757;
        }
        bool _5828 = _5520 && (!_19890);
        bool _5837;
        if (_5828)
        {
            _5837 = (_19961.z + _19961.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5837 = _5828;
        }
        bool _5848;
        if (_5837)
        {
            _5848 = length((_19753 - _19750) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5848 = _5837;
        }
        bool _20050;
        if (_5848)
        {
            uint4 _10964 = r_warped_motion_qdata_tp1.Load(int3(_19971, 0));
            uint _10965 = _10964.x;
            bool _20053;
            if (_10965 != 0u)
            {
                float _20039;
                if (_10965 == 0u)
                {
                    _20039 = -1.0f;
                }
                else
                {
                    _20039 = float((_10965 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5858 = _20039 - 0.12000000476837158203125f;
                bool _10984 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                bool _10990;
                if (_10984)
                {
                    _10990 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                }
                else
                {
                    _10990 = _10984;
                }
                bool _5868;
                if (_10990)
                {
                    uint _10997_dummy_parameter;
                    _5868 = (log(((r_depth_tm1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10997_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5858;
                }
                else
                {
                    _5868 = _10990;
                }
                bool _5882;
                if (!_5868)
                {
                    bool _11027 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                    bool _11033;
                    if (_11027)
                    {
                        _11033 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11033 = _11027;
                    }
                    bool _5880;
                    if (_11033)
                    {
                        uint _11040_dummy_parameter;
                        _5880 = (log(((r_depth_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11040_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5858;
                    }
                    else
                    {
                        _5880 = _11033;
                    }
                    _5882 = _5880;
                }
                else
                {
                    _5882 = _5868;
                }
                _20053 = _5882;
            }
            else
            {
                _20053 = false;
            }
            _20050 = _20053;
        }
        else
        {
            _20050 = false;
        }
        bool _5887 = _19890 || _20050;
        bool _5892;
        if (_5887)
        {
            bool _11070 = all(bool2(_19750.x > 0.0f.xx.x, _19750.y > 0.0f.xx.y));
            bool _11076;
            if (_11070)
            {
                _11076 = all(bool2(_19750.x < 1.0f.xx.x, _19750.y < 1.0f.xx.y));
            }
            else
            {
                _11076 = _11070;
            }
            _5892 = _11076;
        }
        else
        {
            _5892 = _5887;
        }
        bool _5897;
        if (_5892)
        {
            bool _11081 = all(bool2(_19752.x > 0.0f.xx.x, _19752.y > 0.0f.xx.y));
            bool _11087;
            if (_11081)
            {
                _11087 = all(bool2(_19752.x < 1.0f.xx.x, _19752.y < 1.0f.xx.y));
            }
            else
            {
                _11087 = _11081;
            }
            _5897 = _11087;
        }
        else
        {
            _5897 = _5892;
        }
        float4 _20173;
        if (_5897)
        {
            float _5903 = _19961.x + _19961.y;
            float _5908 = _19961.z + _19961.w;
            float _20068;
            if (_5903 > 0.001000000047497451305389404296875f)
            {
                _20068 = _19961.x / _5903;
            }
            else
            {
                _20068 = _5708;
            }
            _20173 = float4(_19961.x + (_5908 * _20068), _19961.y + (_5908 * (1.0f - _20068)), 0.0f, 0.0f);
        }
        else
        {
            _20173 = _19961;
        }
        bool _11115 = (cbFI_pad0 & 1024u) != 0u;
        bool _11091 = !_11115;
        bool _11092 = !_11091;
        bool _11109;
        if (_11092)
        {
            _11109 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19971.y * cbFI_MvDepthLaneSize.x) + _19971.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11109 = _11091;
        }
        bool _11141;
        if (_11092)
        {
            _11141 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5499.y * cbFI_FlowLaneSize.x) + _5499.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11141 = _11091;
        }
        float _5943 = float(_11141);
        bool _20194;
        float4 _20233;
        float3 _22160;
        if (_11115)
        {
            bool _5953;
            if (_11109)
            {
                _5953 = all(bool2(_19750.x > 0.0f.xx.x, _19750.y > 0.0f.xx.y));
            }
            else
            {
                _5953 = _11109;
            }
            bool _5959;
            if (_5953)
            {
                _5959 = all(bool2(_19750.x < 1.0f.xx.x, _19750.y < 1.0f.xx.y));
            }
            else
            {
                _5959 = _5953;
            }
            bool _5966;
            if (_11109)
            {
                _5966 = all(bool2(_19752.x > 0.0f.xx.x, _19752.y > 0.0f.xx.y));
            }
            else
            {
                _5966 = _11109;
            }
            bool _5972;
            if (_5966)
            {
                _5972 = all(bool2(_19752.x < 1.0f.xx.x, _19752.y < 1.0f.xx.y));
            }
            else
            {
                _5972 = _5966;
            }
            bool _5979;
            if (_11141)
            {
                _5979 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
            }
            else
            {
                _5979 = _11141;
            }
            bool _5985;
            if (_5979)
            {
                _5985 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
            }
            else
            {
                _5985 = _5979;
            }
            bool _5992;
            if (_11141)
            {
                _5992 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
            }
            else
            {
                _5992 = _11141;
            }
            bool _5998;
            if (_5992)
            {
                _5998 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
            }
            else
            {
                _5998 = _5992;
            }
            bool _6000 = !_11109;
            if (_6000)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11183;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11183);
                }
            }
            bool _6005 = !_11141;
            if (_6005)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11193;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11193);
                }
            }
            if (_11109 && _6005)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11203;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11203);
                }
            }
            if (_6000 && _11141)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11213;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11213);
                }
            }
            float _6024 = float(_5959);
            float _6026 = float(_5972);
            bool _6029 = _5985 && _5998;
            float _20102;
            if (_6029)
            {
                _20102 = 1.0f;
            }
            else
            {
                _20102 = (_5985 || _5998) ? 0.5f : 0.0f;
            }
            bool _20117;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5959)) && (!_5972))
            {
                bool _6059;
                if (_6029)
                {
                    float _20110;
                    do
                    {
                        bool _11297 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                        bool _11303;
                        if (_11297)
                        {
                            _11303 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11303 = _11297;
                        }
                        bool _11234 = !_11303;
                        bool _11241;
                        if (!_11234)
                        {
                            bool _11308 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                            bool _11314;
                            if (_11308)
                            {
                                _11314 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11314 = _11308;
                            }
                            _11241 = !_11314;
                        }
                        else
                        {
                            _11241 = _11234;
                        }
                        if (_11241)
                        {
                            _20110 = 0.0f;
                            break;
                        }
                        uint _11321_dummy_parameter;
                        uint _11337_dummy_parameter;
                        float4x4 _20109;
                        do
                        {
                            float4x4 _11351;
                            bool _20108;
                            do
                            {
                                _11351 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20108 = false;
                                    break;
                                }
                                uint _11385 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11385 + 32u) * 4 + 0) != 1u)
                                {
                                    _20108 = false;
                                    break;
                                }
                                uint _20105;
                                _20105 = 0u;
                                for (; _20105 < 4u; _20105++)
                                {
                                    for (uint _20106 = 0u; _20106 < 4u; )
                                    {
                                        _11351[_20105][_20106] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11385 + 16u) + (_20105 * 4u)) + _20106) * 4 + 0));
                                        _20106++;
                                        continue;
                                    }
                                }
                                _20108 = true;
                                break;
                            } while(false);
                            if (_20108)
                            {
                                _20109 = _11351;
                                break;
                            }
                            _20109 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11262 = mul(float4((float2(_19753.x, 1.0f - _19753.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11321_dummy_parameter))))), 0)).x, 1.0f), _20109);
                        float _11264 = _11262.w;
                        if (abs(_11264) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20110 = 0.0f;
                            break;
                        }
                        float _11275 = abs(cbFI_DeviceToViewDepth.y / ((_11262.z / _11264) - cbFI_DeviceToViewDepth.x));
                        float _11278 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11337_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20110 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11275 - _11278) / max(max(_11275, _11278), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _6059 = _20110 >= 0.5f;
                }
                else
                {
                    _6059 = _6029;
                }
                bool _6067;
                if (_6059)
                {
                    _6067 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _6067 = _6059;
                }
                bool _20118;
                if (_6067)
                {
                    uint _11489_dummy_parameter;
                    float4x4 _20115;
                    do
                    {
                        float4x4 _11503;
                        bool _20114;
                        do
                        {
                            _11503 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20114 = false;
                                break;
                            }
                            uint _11537 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11537 + 32u) * 4 + 0) != 1u)
                            {
                                _20114 = false;
                                break;
                            }
                            uint _20111;
                            _20111 = 0u;
                            for (; _20111 < 4u; _20111++)
                            {
                                for (uint _20112 = 0u; _20112 < 4u; )
                                {
                                    _11503[_20111][_20112] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11537 + 16u) + (_20111 * 4u)) + _20112) * 4 + 0));
                                    _20112++;
                                    continue;
                                }
                            }
                            _20114 = true;
                            break;
                        } while(false);
                        if (_20114)
                        {
                            _20115 = _11503;
                            break;
                        }
                        _20115 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20116;
                    do
                    {
                        float _11617 = 1.0f - _19753.y;
                        float4 _11628 = mul(float4((float2(_19753.x, _11617) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11489_dummy_parameter))))), 0)).x, 1.0f), _20115);
                        float _11630 = _11628.w;
                        if (!(_11630 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20116 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11643 = ((_11628.xy / _11630.xx) + 1.0f.xx) * 0.5f;
                        _20116 = float2(_11643.x - _19753.x, _11617 - _11643.y);
                        break;
                    } while(false);
                    float2 _6080 = float2(cbFI_DisplaySize);
                    _20118 = length(((_19753 + _20116) - _19754) * _6080) <= ((0.100000001490116119384765625f * length(_20116 * _6080)) + 8.0f);
                }
                else
                {
                    _20118 = _6059;
                }
                _20117 = _20118;
            }
            else
            {
                _20117 = true;
            }
            bool _6094 = !_20117;
            bool _23567 = _6094 ? false : _5998;
            bool _23568 = _6094 ? false : _5985;
            bool _20195;
            float4 _20234;
            if (!(((_5959 && _5972) && _23568) && _23567))
            {
                float4 _6116 = _20173 * float4(_6024, _6026, float(_23568), float(_23567));
                float _6118 = dot(_6116, 1.0f.xxxx);
                bool _6121 = !(_6118 > 0.0f);
                float4 _20235;
                if (!_6121)
                {
                    _20235 = _6116 / _6118.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11665;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11665);
                    }
                    _20235 = 0.0f.xxxx;
                }
                _20234 = _20235;
                _20195 = _6121;
            }
            else
            {
                _20234 = _20173;
                _20195 = false;
            }
            _22160 = float3(_6024, _6026, _20102);
            _20233 = _20234;
            _20194 = _20195;
        }
        else
        {
            _22160 = float3(float(_11109), _5943, 0.0f);
            _20233 = _20173;
            _20194 = false;
        }
        bool _6139 = !_20194;
        float4 _20326;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6139)
        {
            float _6146 = _20233.x + _20233.y;
            float4 _20327;
            if (_6146 > 0.001000000047497451305389404296875f)
            {
                _20327 = float4(_20233.x / _6146, _20233.y / _6146, 0.0f, 0.0f);
            }
            else
            {
                _20327 = float4(_5708, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20326 = _20327;
        }
        else
        {
            _20326 = _20233;
        }
        float4 _20503;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6139) && _11109)
        {
            float _20300;
            do
            {
                uint4 _11805 = r_warped_motion_qdata_tp1.Load(int3(_19971, 0));
                uint _11806 = _11805.x;
                if (_11806 != 0u)
                {
                    float _20299;
                    if (_11806 == 0u)
                    {
                        _20299 = -1.0f;
                    }
                    else
                    {
                        _20299 = float((_11806 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20300 = _20299;
                    break;
                }
                int _20282;
                uint _20283;
                _20283 = _11806;
                _20282 = -1;
                uint _20298;
                for (; _20282 <= 1; _20283 = _20298, _20282++)
                {
                    _20298 = _20283;
                    for (int _20296 = -1; _20296 <= 1; )
                    {
                        _20298 = max(_20298, r_warped_motion_qdata_tp1.Load(int3(clamp(_19971 + int2(_20296, _20282), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20296++;
                        continue;
                    }
                }
                if (_20283 != 0u)
                {
                    float _20295;
                    if (_20283 == 0u)
                    {
                        _20295 = -1.0f;
                    }
                    else
                    {
                        _20295 = float((_20283 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20300 = _20295;
                    break;
                }
                uint _20285;
                _20285 = 4294967295u;
                uint _23460;
                for (int _20284 = 0; _20284 < 8; _20285 = _23460, _20284++)
                {
                    int _20288 = 0;
                    for (;;)
                    {
                        if (_20288 < 5)
                        {
                            int2 _11756 = _19971 + (_1251[_20284] * _1260[_20288].xx);
                            bool _11759 = any(bool2(_11756.x < int2(0, 0).x, _11756.y < int2(0, 0).y));
                            bool _11767;
                            if (!_11759)
                            {
                                _11767 = any(bool2(_11756.x >= cbFI_MvDepthLaneSize.x, _11756.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11767 = _11759;
                            }
                            if (_11767)
                            {
                                _23460 = _20285;
                                break;
                            }
                            uint4 _11845 = r_warped_motion_qdata_tp1.Load(int3(_11756, 0));
                            uint _11846 = _11845.x;
                            if (_11846 != 0u)
                            {
                                _23460 = min(_20285, _11846);
                                break;
                            }
                            _20288++;
                            continue;
                        }
                        else
                        {
                            _23460 = _20285;
                            break;
                        }
                    }
                }
                float _20287;
                if (_20285 == 4294967295u)
                {
                    _20287 = -1.0f;
                }
                else
                {
                    float _20286;
                    if (_20285 == 0u)
                    {
                        _20286 = -1.0f;
                    }
                    else
                    {
                        _20286 = float((_20285 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20287 = _20286;
                }
                _20300 = _20287;
                break;
            } while(false);
            float _6182 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6185 = r_warped_motion_qdata_tp1.Load(int3(_19971, 0)).x == 0u;
            bool _6191;
            if (_6185)
            {
                bool _11871 = all(bool2(_19750.x > 0.0f.xx.x, _19750.y > 0.0f.xx.y));
                bool _11877;
                if (_11871)
                {
                    _11877 = all(bool2(_19750.x < 1.0f.xx.x, _19750.y < 1.0f.xx.y));
                }
                else
                {
                    _11877 = _11871;
                }
                _6191 = _11877;
            }
            else
            {
                _6191 = _6185;
            }
            bool _6196;
            if (_6191)
            {
                bool _11882 = all(bool2(_19752.x > 0.0f.xx.x, _19752.y > 0.0f.xx.y));
                bool _11888;
                if (_11882)
                {
                    _11888 = all(bool2(_19752.x < 1.0f.xx.x, _19752.y < 1.0f.xx.y));
                }
                else
                {
                    _11888 = _11882;
                }
                _6196 = _11888;
            }
            else
            {
                _6196 = _6191;
            }
            bool _20312;
            float4 _20321;
            if (_6196)
            {
                uint _11895_dummy_parameter;
                float _11919 = log(((r_depth_tm1.Load(int3(int2(floor(_19750 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11895_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _11927_dummy_parameter;
                float _11951 = log(((r_depth_tp1.Load(int3(int2(floor(_19752 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11927_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _6207 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6214;
                if (_6207)
                {
                    _6214 = _11951 > (_11919 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6214 = _6207;
                }
                bool _20317;
                float4 _20339;
                if (_6214)
                {
                    _20339 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20317 = true;
                }
                else
                {
                    bool _6220 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6227;
                    if (_6220)
                    {
                        _6227 = _11919 > (_11951 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6227 = _6220;
                    }
                    bool4 _23569 = _6227.xxxx;
                    _20339 = float4(_23569.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20326.x, _23569.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20326.y, _23569.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20326.z, _23569.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20326.w);
                    _20317 = _6227 ? true : false;
                }
                _20321 = _20339;
                _20312 = _20317;
            }
            else
            {
                _20321 = _20326;
                _20312 = false;
            }
            float4 _20394;
            if (_20312)
            {
                _20394 = 1.0f.xxxx;
            }
            else
            {
                bool _6238 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6244;
                if (_6238)
                {
                    _6244 = _20321.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6244 = _6238;
                }
                bool _6249;
                if (_6244)
                {
                    bool _11957 = all(bool2(_19752.x > 0.0f.xx.x, _19752.y > 0.0f.xx.y));
                    bool _11963;
                    if (_11957)
                    {
                        _11963 = all(bool2(_19752.x < 1.0f.xx.x, _19752.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11963 = _11957;
                    }
                    _6249 = _11963;
                }
                else
                {
                    _6249 = _6244;
                }
                float4 _20395;
                if (_6249)
                {
                    float _20348;
                    if (_20300 >= 0.0f)
                    {
                        _20348 = _20300 - _6182;
                    }
                    else
                    {
                        float _20344;
                        _20344 = 2.0f;
                        float _12020;
                        for (int _20343 = 0; _20343 < 24; _20344 = _12020, _20343++)
                        {
                            float _11984 = float(_20343 & 7) * 0.785398185253143310546875f;
                            int _11986 = _20343 >> 3;
                            int _20345;
                            if (_11986 == 0)
                            {
                                _20345 = 16;
                            }
                            else
                            {
                                _20345 = (_11986 == 1) ? 48 : 96;
                            }
                            uint _12052_dummy_parameter;
                            _12020 = min(_20344, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19752 + ((cbFI_MvDepthLaneSizeRcp * float(_20345)) * float2(cos(_11984), sin(_11984))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12052_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20348 = _20344;
                    }
                    uint _12084_dummy_parameter;
                    float4 _20396;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_19752 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12084_dummy_parameter))))), 0)).x) > ((exp((_20348 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20396 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20396 = 1.0f.xxxx;
                    }
                    _20395 = _20396;
                }
                else
                {
                    _20395 = 1.0f.xxxx;
                }
                _20394 = _20395;
            }
            bool _6277 = _20300 >= 0.0f;
            bool _6278 = (!_20312) && _6277;
            bool _6285;
            if (_6278)
            {
                _6285 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6285 = _6278;
            }
            bool _6291;
            if (_6285)
            {
                _6291 = _20321.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6291 = _6285;
            }
            bool _6296;
            if (_6291)
            {
                bool _12109 = all(bool2(_19750.x > 0.0f.xx.x, _19750.y > 0.0f.xx.y));
                bool _12115;
                if (_12109)
                {
                    _12115 = all(bool2(_19750.x < 1.0f.xx.x, _19750.y < 1.0f.xx.y));
                }
                else
                {
                    _12115 = _12109;
                }
                _6296 = _12115;
            }
            else
            {
                _6296 = _6291;
            }
            float4 _20419;
            if (_6296)
            {
                float _20388;
                if (_6277)
                {
                    _20388 = _20300 - _6182;
                }
                else
                {
                    float _20384;
                    _20384 = 2.0f;
                    float _12172;
                    for (int _20383 = 0; _20383 < 24; _20384 = _12172, _20383++)
                    {
                        float _12136 = float(_20383 & 7) * 0.785398185253143310546875f;
                        int _12138 = _20383 >> 3;
                        int _20385;
                        if (_12138 == 0)
                        {
                            _20385 = 16;
                        }
                        else
                        {
                            _20385 = (_12138 == 1) ? 48 : 96;
                        }
                        uint _12188_dummy_parameter;
                        _12172 = min(_20384, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19750 + ((cbFI_MvDepthLaneSizeRcp * float(_20385)) * float2(cos(_12136), sin(_12136))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12188_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20388 = _20384;
                }
                uint _12236_dummy_parameter;
                float4 _20420;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_19750 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12236_dummy_parameter))))), 0)).x) > ((exp((_20388 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19421 = _20394;
                    _19421.x = 0.0f;
                    _20420 = _19421;
                }
                else
                {
                    _20420 = _20394;
                }
                _20419 = _20420;
            }
            else
            {
                _20419 = _20394;
            }
            float4 _20432;
            if (_6278)
            {
                float _12263 = (exp(((_20300 - _6182) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6334 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6340;
                if (_6334)
                {
                    _6340 = _20321.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6340 = _6334;
                }
                bool _6345;
                if (_6340)
                {
                    bool _12268 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                    bool _12274;
                    if (_12268)
                    {
                        _12274 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12274 = _12268;
                    }
                    _6345 = _12274;
                }
                else
                {
                    _6345 = _6340;
                }
                bool _6353;
                if (_6345)
                {
                    uint _12281_dummy_parameter;
                    _6353 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12281_dummy_parameter))))), 0)).x) > _12263;
                }
                else
                {
                    _6353 = _6345;
                }
                float4 _20430;
                if (_6353)
                {
                    float4 _19424 = _20419;
                    _19424.w = 0.0f;
                    _20430 = _19424;
                }
                else
                {
                    _20430 = _20419;
                }
                bool _6360 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6366;
                if (_6360)
                {
                    _6366 = _20321.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6366 = _6360;
                }
                bool _6371;
                if (_6366)
                {
                    bool _12299 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                    bool _12305;
                    if (_12299)
                    {
                        _12305 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12305 = _12299;
                    }
                    _6371 = _12305;
                }
                else
                {
                    _6371 = _6366;
                }
                bool _6379;
                if (_6371)
                {
                    uint _12312_dummy_parameter;
                    _6379 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12312_dummy_parameter))))), 0)).x) > _12263;
                }
                else
                {
                    _6379 = _6371;
                }
                float4 _20433;
                if (_6379)
                {
                    float4 _19427 = _20430;
                    _19427.z = 0.0f;
                    _20433 = _19427;
                }
                else
                {
                    _20433 = _20430;
                }
                _20432 = _20433;
            }
            else
            {
                _20432 = _20419;
            }
            float4 _20504;
            if (any(bool4(_20432.x < 1.0f.xxxx.x, _20432.y < 1.0f.xxxx.y, _20432.z < 1.0f.xxxx.z, _20432.w < 1.0f.xxxx.w)))
            {
                float4 _6390 = _20321 * _20432;
                float _6392 = dot(_6390, 1.0f.xxxx);
                float4 _20505;
                if (_6392 > 0.0f)
                {
                    _20505 = _6390 / _6392.xxxx;
                }
                else
                {
                    bool _6403 = _20432.y == 0.0f;
                    bool _6409;
                    if (_6403)
                    {
                        _6409 = _20432.x > 0.0f;
                    }
                    else
                    {
                        _6409 = _6403;
                    }
                    bool _6414;
                    if (_6409)
                    {
                        bool _12330 = all(bool2(_19750.x > 0.0f.xx.x, _19750.y > 0.0f.xx.y));
                        bool _12336;
                        if (_12330)
                        {
                            _12336 = all(bool2(_19750.x < 1.0f.xx.x, _19750.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12336 = _12330;
                        }
                        _6414 = _12336;
                    }
                    else
                    {
                        _6414 = _6409;
                    }
                    float4 _20506;
                    if (_6414)
                    {
                        _20506 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6419 = _20432.x == 0.0f;
                        bool _6425;
                        if (_6419)
                        {
                            _6425 = _20432.y > 0.0f;
                        }
                        else
                        {
                            _6425 = _6419;
                        }
                        bool _6430;
                        if (_6425)
                        {
                            bool _12341 = all(bool2(_19752.x > 0.0f.xx.x, _19752.y > 0.0f.xx.y));
                            bool _12347;
                            if (_12341)
                            {
                                _12347 = all(bool2(_19752.x < 1.0f.xx.x, _19752.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12347 = _12341;
                            }
                            _6430 = _12347;
                        }
                        else
                        {
                            _6430 = _6425;
                        }
                        bool4 _23572 = _6430.xxxx;
                        _20506 = float4(_23572.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20321.x, _23572.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20321.y, _23572.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20321.z, _23572.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20321.w);
                    }
                    _20505 = _20506;
                }
                _20504 = _20505;
            }
            else
            {
                _20504 = _20321;
            }
            _20503 = _20504;
        }
        else
        {
            _20503 = _20326;
        }
        float4 _21233;
        bool _21539;
        float3 _21863;
        if (((cbFI_pad0 & 32768u) != 0u) && _6139)
        {
            bool _6447 = _20503.x > 0.00999999977648258209228515625f;
            bool _6450 = _20503.y > 0.00999999977648258209228515625f;
            bool _6459 = (_20503.z + _20503.w) > 0.0199999995529651641845703125f;
            bool _6465;
            if (_6459)
            {
                bool _12352 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                bool _12358;
                if (_12352)
                {
                    _12358 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                }
                else
                {
                    _12358 = _12352;
                }
                _6465 = _12358;
            }
            else
            {
                _6465 = _6459;
            }
            bool _6470;
            if (_6465)
            {
                bool _12363 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                bool _12369;
                if (_12363)
                {
                    _12369 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                }
                else
                {
                    _12369 = _12363;
                }
                _6470 = _12369;
            }
            else
            {
                _6470 = _6465;
            }
            bool _6477;
            if (_6470)
            {
                float _20519;
                do
                {
                    bool _12452 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                    bool _12458;
                    if (_12452)
                    {
                        _12458 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12458 = _12452;
                    }
                    bool _12389 = !_12458;
                    bool _12396;
                    if (!_12389)
                    {
                        bool _12463 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                        bool _12469;
                        if (_12463)
                        {
                            _12469 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12469 = _12463;
                        }
                        _12396 = !_12469;
                    }
                    else
                    {
                        _12396 = _12389;
                    }
                    if (_12396)
                    {
                        _20519 = 0.0f;
                        break;
                    }
                    uint _12476_dummy_parameter;
                    uint _12492_dummy_parameter;
                    float4x4 _20518;
                    do
                    {
                        float4x4 _12506;
                        bool _20517;
                        do
                        {
                            _12506 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20517 = false;
                                break;
                            }
                            uint _12540 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12540 + 32u) * 4 + 0) != 1u)
                            {
                                _20517 = false;
                                break;
                            }
                            uint _20514;
                            _20514 = 0u;
                            for (; _20514 < 4u; _20514++)
                            {
                                for (uint _20515 = 0u; _20515 < 4u; )
                                {
                                    _12506[_20514][_20515] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12540 + 16u) + (_20514 * 4u)) + _20515) * 4 + 0));
                                    _20515++;
                                    continue;
                                }
                            }
                            _20517 = true;
                            break;
                        } while(false);
                        if (_20517)
                        {
                            _20518 = _12506;
                            break;
                        }
                        _20518 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12417 = mul(float4((float2(_19753.x, 1.0f - _19753.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12476_dummy_parameter))))), 0)).x, 1.0f), _20518);
                    float _12419 = _12417.w;
                    if (abs(_12419) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20519 = 0.0f;
                        break;
                    }
                    float _12430 = abs(cbFI_DeviceToViewDepth.y / ((_12417.z / _12419) - cbFI_DeviceToViewDepth.x));
                    float _12433 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12492_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20519 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12430 - _12433) / max(max(_12430, _12433), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6477 = _20519 < 0.5f;
            }
            else
            {
                _6477 = _6470;
            }
            float4 _20538;
            if (_6477)
            {
                uint _12644_dummy_parameter;
                uint _12675_dummy_parameter;
                float4 _20539;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12644_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12675_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20539 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20539 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20538 = _20539;
            }
            else
            {
                _20538 = 1.0f.xxxx;
            }
            bool _6501;
            if (_11109)
            {
                bool _12704 = all(bool2(_19750.x > 0.0f.xx.x, _19750.y > 0.0f.xx.y));
                bool _12710;
                if (_12704)
                {
                    _12710 = all(bool2(_19750.x < 1.0f.xx.x, _19750.y < 1.0f.xx.y));
                }
                else
                {
                    _12710 = _12704;
                }
                _6501 = _12710;
            }
            else
            {
                _6501 = _11109;
            }
            bool _6507;
            if (_11109)
            {
                bool _12715 = all(bool2(_19752.x > 0.0f.xx.x, _19752.y > 0.0f.xx.y));
                bool _12721;
                if (_12715)
                {
                    _12721 = all(bool2(_19752.x < 1.0f.xx.x, _19752.y < 1.0f.xx.y));
                }
                else
                {
                    _12721 = _12715;
                }
                _6507 = _12721;
            }
            else
            {
                _6507 = _11109;
            }
            bool _6513;
            if (_11141)
            {
                bool _12726 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                bool _12732;
                if (_12726)
                {
                    _12732 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                }
                else
                {
                    _12732 = _12726;
                }
                _6513 = _12732;
            }
            else
            {
                _6513 = _11141;
            }
            bool _6519;
            if (_11141)
            {
                bool _12737 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                bool _12743;
                if (_12737)
                {
                    _12743 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                }
                else
                {
                    _12743 = _12737;
                }
                _6519 = _12743;
            }
            else
            {
                _6519 = _11141;
            }
            bool _6522 = _6513 != _6519;
            bool _6528;
            if (_6522)
            {
                _6528 = _6501 || _6507;
            }
            else
            {
                _6528 = _6522;
            }
            float4 _20641;
            if (_6528)
            {
                float4 _19454 = _20538;
                _19454.z = 0.0f;
                _19454.w = 0.0f;
                _20641 = _19454;
            }
            else
            {
                _20641 = _20538;
            }
            bool _6535 = _6501 && _6447;
            bool _6538 = _6507 && _6450;
            float4 _20746;
            float3 _21972;
            if (_6535 || _6538)
            {
                float _20636;
                do
                {
                    uint4 _12882 = r_warped_motion_qdata_tp1.Load(int3(_19971, 0));
                    uint _12883 = _12882.x;
                    if (_12883 != 0u)
                    {
                        float _20635;
                        if (_12883 == 0u)
                        {
                            _20635 = -1.0f;
                        }
                        else
                        {
                            _20635 = float((_12883 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20636 = _20635;
                        break;
                    }
                    int _20618;
                    uint _20619;
                    _20619 = _12883;
                    _20618 = -1;
                    uint _20634;
                    for (; _20618 <= 1; _20619 = _20634, _20618++)
                    {
                        _20634 = _20619;
                        for (int _20632 = -1; _20632 <= 1; )
                        {
                            _20634 = max(_20634, r_warped_motion_qdata_tp1.Load(int3(clamp(_19971 + int2(_20632, _20618), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20632++;
                            continue;
                        }
                    }
                    if (_20619 != 0u)
                    {
                        float _20631;
                        if (_20619 == 0u)
                        {
                            _20631 = -1.0f;
                        }
                        else
                        {
                            _20631 = float((_20619 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20636 = _20631;
                        break;
                    }
                    uint _20621;
                    _20621 = 4294967295u;
                    uint _23461;
                    for (int _20620 = 0; _20620 < 8; _20621 = _23461, _20620++)
                    {
                        int _20624 = 0;
                        for (;;)
                        {
                            if (_20624 < 5)
                            {
                                int2 _12833 = _19971 + (_1251[_20620] * _1260[_20624].xx);
                                bool _12836 = any(bool2(_12833.x < int2(0, 0).x, _12833.y < int2(0, 0).y));
                                bool _12844;
                                if (!_12836)
                                {
                                    _12844 = any(bool2(_12833.x >= cbFI_MvDepthLaneSize.x, _12833.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12844 = _12836;
                                }
                                if (_12844)
                                {
                                    _23461 = _20621;
                                    break;
                                }
                                uint4 _12922 = r_warped_motion_qdata_tp1.Load(int3(_12833, 0));
                                uint _12923 = _12922.x;
                                if (_12923 != 0u)
                                {
                                    _23461 = min(_20621, _12923);
                                    break;
                                }
                                _20624++;
                                continue;
                            }
                            else
                            {
                                _23461 = _20621;
                                break;
                            }
                        }
                    }
                    float _20623;
                    if (_20621 == 4294967295u)
                    {
                        _20623 = -1.0f;
                    }
                    else
                    {
                        float _20622;
                        if (_20621 == 0u)
                        {
                            _20622 = -1.0f;
                        }
                        else
                        {
                            _20622 = float((_20621 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20623 = _20622;
                    }
                    _20636 = _20623;
                    break;
                } while(false);
                bool _6546 = _20636 < 0.0f;
                float _20637;
                if (_6546)
                {
                    _20637 = 0.0f;
                }
                else
                {
                    _20637 = _20636 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12944_dummy_parameter;
                uint _12976_dummy_parameter;
                float4 _20674;
                if ((_6546 && _6535) && _6538)
                {
                    uint _13008_dummy_parameter;
                    float _13032 = log(((r_depth_tm1.Load(int3(int2(floor(_19750 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13008_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _13040_dummy_parameter;
                    float _13064 = log(((r_depth_tp1.Load(int3(int2(floor(_19752 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13040_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20675;
                    if (_13032 > (_13064 + 0.07999999821186065673828125f))
                    {
                        float4 _19458 = _20641;
                        _19458.x = 0.0f;
                        _20675 = _19458;
                    }
                    else
                    {
                        float4 _20676;
                        if (_13064 > (_13032 + 0.07999999821186065673828125f))
                        {
                            float4 _19460 = _20641;
                            _19460.y = 0.0f;
                            _20676 = _19460;
                        }
                        else
                        {
                            _20676 = _20641;
                        }
                        _20675 = _20676;
                    }
                    _20674 = _20675;
                }
                else
                {
                    _20674 = _20641;
                }
                float _6598 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6600 = _20636 >= 0.0f;
                float _20657;
                if (_6600)
                {
                    _20657 = _20636 - _6598;
                }
                else
                {
                    float _20653;
                    if (_6535)
                    {
                        float _20652;
                        _20652 = 2.0f;
                        float _13122;
                        for (int _20651 = 0; _20651 < 24; _20652 = _13122, _20651++)
                        {
                            float _13086 = float(_20651 & 7) * 0.785398185253143310546875f;
                            int _13088 = _20651 >> 3;
                            int _20654;
                            if (_13088 == 0)
                            {
                                _20654 = 16;
                            }
                            else
                            {
                                _20654 = (_13088 == 1) ? 48 : 96;
                            }
                            uint _13138_dummy_parameter;
                            _13122 = min(_20652, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19750 + ((cbFI_MvDepthLaneSizeRcp * float(_20654)) * float2(cos(_13086), sin(_13086))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13138_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20653 = _20652;
                    }
                    else
                    {
                        _20653 = 0.0f;
                    }
                    _20657 = _20653;
                }
                float _20664;
                if (_6600)
                {
                    _20664 = _20636 - _6598;
                }
                else
                {
                    float _20660;
                    if (_6538)
                    {
                        float _20659;
                        _20659 = 2.0f;
                        float _13236;
                        for (int _20658 = 0; _20658 < 24; _20659 = _13236, _20658++)
                        {
                            float _13200 = float(_20658 & 7) * 0.785398185253143310546875f;
                            int _13202 = _20658 >> 3;
                            int _20661;
                            if (_13202 == 0)
                            {
                                _20661 = 16;
                            }
                            else
                            {
                                _20661 = (_13202 == 1) ? 48 : 96;
                            }
                            uint _13268_dummy_parameter;
                            _13236 = min(_20659, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19752 + ((cbFI_MvDepthLaneSizeRcp * float(_20661)) * float2(cos(_13200), sin(_13200))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13268_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20660 = _20659;
                    }
                    else
                    {
                        _20660 = 0.0f;
                    }
                    _20664 = _20660;
                }
                float _20665;
                if (_6535)
                {
                    uint _13300_dummy_parameter;
                    _20665 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_19750 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13300_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20665 = 0.0f;
                }
                float _20666;
                if (_6538)
                {
                    uint _13320_dummy_parameter;
                    _20666 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_19752 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13320_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20666 = 0.0f;
                }
                bool _6655;
                if (_6535)
                {
                    _6655 = _20665 > ((exp((_20657 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6655 = _6535;
                }
                float4 _20682;
                if (_6655)
                {
                    float4 _19462 = _20674;
                    _19462.x = 0.0f;
                    _20682 = _19462;
                }
                else
                {
                    _20682 = _20674;
                }
                bool _6667;
                if (_6538)
                {
                    _6667 = _20666 > ((exp((_20664 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6667 = _6538;
                }
                float4 _20684;
                if (_6667)
                {
                    float4 _19464 = _20682;
                    _19464.y = 0.0f;
                    _20684 = _19464;
                }
                else
                {
                    _20684 = _20682;
                }
                float4 _20747;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6600)
                {
                    bool _6687;
                    if (_6535)
                    {
                        _6687 = _20665 < ((exp((_20657 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6687 = _6535;
                    }
                    float4 _20686;
                    if (_6687)
                    {
                        float4 _19466 = _20684;
                        _19466.x = 0.0f;
                        _20686 = _19466;
                    }
                    else
                    {
                        _20686 = _20684;
                    }
                    bool _6699;
                    if (_6538)
                    {
                        _6699 = _20666 < ((exp((_20664 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6699 = _6538;
                    }
                    float4 _20748;
                    if (_6699)
                    {
                        float4 _19468 = _20686;
                        _19468.y = 0.0f;
                        _20748 = _19468;
                    }
                    else
                    {
                        _20748 = _20686;
                    }
                    _20747 = _20748;
                }
                else
                {
                    _20747 = _20684;
                }
                _21972 = float3(_20637, log(((r_depth_tm1.Load(int3(int2(floor(_19750 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12944_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_19752 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12976_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _20746 = _20747;
            }
            else
            {
                _21972 = float3(0.0f, 0.0f, 0.5f);
                _20746 = _20641;
            }
            bool _6710 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6459;
            bool _6716;
            if (_6710)
            {
                _6716 = _6513 || _6519;
            }
            else
            {
                _6716 = _6710;
            }
            float4 _20789;
            if (_6716)
            {
                float _20741;
                do
                {
                    uint4 _13500 = r_warped_motion_qdata_tp1.Load(int3(_19971, 0));
                    uint _13501 = _13500.x;
                    if (_13501 != 0u)
                    {
                        float _20740;
                        if (_13501 == 0u)
                        {
                            _20740 = -1.0f;
                        }
                        else
                        {
                            _20740 = float((_13501 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20741 = _20740;
                        break;
                    }
                    int _20723;
                    uint _20724;
                    _20724 = _13501;
                    _20723 = -1;
                    uint _20739;
                    for (; _20723 <= 1; _20724 = _20739, _20723++)
                    {
                        _20739 = _20724;
                        for (int _20737 = -1; _20737 <= 1; )
                        {
                            _20739 = max(_20739, r_warped_motion_qdata_tp1.Load(int3(clamp(_19971 + int2(_20737, _20723), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20737++;
                            continue;
                        }
                    }
                    if (_20724 != 0u)
                    {
                        float _20736;
                        if (_20724 == 0u)
                        {
                            _20736 = -1.0f;
                        }
                        else
                        {
                            _20736 = float((_20724 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20741 = _20736;
                        break;
                    }
                    uint _20726;
                    _20726 = 4294967295u;
                    uint _23462;
                    for (int _20725 = 0; _20725 < 8; _20726 = _23462, _20725++)
                    {
                        int _20729 = 0;
                        for (;;)
                        {
                            if (_20729 < 5)
                            {
                                int2 _13451 = _19971 + (_1251[_20725] * _1260[_20729].xx);
                                bool _13454 = any(bool2(_13451.x < int2(0, 0).x, _13451.y < int2(0, 0).y));
                                bool _13462;
                                if (!_13454)
                                {
                                    _13462 = any(bool2(_13451.x >= cbFI_MvDepthLaneSize.x, _13451.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13462 = _13454;
                                }
                                if (_13462)
                                {
                                    _23462 = _20726;
                                    break;
                                }
                                uint4 _13540 = r_warped_motion_qdata_tp1.Load(int3(_13451, 0));
                                uint _13541 = _13540.x;
                                if (_13541 != 0u)
                                {
                                    _23462 = min(_20726, _13541);
                                    break;
                                }
                                _20729++;
                                continue;
                            }
                            else
                            {
                                _23462 = _20726;
                                break;
                            }
                        }
                    }
                    float _20728;
                    if (_20726 == 4294967295u)
                    {
                        _20728 = -1.0f;
                    }
                    else
                    {
                        float _20727;
                        if (_20726 == 0u)
                        {
                            _20727 = -1.0f;
                        }
                        else
                        {
                            _20727 = float((_20726 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20728 = _20727;
                    }
                    _20741 = _20728;
                    break;
                } while(false);
                float4 _20790;
                if (_20741 >= 0.0f)
                {
                    float _13562 = (exp((_20741 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6735;
                    if (_6513)
                    {
                        uint _13569_dummy_parameter;
                        _6735 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13569_dummy_parameter))))), 0)).x) > _13562;
                    }
                    else
                    {
                        _6735 = _6513;
                    }
                    float4 _20759;
                    if (_6735)
                    {
                        float4 _19470 = _20746;
                        _19470.z = 0.0f;
                        _20759 = _19470;
                    }
                    else
                    {
                        _20759 = _20746;
                    }
                    bool _6747;
                    if (_6519)
                    {
                        uint _13589_dummy_parameter;
                        _6747 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13589_dummy_parameter))))), 0)).x) > _13562;
                    }
                    else
                    {
                        _6747 = _6519;
                    }
                    float4 _20791;
                    if (_6747)
                    {
                        float4 _19472 = _20759;
                        _19472.w = 0.0f;
                        _20791 = _19472;
                    }
                    else
                    {
                        _20791 = _20759;
                    }
                    _20790 = _20791;
                }
                else
                {
                    _20790 = _20746;
                }
                _20789 = _20790;
            }
            else
            {
                _20789 = _20746;
            }
            bool _6755 = _6501 != _6507;
            bool _6762;
            if (_6755)
            {
                _6762 = _6501 ? _6447 : _6450;
            }
            else
            {
                _6762 = _6755;
            }
            bool _6769;
            if (_6762)
            {
                _6769 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6769 = _6762;
            }
            float4 _20892;
            if (_6769)
            {
                bool2 _6774 = _6501.xx;
                float2 _6775 = float2(_6774.x ? _19750.x : _19752.x, _6774.y ? _19750.y : _19752.y);
                float _20773;
                if (_6501)
                {
                    uint _13609_dummy_parameter;
                    _20773 = r_depth_tm1.Load(int3(int2(floor(_6775 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13609_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13625_dummy_parameter;
                    _20773 = r_depth_tp1.Load(int3(int2(floor(_6775 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13625_dummy_parameter))))), 0)).x;
                }
                float4x4 _20780;
                if (_6501)
                {
                    float4x4 _20769;
                    do
                    {
                        float4x4 _13639;
                        bool _20768;
                        do
                        {
                            _13639 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20768 = false;
                                break;
                            }
                            uint _13673 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13673 + 32u) * 4 + 0) != 1u)
                            {
                                _20768 = false;
                                break;
                            }
                            uint _20765;
                            _20765 = 0u;
                            for (; _20765 < 4u; _20765++)
                            {
                                for (uint _20766 = 0u; _20766 < 4u; )
                                {
                                    _13639[_20765][_20766] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13673 + 16u) + (_20765 * 4u)) + _20766) * 4 + 0));
                                    _20766++;
                                    continue;
                                }
                            }
                            _20768 = true;
                            break;
                        } while(false);
                        if (_20768)
                        {
                            _20769 = _13639;
                            break;
                        }
                        _20769 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20780 = _20769;
                }
                else
                {
                    float4x4 _20764;
                    do
                    {
                        float4x4 _13745;
                        bool _20763;
                        do
                        {
                            _13745 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20763 = false;
                                break;
                            }
                            uint _13779 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13779 + 32u) * 4 + 0) != 1u)
                            {
                                _20763 = false;
                                break;
                            }
                            uint _20760;
                            _20760 = 0u;
                            for (; _20760 < 4u; _20760++)
                            {
                                for (uint _20761 = 0u; _20761 < 4u; )
                                {
                                    _13745[_20760][_20761] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13779 + (_20760 * 4u)) + _20761) * 4 + 0));
                                    _20761++;
                                    continue;
                                }
                            }
                            _20763 = true;
                            break;
                        } while(false);
                        if (_20763)
                        {
                            _20764 = _13745;
                            break;
                        }
                        _20764 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20780 = _20764;
                }
                float2 _20781;
                do
                {
                    float _13856 = _6775.x;
                    float _13859 = 1.0f - _6775.y;
                    float4 _13870 = mul(float4((float2(_13856, _13859) * 2.0f) - 1.0f.xx, _20773, 1.0f), _20780);
                    float _13872 = _13870.w;
                    if (!(_13872 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20781 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13885 = ((_13870.xy / _13872.xx) + 1.0f.xx) * 0.5f;
                    _20781 = float2(_13885.x - _13856, _13859 - _13885.y);
                    break;
                } while(false);
                float2 _6805 = float2(cbFI_DisplaySize);
                float4 _20893;
                if (!(length(((_6775 + _20781) - float2(_6774.x ? _19752.x : _19750.x, _6774.y ? _19752.y : _19750.y)) * _6805) <= ((0.100000001490116119384765625f * length(_20781 * _6805)) + 8.0f)))
                {
                    float4 _20894;
                    if (_6501)
                    {
                        float4 _19482 = _20789;
                        _19482.x = 0.0f;
                        _20894 = _19482;
                    }
                    else
                    {
                        float4 _19484 = _20789;
                        _19484.y = 0.0f;
                        _20894 = _19484;
                    }
                    _20893 = _20894;
                }
                else
                {
                    _20893 = _20789;
                }
                _20892 = _20893;
            }
            else
            {
                _20892 = _20789;
            }
            float4 _6830 = _20503 * _20892;
            float _6832 = dot(_6830, 1.0f.xxxx);
            float4 _21234;
            bool _21540;
            if (_6832 > 0.0f)
            {
                _21540 = _20194;
                _21234 = _6830 / _6832.xxxx;
            }
            else
            {
                bool _6843 = any(bool4(_20892.x < 1.0f.xxxx.x, _20892.y < 1.0f.xxxx.y, _20892.z < 1.0f.xxxx.z, _20892.w < 1.0f.xxxx.w));
                if (_6843)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13907;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13907);
                    }
                }
                bool4 _23575 = _6843.xxxx;
                _21540 = _6843 ? true : _20194;
                _21234 = float4(_23575.x ? 0.0f.xxxx.x : _20503.x, _23575.y ? 0.0f.xxxx.y : _20503.y, _23575.z ? 0.0f.xxxx.z : _20503.z, _23575.w ? 0.0f.xxxx.w : _20503.w);
            }
            _21863 = _21972;
            _21539 = _21540;
            _21233 = _21234;
        }
        else
        {
            _21863 = float3(0.0f, 0.0f, 0.5f);
            _21539 = _20194;
            _21233 = _20503;
        }
        uint _6852 = (cbFI_pad0 >> 24u) & 31u;
        uint _6856 = (cbFI_pad0 >> 16u) & 255u;
        bool _6858 = _6852 != 0u;
        bool _6860 = _6856 == 12u;
        bool _6863 = _6856 == 13u;
        float4 _21254;
        if ((_6858 || _6860) || _6863)
        {
            float _20900;
            do
            {
                bool _13991 = all(bool2(_19753.x > 0.0f.xx.x, _19753.y > 0.0f.xx.y));
                bool _13997;
                if (_13991)
                {
                    _13997 = all(bool2(_19753.x < 1.0f.xx.x, _19753.y < 1.0f.xx.y));
                }
                else
                {
                    _13997 = _13991;
                }
                bool _13928 = !_13997;
                bool _13935;
                if (!_13928)
                {
                    bool _14002 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
                    bool _14008;
                    if (_14002)
                    {
                        _14008 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _14008 = _14002;
                    }
                    _13935 = !_14008;
                }
                else
                {
                    _13935 = _13928;
                }
                if (_13935)
                {
                    _20900 = 0.0f;
                    break;
                }
                uint _14015_dummy_parameter;
                uint _14031_dummy_parameter;
                float4x4 _20899;
                do
                {
                    float4x4 _14045;
                    bool _20898;
                    do
                    {
                        _14045 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20898 = false;
                            break;
                        }
                        uint _14079 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14079 + 32u) * 4 + 0) != 1u)
                        {
                            _20898 = false;
                            break;
                        }
                        uint _20895;
                        _20895 = 0u;
                        for (; _20895 < 4u; _20895++)
                        {
                            for (uint _20896 = 0u; _20896 < 4u; )
                            {
                                _14045[_20895][_20896] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14079 + 16u) + (_20895 * 4u)) + _20896) * 4 + 0));
                                _20896++;
                                continue;
                            }
                        }
                        _20898 = true;
                        break;
                    } while(false);
                    if (_20898)
                    {
                        _20899 = _14045;
                        break;
                    }
                    _20899 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13956 = mul(float4((float2(_19753.x, 1.0f - _19753.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19753 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14015_dummy_parameter))))), 0)).x, 1.0f), _20899);
                float _13958 = _13956.w;
                if (abs(_13958) < 9.9999999747524270787835121154785e-07f)
                {
                    _20900 = 0.0f;
                    break;
                }
                float _13969 = abs(cbFI_DeviceToViewDepth.y / ((_13956.z / _13958) - cbFI_DeviceToViewDepth.x));
                float _13972 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _14031_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20900 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13969 - _13972) / max(max(_13969, _13972), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14181 = all(bool2(_19754.x > 0.0f.xx.x, _19754.y > 0.0f.xx.y));
            bool _14187;
            if (_14181)
            {
                _14187 = all(bool2(_19754.x < 1.0f.xx.x, _19754.y < 1.0f.xx.y));
            }
            else
            {
                _14187 = _14181;
            }
            float _20901;
            if (_14187)
            {
                uint _14194_dummy_parameter;
                _20901 = length((_8007 + (r_motion_tp1.Load(int3(int2(floor(_19754 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14194_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20901 = 1000000.0f;
            }
            float _20916;
            if ((_6852 & 1u) != 0u)
            {
                _20916 = _20900;
            }
            else
            {
                _20916 = 1.0f;
            }
            float _20917;
            if ((_6852 & 2u) != 0u)
            {
                _20917 = _20916 * (1.0f - smoothstep(2.0f, 8.0f, _20901));
            }
            else
            {
                _20917 = _20916;
            }
            float _20918;
            if ((_6852 & 4u) != 0u)
            {
                _20918 = _20917 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8728 - _8736) - length(_8712 - _8720))));
            }
            else
            {
                _20918 = _20917;
            }
            float _21248;
            if ((_6852 & 8u) != 0u)
            {
                _21248 = lerp(1.0f, _20918, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8712 - _8720)));
            }
            else
            {
                _21248 = _20918;
            }
            bool _6938 = (_6852 & 16u) != 0u;
            bool _6947;
            if (_6938)
            {
                _6947 = length(_19748 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6947 = _6938;
            }
            float _23577 = _6947 ? 1.0f : _21248;
            bool _6953 = _6858 && _11109;
            bool _6958;
            if (_6953)
            {
                bool _14219 = all(bool2(_19750.x > 0.0f.xx.x, _19750.y > 0.0f.xx.y));
                bool _14225;
                if (_14219)
                {
                    _14225 = all(bool2(_19750.x < 1.0f.xx.x, _19750.y < 1.0f.xx.y));
                }
                else
                {
                    _14225 = _14219;
                }
                _6958 = _14225;
            }
            else
            {
                _6958 = _6953;
            }
            bool _6963;
            if (_6958)
            {
                bool _14230 = all(bool2(_19752.x > 0.0f.xx.x, _19752.y > 0.0f.xx.y));
                bool _14236;
                if (_14230)
                {
                    _14236 = all(bool2(_19752.x < 1.0f.xx.x, _19752.y < 1.0f.xx.y));
                }
                else
                {
                    _14236 = _14230;
                }
                _6963 = _14236;
            }
            else
            {
                _6963 = _6958;
            }
            float4 _21255;
            if (_6963)
            {
                float _6969 = _21233.x + _21233.y;
                float _6978 = (_21233.z + _21233.w) * (1.0f - _23577);
                float _21251;
                if (_6969 > 9.9999997473787516355514526367188e-06f)
                {
                    _21251 = _21233.x / _6969;
                }
                else
                {
                    _21251 = _5708;
                }
                _21255 = float4(_21233.x + (_6978 * _21251), _21233.y + (_6978 * (1.0f - _21251)), _21233.zw * _23577);
            }
            else
            {
                _21255 = _21233;
            }
            _21254 = _21255;
        }
        else
        {
            _21254 = _21233;
        }
        float3 _7039 = (((_8712 * _21254.x) + (_8720 * _21254.y)) + (_8728 * _21254.z)) + (_8736 * _21254.w);
        float3 _23210;
        if (_5724 && (_21269 > 0.0f))
        {
            uint _14243_dummy_parameter;
            float2 _14258 = r_motion_tp1.Load(int3(int2(floor(_5483 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14243_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21531;
            if (_8035)
            {
                float2 _14303 = clamp((((_19727 + (_14258 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14306 = tan(_14303.x);
                _21531 = (float2(_14306 / cbFI_DeviceToViewDepth.z, (tan(_14303.y) * sqrt(1.0f + (_14306 * _14306))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21531 = _19727 + (_14258 * cbFI_Timestep);
            }
            float2 _21532;
            if (_8035)
            {
                float2 _14382 = clamp((((_19727 + (_14258 * _5698)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14385 = tan(_14382.x);
                _21532 = (float2(_14385 / cbFI_DeviceToViewDepth.z, (tan(_14382.y) * sqrt(1.0f + (_14385 * _14385))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21532 = _19727 + (_14258 * _5698);
            }
            _23210 = lerp(_7039, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21531, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21532, 0.0f).xyz, cbFI_Timestep.xxx), _21269.xxx);
        }
        else
        {
            _23210 = _7039;
        }
        float3 _23209;
        if (_21539)
        {
            float3 _14427 = r_current_interpolation_source.Load(int3(_4971, 0)).xyz;
            float3 _23211;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11109)
            {
                uint _14434_dummy_parameter;
                float _21662;
                _21662 = r_depth_tm1.Load(int3(int2(floor(_19750 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14434_dummy_parameter))))), 0)).x;
                float _7120;
                for (int _21661 = 0; _21661 < 24; _21662 = _7120, _21661++)
                {
                    float _7092 = float(_21661 & 7) * 0.785398185253143310546875f;
                    int _7094 = _21661 >> 3;
                    int _23304;
                    if (_7094 == 0)
                    {
                        _23304 = 16;
                    }
                    else
                    {
                        _23304 = (_7094 == 1) ? 48 : 96;
                    }
                    uint _14454_dummy_parameter;
                    _7120 = max(_21662, r_depth_tm1.Load(int3(int2(floor(clamp(_19750 + ((cbFI_MvDepthLaneSizeRcp * float(_23304)) * float2(cos(_7092), sin(_7092))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14454_dummy_parameter))))), 0)).x);
                }
                float2 _21663;
                do
                {
                    float _14476 = 1.0f - _19750.y;
                    float4 _14487 = mul(float4((float2(_19750.x, _14476) * 2.0f) - 1.0f.xx, _21662, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14489 = _14487.w;
                    if (!(_14489 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21663 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14502 = ((_14487.xy / _14489.xx) + 1.0f.xx) * 0.5f;
                    _21663 = float2(_14502.x - _19750.x, _14476 - _14502.y);
                    break;
                } while(false);
                float2 _7131 = _19750 + _21663;
                bool _14520 = all(bool2(_7131.x > 0.0f.xx.x, _7131.y > 0.0f.xx.y));
                bool _14526;
                if (_14520)
                {
                    _14526 = all(bool2(_7131.x < 1.0f.xx.x, _7131.y < 1.0f.xx.y));
                }
                else
                {
                    _14526 = _14520;
                }
                float3 _23212;
                if (_14526)
                {
                    float _7137 = abs(cbFI_DeviceToViewDepth.y / (_21662 - cbFI_DeviceToViewDepth.x));
                    uint _14546_dummy_parameter;
                    int2 _14546 = int2(spvTextureSize(r_depth_m2, uint(0), _14546_dummy_parameter));
                    float _7141 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7131 * float2(_14546))), int2(0, 0), _14546 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _23217;
                    if (abs(_7141 - _7137) <= (0.20000000298023223876953125f * max(_7141, _7137)))
                    {
                        uint _14580_dummy_parameter;
                        int2 _14580 = int2(spvTextureSize(r_colour_m2, uint(0), _14580_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14603;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14603);
                        }
                        _23217 = r_colour_m2.Load(int3(clamp(int2(floor(_7131 * float2(_14580))), int2(0, 0), _14580 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14613;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14613);
                        }
                        _23217 = _14427;
                    }
                    _23212 = _23217;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14623;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14623);
                    }
                    _23212 = _14427;
                }
                _23211 = _23212;
            }
            else
            {
                _23211 = _14427;
            }
            _23209 = _23211;
        }
        else
        {
            _23209 = _23210;
        }
        bool _7166 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _23208;
        float _23284;
        if (_7166)
        {
            float2 _7170 = float2(cbFI_DisplaySize);
            float3 _21845;
            float _21846;
            do
            {
                bool _14935;
                float4x4 _21670;
                do
                {
                    float4x4 _14911;
                    bool _21669;
                    do
                    {
                        _14911 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14935 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14935)
                        {
                            _21669 = false;
                            break;
                        }
                        uint _14945 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14945 + 32u) * 4 + 0) != 1u)
                        {
                            _21669 = false;
                            break;
                        }
                        uint _21666;
                        _21666 = 0u;
                        for (; _21666 < 4u; _21666++)
                        {
                            for (uint _21667 = 0u; _21667 < 4u; )
                            {
                                _14911[_21666][_21667] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14945 + (_21666 * 4u)) + _21667) * 4 + 0));
                                _21667++;
                                continue;
                            }
                        }
                        _21669 = true;
                        break;
                    } while(false);
                    if (_21669)
                    {
                        _21670 = _14911;
                        break;
                    }
                    _21670 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float4x4 _14693 = spvInverse(_21670);
                bool _14695 = _6856 == 33u;
                if (_14695 || (_6856 == 34u))
                {
                    uint _15025_dummy_parameter;
                    float2 _15040 = r_motion_tp1.Load(int3(int2(floor(clamp(_5483, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15025_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
                    float2 _21837;
                    if (_14695)
                    {
                        uint _15052_dummy_parameter;
                        float2 _21836;
                        do
                        {
                            float _15071 = _5483.x;
                            float _15074 = 1.0f - _5483.y;
                            float4 _15085 = mul(float4((float2(_15071, _15074) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5483 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15052_dummy_parameter))))), 0)).x, 1.0f), _21670);
                            float _15087 = _15085.w;
                            if (!(_15087 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21836 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15100 = ((_15085.xy / _15087.xx) + 1.0f.xx) * 0.5f;
                            _21836 = float2(_15100.x - _15071, _15074 - _15100.y);
                            break;
                        } while(false);
                        _21837 = _21836 - _15040;
                    }
                    else
                    {
                        float2 _14715 = _5483 + _15040;
                        bool _15118 = all(bool2(_14715.x > 0.0f.xx.x, _14715.y > 0.0f.xx.y));
                        bool _15124;
                        if (_15118)
                        {
                            _15124 = all(bool2(_14715.x < 1.0f.xx.x, _14715.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15124 = _15118;
                        }
                        float2 _21835;
                        if (_15124)
                        {
                            uint _15131_dummy_parameter;
                            float2 _21834;
                            do
                            {
                                float _15150 = _14715.x;
                                float _15153 = 1.0f - _14715.y;
                                float4 _15164 = mul(float4((float2(_15150, _15153) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14715 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _15131_dummy_parameter))))), 0)).x, 1.0f), _14693);
                                float _15166 = _15164.w;
                                if (!(_15166 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21834 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _15179 = ((_15164.xy / _15166.xx) + 1.0f.xx) * 0.5f;
                                _21834 = float2(_15179.x - _15150, _15153 - _15179.y);
                                break;
                            } while(false);
                            _21835 = _21834 + _15040;
                        }
                        else
                        {
                            _21835 = 0.0f.xx;
                        }
                        _21837 = _21835;
                    }
                    bool _21844;
                    do
                    {
                        bool _15258 = all(bool2(_5483.x > 0.0f.xx.x, _5483.y > 0.0f.xx.y));
                        bool _15264;
                        if (_15258)
                        {
                            _15264 = all(bool2(_5483.x < 1.0f.xx.x, _5483.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15264 = _15258;
                        }
                        if (!_15264)
                        {
                            _21844 = false;
                            break;
                        }
                        uint _15271_dummy_parameter;
                        float4x4 _21842;
                        do
                        {
                            float4x4 _15285;
                            bool _21841;
                            do
                            {
                                _15285 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14935)
                                {
                                    _21841 = false;
                                    break;
                                }
                                uint _15319 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_15319 + 32u) * 4 + 0) != 1u)
                                {
                                    _21841 = false;
                                    break;
                                }
                                uint _21838;
                                _21838 = 0u;
                                for (; _21838 < 4u; _21838++)
                                {
                                    for (uint _21839 = 0u; _21839 < 4u; )
                                    {
                                        _15285[_21838][_21839] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15319 + (_21838 * 4u)) + _21839) * 4 + 0));
                                        _21839++;
                                        continue;
                                    }
                                }
                                _21841 = true;
                                break;
                            } while(false);
                            if (_21841)
                            {
                                _21842 = _15285;
                                break;
                            }
                            _21842 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21843;
                        do
                        {
                            float _15396 = _5483.x;
                            float _15399 = 1.0f - _5483.y;
                            float4 _15410 = mul(float4((float2(_15396, _15399) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5483 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15271_dummy_parameter))))), 0)).x, 1.0f), _21842);
                            float _15412 = _15410.w;
                            if (!(_15412 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21843 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15425 = ((_15410.xy / _15412.xx) + 1.0f.xx) * 0.5f;
                            _21843 = float2(_15425.x - _15396, _15399 - _15425.y);
                            break;
                        } while(false);
                        float2 _15222 = abs(_21843);
                        if (any(bool2(_15222.x > 100000.0f.xx.x, _15222.y > 100000.0f.xx.y)))
                        {
                            _21844 = false;
                            break;
                        }
                        float _15230 = length(_21843 * _7170);
                        uint _15445_dummy_parameter;
                        bool _15244 = _15230 > ((8.0f * _7170.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _15251;
                        if (_15244)
                        {
                            _15251 = length((r_motion_tp1.Load(int3(int2(floor(_5483 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15445_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7170) < (0.20000000298023223876953125f * _15230);
                        }
                        else
                        {
                            _15251 = _15244;
                        }
                        _21844 = _15251;
                        break;
                    } while(false);
                    _21846 = 2.0f;
                    _21845 = float3(clamp(length(_21837 * float2(cbFI_RenderSize)) * 0.25f, 0.0f, 1.0f), float(_21844), 0.0f);
                    break;
                }
                float _15479;
                float _15482;
                float4 _15492;
                float2 _21671;
                do
                {
                    _15479 = _5483.x;
                    _15482 = 1.0f - _5483.y;
                    _15492 = float4((float2(_15479, _15482) * 2.0f) - 1.0f.xx, 0.99999988079071044921875f, 1.0f);
                    float4 _15493 = mul(_15492, _21670);
                    float _15495 = _15493.w;
                    if (!(_15495 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21671 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15508 = ((_15493.xy / _15495.xx) + 1.0f.xx) * 0.5f;
                    _21671 = float2(_15508.x - _15479, _15482 - _15508.y);
                    break;
                } while(false);
                float2 _21672;
                do
                {
                    float4 _15545 = mul(_15492, _14693);
                    float _15547 = _15545.w;
                    if (!(_15547 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21672 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15560 = ((_15545.xy / _15547.xx) + 1.0f.xx) * 0.5f;
                    _21672 = float2(_15560.x - _15479, _15482 - _15560.y);
                    break;
                } while(false);
                float2 _14750 = abs(_21671);
                bool2 _23578 = any(bool2(_14750.x > 4.0f.xx.x, _14750.y > 4.0f.xx.y)).xx;
                float2 _14756 = abs(_21672);
                bool2 _23580 = any(bool2(_14756.x > 4.0f.xx.x, _14756.y > 4.0f.xx.y)).xx;
                float2 _15574[3];
                _15574[0] = _5483;
                float2 _15694 = clamp(_5483, 0.0f.xx, 1.0f.xx);
                uint _15702_dummy_parameter;
                _15574[1] = _5483 - ((r_motion_tp1.Load(int3(int2(floor(_15694 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15702_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5708);
                _15574[2] = _5483 - (float2(_23578.x ? 0.0f.xx.x : _21671.x, _23578.y ? 0.0f.xx.y : _21671.y) * _5708);
                float _21678;
                float2 _21679;
                _21679 = _5483;
                _21678 = 1000000000.0f;
                float _23582;
                float2 _23584;
                float _23585;
                int _21677 = 0;
                float _21826 = -1.0f;
                for (; _21677 < 3; _21826 = _23582, _21679 = _23584, _21678 = _23585, _21677++)
                {
                    float2 _21816;
                    _21816 = _15574[_21677];
                    for (int _21815 = 0; _21815 < 30; )
                    {
                        uint _16216_dummy_parameter;
                        _21816 += (((_5483 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_21816, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16216_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5708)) - _21816) * 0.699999988079071044921875f);
                        _21815++;
                        continue;
                    }
                    float2 _16646 = clamp(_21816, 0.0f.xx, 1.0f.xx);
                    uint _16654_dummy_parameter;
                    bool _17084 = all(bool2(_21816.x > 0.0f.xx.x, _21816.y > 0.0f.xx.y));
                    bool _17090;
                    if (_17084)
                    {
                        _17090 = all(bool2(_21816.x < 1.0f.xx.x, _21816.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17090 = _17084;
                    }
                    float _21818;
                    if (_17090)
                    {
                        _21818 = length(((_21816 + ((r_motion_tp1.Load(int3(int2(floor(_16646 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16654_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5708)) - _5483) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21818 = 1000000000.0f;
                    }
                    uint _17101_dummy_parameter;
                    float _17141 = log(((r_depth_tp1.Load(int3(int2(floor(_16646 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17101_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15654 = _21818 < 0.3499999940395355224609375f;
                    bool _15656 = _21678 < 0.3499999940395355224609375f;
                    bool _15666;
                    if (_15654)
                    {
                        _15666 = (!_15656) || (_17141 > _21826);
                    }
                    else
                    {
                        _15666 = _15654;
                    }
                    bool _15679;
                    if (!_15666)
                    {
                        _15679 = ((!_15654) && (!_15656)) && (_21818 < _21678);
                    }
                    else
                    {
                        _15679 = _15666;
                    }
                    _23582 = _15679 ? _17141 : _21826;
                    bool2 _23583 = _15679.xx;
                    _23584 = float2(_23583.x ? _21816.x : _21679.x, _23583.y ? _21816.y : _21679.y);
                    _23585 = _15679 ? _21818 : _21678;
                }
                float2 _17143[3];
                _17143[0] = _5483;
                float2 _21698;
                do
                {
                    bool _21688;
                    do
                    {
                        bool _17390 = all(bool2(_15694.x > 0.0f.xx.x, _15694.y > 0.0f.xx.y));
                        bool _17396;
                        if (_17390)
                        {
                            _17396 = all(bool2(_15694.x < 1.0f.xx.x, _15694.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17396 = _17390;
                        }
                        if (!_17396)
                        {
                            _21688 = false;
                            break;
                        }
                        uint _17403_dummy_parameter;
                        float4x4 _21686;
                        do
                        {
                            float4x4 _17417;
                            bool _21685;
                            do
                            {
                                _17417 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14935)
                                {
                                    _21685 = false;
                                    break;
                                }
                                uint _17451 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17451 + 32u) * 4 + 0) != 1u)
                                {
                                    _21685 = false;
                                    break;
                                }
                                uint _21682;
                                _21682 = 0u;
                                for (; _21682 < 4u; _21682++)
                                {
                                    for (uint _21683 = 0u; _21683 < 4u; )
                                    {
                                        _17417[_21682][_21683] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17451 + (_21682 * 4u)) + _21683) * 4 + 0));
                                        _21683++;
                                        continue;
                                    }
                                }
                                _21685 = true;
                                break;
                            } while(false);
                            if (_21685)
                            {
                                _21686 = _17417;
                                break;
                            }
                            _21686 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21687;
                        do
                        {
                            float _17528 = _15694.x;
                            float _17531 = 1.0f - _15694.y;
                            float4 _17542 = mul(float4((float2(_17528, _17531) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15694 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17403_dummy_parameter))))), 0)).x, 1.0f), _21686);
                            float _17544 = _17542.w;
                            if (!(_17544 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21687 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17557 = ((_17542.xy / _17544.xx) + 1.0f.xx) * 0.5f;
                            _21687 = float2(_17557.x - _17528, _17531 - _17557.y);
                            break;
                        } while(false);
                        float2 _17354 = abs(_21687);
                        if (any(bool2(_17354.x > 100000.0f.xx.x, _17354.y > 100000.0f.xx.y)))
                        {
                            _21688 = false;
                            break;
                        }
                        float _17362 = length(_21687 * _7170);
                        uint _17577_dummy_parameter;
                        bool _17376 = _17362 > ((8.0f * _7170.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17383;
                        if (_17376)
                        {
                            _17383 = length((r_motion_tp1.Load(int3(int2(floor(_15694 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17577_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7170) < (0.20000000298023223876953125f * _17362);
                        }
                        else
                        {
                            _17383 = _17376;
                        }
                        _21688 = _17383;
                        break;
                    } while(false);
                    if (_21688)
                    {
                        uint _17608_dummy_parameter;
                        _21698 = -(r_motion_tp1.Load(int3(int2(floor(_15694 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17608_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17635_dummy_parameter;
                    float2 _21697;
                    do
                    {
                        float _17654 = _15694.x;
                        float _17657 = 1.0f - _15694.y;
                        float4 _17668 = mul(float4((float2(_17654, _17657) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15694 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17635_dummy_parameter))))), 0)).x, 1.0f), _14693);
                        float _17670 = _17668.w;
                        if (!(_17670 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21697 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17683 = ((_17668.xy / _17670.xx) + 1.0f.xx) * 0.5f;
                        _21697 = float2(_17683.x - _17654, _17657 - _17683.y);
                        break;
                    } while(false);
                    float2 _17321 = abs(_21697);
                    bool2 _17325 = any(bool2(_17321.x > 4.0f.xx.x, _17321.y > 4.0f.xx.y)).xx;
                    _21698 = float2(_17325.x ? 0.0f.xx.x : _21697.x, _17325.y ? 0.0f.xx.y : _21697.y);
                    break;
                } while(false);
                _17143[1] = _5483 - (_21698 * cbFI_Timestep);
                _17143[2] = _5483 - (float2(_23580.x ? 0.0f.xx.x : _21672.x, _23580.y ? 0.0f.xx.y : _21672.y) * cbFI_Timestep);
                float _21700;
                float2 _21701;
                _21701 = _5483;
                _21700 = 1000000000.0f;
                float _23586;
                float2 _23588;
                float _23589;
                float4x4 _17931;
                float4x4 _18369;
                int _21699 = 0;
                float _21753 = -1.0f;
                for (; _21699 < 3; _21753 = _23586, _21701 = _23588, _21700 = _23589, _21699++)
                {
                    float2 _21703;
                    _21703 = _17143[_21699];
                    float2 _17740;
                    for (int _21702 = 0; _21702 < 30; _21703 = _17740, _21702++)
                    {
                        float2 _21794;
                        do
                        {
                            float2 _17820 = clamp(_21703, 0.0f.xx, 1.0f.xx);
                            bool _21784;
                            do
                            {
                                bool _17904 = all(bool2(_17820.x > 0.0f.xx.x, _17820.y > 0.0f.xx.y));
                                bool _17910;
                                if (_17904)
                                {
                                    _17910 = all(bool2(_17820.x < 1.0f.xx.x, _17820.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17910 = _17904;
                                }
                                if (!_17910)
                                {
                                    _21784 = false;
                                    break;
                                }
                                uint _17917_dummy_parameter;
                                float4x4 _21782;
                                do
                                {
                                    bool _21781;
                                    do
                                    {
                                        _17931 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14935)
                                        {
                                            _21781 = false;
                                            break;
                                        }
                                        uint _17965 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17965 + 32u) * 4 + 0) != 1u)
                                        {
                                            _21781 = false;
                                            break;
                                        }
                                        uint _21778;
                                        _21778 = 0u;
                                        for (; _21778 < 4u; _21778++)
                                        {
                                            for (uint _21779 = 0u; _21779 < 4u; )
                                            {
                                                _17931[_21778][_21779] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17965 + (_21778 * 4u)) + _21779) * 4 + 0));
                                                _21779++;
                                                continue;
                                            }
                                        }
                                        _21781 = true;
                                        break;
                                    } while(false);
                                    if (_21781)
                                    {
                                        _21782 = _17931;
                                        break;
                                    }
                                    _21782 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _21783;
                                do
                                {
                                    float _18042 = _17820.x;
                                    float _18045 = 1.0f - _17820.y;
                                    float4 _18056 = mul(float4((float2(_18042, _18045) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17820 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17917_dummy_parameter))))), 0)).x, 1.0f), _21782);
                                    float _18058 = _18056.w;
                                    if (!(_18058 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _21783 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _18071 = ((_18056.xy / _18058.xx) + 1.0f.xx) * 0.5f;
                                    _21783 = float2(_18071.x - _18042, _18045 - _18071.y);
                                    break;
                                } while(false);
                                float2 _17868 = abs(_21783);
                                if (any(bool2(_17868.x > 100000.0f.xx.x, _17868.y > 100000.0f.xx.y)))
                                {
                                    _21784 = false;
                                    break;
                                }
                                float _17876 = length(_21783 * _7170);
                                uint _18091_dummy_parameter;
                                bool _17890 = _17876 > ((8.0f * _7170.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17897;
                                if (_17890)
                                {
                                    _17897 = length((r_motion_tp1.Load(int3(int2(floor(_17820 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18091_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7170) < (0.20000000298023223876953125f * _17876);
                                }
                                else
                                {
                                    _17897 = _17890;
                                }
                                _21784 = _17897;
                                break;
                            } while(false);
                            if (_21784)
                            {
                                uint _18122_dummy_parameter;
                                _21794 = -(r_motion_tp1.Load(int3(int2(floor(_17820 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18122_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _18149_dummy_parameter;
                            float2 _21793;
                            do
                            {
                                float _18168 = _17820.x;
                                float _18171 = 1.0f - _17820.y;
                                float4 _18182 = mul(float4((float2(_18168, _18171) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17820 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18149_dummy_parameter))))), 0)).x, 1.0f), _14693);
                                float _18184 = _18182.w;
                                if (!(_18184 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21793 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18197 = ((_18182.xy / _18184.xx) + 1.0f.xx) * 0.5f;
                                _21793 = float2(_18197.x - _18168, _18171 - _18197.y);
                                break;
                            } while(false);
                            float2 _17835 = abs(_21793);
                            bool2 _17839 = any(bool2(_17835.x > 4.0f.xx.x, _17835.y > 4.0f.xx.y)).xx;
                            _21794 = float2(_17839.x ? 0.0f.xx.x : _21793.x, _17839.y ? 0.0f.xx.y : _21793.y);
                            break;
                        } while(false);
                        _17740 = _21703 + (((_5483 - (_21794 * cbFI_Timestep)) - _21703) * 0.699999988079071044921875f);
                    }
                    float2 _18258;
                    float2 _21720;
                    do
                    {
                        _18258 = clamp(_21703, 0.0f.xx, 1.0f.xx);
                        bool _21710;
                        do
                        {
                            bool _18342 = all(bool2(_18258.x > 0.0f.xx.x, _18258.y > 0.0f.xx.y));
                            bool _18348;
                            if (_18342)
                            {
                                _18348 = all(bool2(_18258.x < 1.0f.xx.x, _18258.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18348 = _18342;
                            }
                            if (!_18348)
                            {
                                _21710 = false;
                                break;
                            }
                            uint _18355_dummy_parameter;
                            float4x4 _21708;
                            do
                            {
                                bool _21707;
                                do
                                {
                                    _18369 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14935)
                                    {
                                        _21707 = false;
                                        break;
                                    }
                                    uint _18403 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18403 + 32u) * 4 + 0) != 1u)
                                    {
                                        _21707 = false;
                                        break;
                                    }
                                    uint _21704;
                                    _21704 = 0u;
                                    for (; _21704 < 4u; _21704++)
                                    {
                                        for (uint _21705 = 0u; _21705 < 4u; )
                                        {
                                            _18369[_21704][_21705] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18403 + (_21704 * 4u)) + _21705) * 4 + 0));
                                            _21705++;
                                            continue;
                                        }
                                    }
                                    _21707 = true;
                                    break;
                                } while(false);
                                if (_21707)
                                {
                                    _21708 = _18369;
                                    break;
                                }
                                _21708 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _21709;
                            do
                            {
                                float _18483 = 1.0f - _18258.y;
                                float4 _18494 = mul(float4((float2(_18258.x, _18483) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18258 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18355_dummy_parameter))))), 0)).x, 1.0f), _21708);
                                float _18496 = _18494.w;
                                if (!(_18496 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21709 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18509 = ((_18494.xy / _18496.xx) + 1.0f.xx) * 0.5f;
                                _21709 = float2(_18509.x - _18258.x, _18483 - _18509.y);
                                break;
                            } while(false);
                            float2 _18306 = abs(_21709);
                            if (any(bool2(_18306.x > 100000.0f.xx.x, _18306.y > 100000.0f.xx.y)))
                            {
                                _21710 = false;
                                break;
                            }
                            float _18314 = length(_21709 * _7170);
                            uint _18529_dummy_parameter;
                            bool _18328 = _18314 > ((8.0f * _7170.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18335;
                            if (_18328)
                            {
                                _18335 = length((r_motion_tp1.Load(int3(int2(floor(_18258 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18529_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7170) < (0.20000000298023223876953125f * _18314);
                            }
                            else
                            {
                                _18335 = _18328;
                            }
                            _21710 = _18335;
                            break;
                        } while(false);
                        if (_21710)
                        {
                            uint _18560_dummy_parameter;
                            _21720 = -(r_motion_tp1.Load(int3(int2(floor(_18258 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18560_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18587_dummy_parameter;
                        float2 _21719;
                        do
                        {
                            float _18609 = 1.0f - _18258.y;
                            float4 _18620 = mul(float4((float2(_18258.x, _18609) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18258 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18587_dummy_parameter))))), 0)).x, 1.0f), _14693);
                            float _18622 = _18620.w;
                            if (!(_18622 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21719 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18635 = ((_18620.xy / _18622.xx) + 1.0f.xx) * 0.5f;
                            _21719 = float2(_18635.x - _18258.x, _18609 - _18635.y);
                            break;
                        } while(false);
                        float2 _18273 = abs(_21719);
                        bool2 _18277 = any(bool2(_18273.x > 4.0f.xx.x, _18273.y > 4.0f.xx.y)).xx;
                        _21720 = float2(_18277.x ? 0.0f.xx.x : _21719.x, _18277.y ? 0.0f.xx.y : _21719.y);
                        break;
                    } while(false);
                    bool _18653 = all(bool2(_21703.x > 0.0f.xx.x, _21703.y > 0.0f.xx.y));
                    bool _18659;
                    if (_18653)
                    {
                        _18659 = all(bool2(_21703.x < 1.0f.xx.x, _21703.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18659 = _18653;
                    }
                    float _21732;
                    if (_18659)
                    {
                        _21732 = length(((_21703 + (_21720 * cbFI_Timestep)) - _5483) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21732 = 1000000000.0f;
                    }
                    uint _18686_dummy_parameter;
                    float _18710 = log(((r_depth_tm1.Load(int3(int2(floor(_18258 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18686_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _17223 = _21732 < 0.3499999940395355224609375f;
                    bool _17225 = _21700 < 0.3499999940395355224609375f;
                    bool _17235;
                    if (_17223)
                    {
                        _17235 = (!_17225) || (_18710 > _21753);
                    }
                    else
                    {
                        _17235 = _17223;
                    }
                    bool _17248;
                    if (!_17235)
                    {
                        _17248 = ((!_17223) && (!_17225)) && (_21732 < _21700);
                    }
                    else
                    {
                        _17248 = _17235;
                    }
                    _23586 = _17248 ? _18710 : _21753;
                    bool2 _23587 = _17248.xx;
                    _23588 = float2(_23587.x ? _21703.x : _21701.x, _23587.y ? _21703.y : _21701.y);
                    _23589 = _17248 ? _21732 : _21700;
                }
                float3 _18719 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21679, 0.0f).xyz;
                float3 _18727 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21701, 0.0f).xyz;
                uint _18734_dummy_parameter;
                uint _18765_dummy_parameter;
                float _14796 = exp((_21678 * (-2.0f)) * (_21678 * 2.0f));
                float _14803 = exp((_21700 * (-2.0f)) * (_21700 * 2.0f));
                float _14816 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21701, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18765_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21679, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18734_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14830 = ((_14796 * cbFI_Timestep) * ((1.0f - _14803) + ((_14803 * 2.0f) * _14816))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14840 = 1.0f - _14816;
                float _14847 = ((_14803 * _5708) * ((1.0f - _14796) + ((_14796 * 2.0f) * _14840))) + (9.9999997473787516355514526367188e-05f * _5708);
                float _14856 = (((_14796 * _14803) * 4.0f) * _14816) * _14840;
                float _14874 = (_14856 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18727 - _18719, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14856)) * max(_14796, _14803));
                if (_6856 == 30u)
                {
                    _21846 = _14874;
                    _21845 = _18719;
                    break;
                }
                if (_6856 == 31u)
                {
                    _21846 = _14874;
                    _21845 = _18727;
                    break;
                }
                if (_6856 == 32u)
                {
                    _21846 = _14874;
                    _21845 = float3(_14796, _14803, _14816);
                    break;
                }
                _21846 = _14874;
                _21845 = ((_18719 * _14830) + (_18727 * _14847)) / (_14830 + _14847).xxx;
                break;
            } while(false);
            _23284 = _21846;
            _23208 = _21845;
        }
        else
        {
            _23284 = 1.0f;
            _23208 = _23209;
        }
        uint _7186 = cbFI_pad0 & 255u;
        bool _23015;
        float3 _23207;
        if (_7186 != 0u)
        {
            float3 _7191 = r_present_backbuffer.Load(int3(_4971, 0)).xyz;
            float3 _7195 = r_current_interpolation_source.Load(int3(_4971, 0)).xyz;
            float3 _7199 = abs(_7191 - _7195);
            float3 _21855;
            if (_7186 == 2u)
            {
                _21855 = (abs(_7195) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21855 = 0.000244140625f.xxx;
            }
            bool _7215 = any(bool3(_7199.x > _21855.x, _7199.y > _21855.y, _7199.z > _21855.z));
            bool3 _23590 = _7215.xxx;
            _23207 = float3(_23590.x ? _7191.x : _23208.x, _23590.y ? _7191.y : _23208.y, _23590.z ? _7191.z : _23208.z);
            _23015 = _7215;
        }
        else
        {
            _23207 = _23208;
            _23015 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18803;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18803);
        }
        float3 _23189;
        if (_6856 == 1u)
        {
            _23189 = lerp(_8712, _8720, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _23190;
            if (_6856 == 2u)
            {
                _23190 = lerp(_8728, _8736, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _23191;
                if (_6856 == 3u)
                {
                    _23191 = float(_23015).xxx;
                }
                else
                {
                    float3 _23192;
                    if (_6856 == 4u)
                    {
                        _23192 = float3(((_19748 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _23193;
                        if (_6856 == 5u)
                        {
                            _23193 = float3(((_8007 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _23194;
                            if (_6856 == 6u)
                            {
                                _23194 = float3(_21254.xy, _21254.z + _21254.w);
                            }
                            else
                            {
                                float3 _23195;
                                if (_6856 == 7u)
                                {
                                    _23195 = r_current_interpolation_source.Load(int3(_4971, 0)).xyz;
                                }
                                else
                                {
                                    float3 _23196;
                                    if (_6856 == 8u)
                                    {
                                        _23196 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5483, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _23197;
                                        if (_6860)
                                        {
                                            uint _18825_dummy_parameter;
                                            uint _18857_dummy_parameter;
                                            _23197 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_5483 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18825_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_5483 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18857_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _23198;
                                            if (_6863)
                                            {
                                                _23198 = _8728;
                                            }
                                            else
                                            {
                                                float3 _23199;
                                                if (_6856 == 20u)
                                                {
                                                    _23199 = _8712;
                                                }
                                                else
                                                {
                                                    float3 _23200;
                                                    if (_6856 == 21u)
                                                    {
                                                        _23200 = _8720;
                                                    }
                                                    else
                                                    {
                                                        float3 _23201;
                                                        if (_6856 == 22u)
                                                        {
                                                            _23201 = _8736;
                                                        }
                                                        else
                                                        {
                                                            float3 _23202;
                                                            if (_6856 == 18u)
                                                            {
                                                                _23202 = _22463;
                                                            }
                                                            else
                                                            {
                                                                float3 _23203;
                                                                if (_6856 == 19u)
                                                                {
                                                                    _23203 = _22160;
                                                                }
                                                                else
                                                                {
                                                                    float3 _23204;
                                                                    if (_6856 == 23u)
                                                                    {
                                                                        _23204 = _21863;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _23205;
                                                                        if (_6856 == 24u)
                                                                        {
                                                                            uint _7359 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7364 = float(rw_nfru_diagnostics.Load<uint>((_7359 + 35u) * 4 + 0));
                                                                            float _21856;
                                                                            if (_7364 > 0.0f)
                                                                            {
                                                                                _21856 = float(rw_nfru_diagnostics.Load<uint>((_7359 + 34u) * 4 + 0)) / _7364;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21856 = 0.0f;
                                                                            }
                                                                            _23205 = float3(float(rw_nfru_diagnostics.Load<uint>((_7359 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7359 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21856);
                                                                        }
                                                                        else
                                                                        {
                                                                            _23205 = _23207;
                                                                        }
                                                                        _23204 = _23205;
                                                                    }
                                                                    _23203 = _23204;
                                                                }
                                                                _23202 = _23203;
                                                            }
                                                            _23201 = _23202;
                                                        }
                                                        _23200 = _23201;
                                                    }
                                                    _23199 = _23200;
                                                }
                                                _23198 = _23199;
                                            }
                                            _23197 = _23198;
                                        }
                                        _23196 = _23197;
                                    }
                                    _23195 = _23196;
                                }
                                _23194 = _23195;
                            }
                            _23193 = _23194;
                        }
                        _23192 = _23193;
                    }
                    _23191 = _23192;
                }
                _23190 = _23191;
            }
            _23189 = _23190;
        }
        float3 _23188;
        if ((_6856 >= 9u) && (_6856 <= 11u))
        {
            uint _7424 = 64u + uint((_19971.y * cbFI_MvDepthLaneSize.x) + _19971.x);
            uint _7428 = rw_nfru_diagnostics.Load<uint>(_7424 * 4 + 0) & 15u;
            float3 _23222;
            if (_6856 == 10u)
            {
                float3 _23187;
                if ((rw_nfru_diagnostics.Load<uint>(_7424 * 4 + 0) & 32u) != 0u)
                {
                    _23187 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _23186;
                    if ((rw_nfru_diagnostics.Load<uint>(_7424 * 4 + 0) & 16u) != 0u)
                    {
                        _23186 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7449 = ((rw_nfru_diagnostics.Load<uint>(_7424 * 4 + 0) & 64u) != 0u).xxx;
                        _23186 = float3(_7449.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7449.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7449.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _23187 = _23186;
                }
                _23222 = _23187;
            }
            else
            {
                float3 _23223;
                if (_6856 == 11u)
                {
                    uint _7462 = (rw_nfru_diagnostics.Load<uint>(_7424 * 4 + 0) >> 8u) & 15u;
                    uint _7465 = (rw_nfru_diagnostics.Load<uint>(_7424 * 4 + 0) >> 12u) & 15u;
                    float3 _23179;
                    if ((_7428 == 2u) || (_7428 == 3u))
                    {
                        _23179 = _4653[_7428];
                    }
                    else
                    {
                        bool _7477 = _7462 == 3u;
                        bool _7479 = _7465 == 3u;
                        float3 _23180;
                        if (_7477 && _7479)
                        {
                            _23180 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _23181;
                            if (_7477)
                            {
                                _23181 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _23182;
                                if (_7479)
                                {
                                    _23182 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _23183;
                                    if ((_7462 == 4u) || (_7465 == 4u))
                                    {
                                        _23183 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _23184;
                                        if ((_7462 == 1u) || (_7465 == 1u))
                                        {
                                            _23184 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23592 = (_7428 == 1u).xxx;
                                            _23184 = float3(_23592.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23592.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23592.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _23183 = _23184;
                                    }
                                    _23182 = _23183;
                                }
                                _23181 = _23182;
                            }
                            _23180 = _23181;
                        }
                        _23179 = _23180;
                    }
                    _23223 = _23179;
                }
                else
                {
                    _23223 = _4653[min(_7428, 7u)];
                }
                _23222 = _23223;
            }
            _23188 = _23222;
        }
        else
        {
            _23188 = _23189;
        }
        float4 _23226;
        if ((_6856 >= 14u) && (_6856 <= 16u))
        {
            float2 _23224;
            if (_6856 == 14u)
            {
                uint _7535_dummy_parameter;
                uint _7541_dummy_parameter;
                _23224 = r_flow_tm1.Load(int3(clamp(int2(floor(_5483 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7535_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7541_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _23225;
                if (_6856 == 16u)
                {
                    uint _18933 = r_warped_flow_qdata_tm1.Load(int3(_5499, 0)).x & 2147483647u;
                    uint _18965 = uint(max((int((_18933 >> 16u) & 15u) - 6), 0));
                    _23225 = ((float2(float((1 - (2 * int((_18933 >> 15u) & 1u))) * int(((_18933 >> uint(7)) & 127u) << _18965)), float((1 - (2 * int((_18933 >> 14u) & 1u))) * int((_18933 & 127u) << _18965))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _23225 = _8007 * float2(cbFI_DisplaySize);
                }
                _23224 = _23225;
            }
            uint2 _7574 = uint2(clamp(round(_23224 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7576 = _7574.x;
            uint _7583 = _7574.y;
            _23226 = float4(float(_7576 & 255u), float((_7576 >> 8u) | ((_7583 & 15u) << 4u)), float(_7583 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _23227;
            if (_6856 == 17u)
            {
                _23227 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5499, 0)).x != 0u), _5943, 0.0f, 1.0f);
            }
            else
            {
                _23227 = float4(_23188, 1.0f);
            }
            _23226 = _23227;
        }
        rw_output[_4971] = _23226.xyz;
        if (_7166)
        {
            uint _19010 = uint((_4971.y * cbFI_DisplaySize.x) + _4971.x) * 2u;
            rw_nfru_select.Store<uint>(_19010 * 4 + 0, spvPackHalf2x16(_23226.xy));
            rw_nfru_select.Store<uint>((_19010 + 1u) * 4 + 0, spvPackHalf2x16(float2(_23226.z, (_23015 || (_6856 != 0u)) ? 2.0f : _23284)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7641 = ((uint(_4971.y) * uint(cbFI_DisplaySize.x)) + uint(_4971.x)) * 6u;
            uint _19036 = spvPackHalf2x16(clamp(_8711.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7641 * 4 + 0, (((_19036 & 32767u) >> 4u) | ((((_19036 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8711.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19071 = spvPackHalf2x16(clamp(_8719.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7641 + 1u) * 4 + 0, (((_19071 & 32767u) >> 4u) | ((((_19071 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8719.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19106 = spvPackHalf2x16(clamp(_8727.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7641 + 2u) * 4 + 0, (((_19106 & 32767u) >> 4u) | ((((_19106 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8727.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19141 = spvPackHalf2x16(clamp(_8735.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7641 + 3u) * 4 + 0, (((_19141 & 32767u) >> 4u) | ((((_19141 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8735.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19168 = r_current_interpolation_source.Load(int3(_4971, 0));
            uint _19182 = spvPackHalf2x16(clamp(_19168.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7641 + 4u) * 4 + 0, (((_19182 & 32767u) >> 4u) | ((((_19182 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19168.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _23303;
            if (_23015 || (_6856 != 0u))
            {
                _23303 = 4294967295u;
            }
            else
            {
                uint _19217 = spvPackHalf2x16(clamp(_23226.xy, 0.0f.xx, 65000.0f.xx));
                _23303 = (((_19217 & 32767u) >> 4u) | ((((_19217 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_23226.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7641 + 5u) * 4 + 0, _23303);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4971] = float4(r_current_interpolation_source.Load(int3(_4971, 0)).xyz, 1.0f).xyz;
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
