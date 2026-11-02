static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19104;

static const int2 _1251[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1260[5] = { 2, 4, 7, 11, 16 };
static const float3 _4586[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4904 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4904.x >= cbFI_DisplaySize.x, _4904.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4904] = float4(r_present_backbuffer.Load(int3(_4904, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4904] = float4(r_current_interpolation_source.Load(int3(_4904, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7794 = cbFI_DisplaySize - int2(1, 1);
                int2 _7795 = clamp(_4904, int2(0, 0), _7794);
                uint _7805 = uint((_7795.y * cbFI_DisplaySize.x) + _7795.x) * 2u;
                uint _7808 = rw_nfru_select.Load<uint>(_7805 * 4 + 0);
                float2 _7809 = spvUnpackHalf2x16(_7808);
                uint _7813 = rw_nfru_select.Load<uint>((_7805 + 1u) * 4 + 0);
                float2 _7814 = spvUnpackHalf2x16(_7813);
                float _7815 = _7809.x;
                float _7817 = _7814.x;
                if (_7814.y > 1.5f)
                {
                    rw_output[_4904] = float4(_7815, _7809.y, _7817, 1.0f).xyz;
                    break;
                }
                int _22433;
                float _22434;
                float3 _22435;
                float _22436;
                float _22437;
                _22437 = 0.0f;
                _22436 = 0.0f;
                _22435 = 0.0f.xxx;
                _22434 = 0.0f;
                _22433 = -2;
                float3 _22440;
                float _22441;
                float _22442;
                float _22443;
                for (; _22433 <= 2; _22437 = _22443, _22436 = _22442, _22435 = _22440, _22434 = _22441, _22433++)
                {
                    _22443 = _22437;
                    _22442 = _22436;
                    _22441 = _22434;
                    _22440 = _22435;
                    for (int _22438 = -2; _22438 <= 2; )
                    {
                        float _7711 = float((_22438 * _22438) + (_22433 * _22433));
                        float _7716 = exp(_7711 * (-0.319999992847442626953125f));
                        int2 _7721 = int2(_22438, _22433);
                        int2 _7831 = clamp(_4904 + (_7721 * int2(2, 2)), int2(0, 0), _7794);
                        uint _7841 = uint((_7831.y * cbFI_DisplaySize.x) + _7831.x) * 2u;
                        float _7738 = exp(_7711 * (-0.5f));
                        int2 _7863 = clamp(_4904 + (_7721 * int2(6, 6)), int2(0, 0), _7794);
                        _22443 += _7738;
                        _22442 += (_7738 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7863.y * cbFI_DisplaySize.x) + _7863.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _22441 += _7716;
                        _22440 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7841 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7841 + 1u) * 4 + 0)).x, _19104).xyz * _7716);
                        _22438++;
                        continue;
                    }
                }
                float3 _7768 = _22435 / _22434.xxx;
                rw_output[_4904] = float4(_7768 + ((float4(_7815, _7809.y, _7817, _7814.y).xyz - _7768) * clamp(_22436 / _22437, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5416 = (float2(_4904) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5418 = float2(cbFI_MvDepthLaneSize);
        int2 _5427 = int2(floor(_5416 * _5418));
        int2 _5432 = int2(floor(_5416 * float2(cbFI_FlowLaneSize)));
        float4 _7934 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5416 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7940 = r_warped_filled_flow_tm1.Load(int3(_5432, 0)).xy;
        float2 _7946 = r_warped_filled_motion_tp1.Load(int3(_5427, 0)).xy;
        bool _7968 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19105;
        if (_7968)
        {
            float _7981 = ((2.0f * _5416.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19105 = float2(atan(_7981) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5416.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7981 * _7981))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19105 = _5416;
        }
        bool _5453 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19126;
        bool _19268;
        int2 _19349;
        float3 _21599;
        if (_5453)
        {
            float _19107;
            float _19109;
            _19109 = 2.0f;
            _19107 = -1.0f;
            uint _5003[9];
            float _22444;
            float _22447;
            for (int _19106 = 0; _19106 < 9; _19109 = _22447, _19107 = _22444, _19106++)
            {
                _5003[_19106] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5427 + int2((_19106 % 3) - 1, (_19106 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_5003[_19106] != 0u)
                {
                    float _22428;
                    if (_5003[_19106] == 0u)
                    {
                        _22428 = -1.0f;
                    }
                    else
                    {
                        _22428 = float((_5003[_19106] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _22447 = min(_19109, _22428);
                    _22444 = max(_19107, _22428);
                }
                else
                {
                    _22447 = _19109;
                    _22444 = _19107;
                }
            }
            float _5499 = float(_19107 >= 0.0f);
            float3 _18672 = 0.0f.xxx;
            _18672.y = _5499;
            float2 _19127;
            bool _19269;
            int2 _19350;
            float3 _21600;
            if ((_19107 - _19109) > 0.0199999995529651641845703125f)
            {
                float _19115;
                int2 _19116;
                float2 _19117;
                int2 _19119;
                float2 _19125;
                _19125 = _7946;
                _19119 = _5427;
                _19117 = _7946;
                _19116 = _5427;
                _19115 = -1.0f;
                float _22452;
                int2 _22456;
                float2 _22467;
                int2 _22478;
                float2 _22511;
                float _22828;
                int _19114 = 0;
                float _22409 = 1000000000.0f;
                for (; _19114 < 9; _22409 = _22828, _19125 = _22511, _19119 = _22478, _19117 = _22467, _19116 = _22456, _19115 = _22452, _19114++)
                {
                    if (_5003[_19114] == 0u)
                    {
                        _22828 = _22409;
                        _22511 = _19125;
                        _22478 = _19119;
                        _22467 = _19117;
                        _22456 = _19116;
                        _22452 = _19115;
                        continue;
                    }
                    int2 _5534 = clamp(_5427 + int2((_19114 % 3) - 1, (_19114 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8056 = _5003[_19114] & 2147483647u;
                    uint _8088 = uint(max((int((_8056 >> 16u) & 15u) - 6), 0));
                    float2 _5540 = (float2(float((1 - (2 * int((_8056 >> 15u) & 1u))) * int(((_8056 >> uint(7)) & 127u) << _8088)), float((1 - (2 * int((_8056 >> 14u) & 1u))) * int((_8056 & 127u) << _8088))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _22395;
                    if (_5003[_19114] == 0u)
                    {
                        _22395 = -1.0f;
                    }
                    else
                    {
                        _22395 = float((_5003[_19114] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5545 = _22395 - 0.100000001490116119384765625f;
                    float2 _22396;
                    if (_7968)
                    {
                        float2 _8165 = clamp((((_19105 + (_5540 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8168 = tan(_8165.x);
                        _22396 = (float2(_8168 / cbFI_DeviceToViewDepth.z, (tan(_8165.y) * sqrt(1.0f + (_8168 * _8168))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _22396 = _19105 + (_5540 * cbFI_Timestep);
                    }
                    float _5552 = cbFI_Timestep - 1.0f;
                    float2 _22397;
                    if (_7968)
                    {
                        float2 _8236 = clamp((((_19105 + (_5540 * _5552)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8239 = tan(_8236.x);
                        _22397 = (float2(_8239 / cbFI_DeviceToViewDepth.z, (tan(_8236.y) * sqrt(1.0f + (_8239 * _8239))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _22397 = _19105 + (_5540 * _5552);
                    }
                    bool _8272 = all(bool2(_22396.x > 0.0f.xx.x, _22396.y > 0.0f.xx.y));
                    bool _8278;
                    if (_8272)
                    {
                        _8278 = all(bool2(_22396.x < 1.0f.xx.x, _22396.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8278 = _8272;
                    }
                    float _22400;
                    if (_8278)
                    {
                        uint _8285_dummy_parameter;
                        _22400 = max((_5545 - (log((r_depth_tm1.Load(int3(int2(floor(_22396 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8285_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _22400 = 0.0f;
                    }
                    bool _8315 = all(bool2(_22397.x > 0.0f.xx.x, _22397.y > 0.0f.xx.y));
                    bool _8321;
                    if (_8315)
                    {
                        _8321 = all(bool2(_22397.x < 1.0f.xx.x, _22397.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8321 = _8315;
                    }
                    float _22401;
                    if (_8321)
                    {
                        uint _8328_dummy_parameter;
                        _22401 = _22400 + max((_5545 - (log((r_depth_tp1.Load(int3(int2(floor(_22397 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8328_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _22401 = _22400;
                    }
                    float _22453;
                    int2 _22457;
                    float2 _22468;
                    int2 _22479;
                    float2 _22512;
                    float _22829;
                    if (_22401 == 0.0f)
                    {
                        bool _5587 = _5545 > _19115;
                        bool2 _22837 = _5587.xx;
                        _22829 = _22409;
                        _22512 = float2(_22837.x ? _5540.x : _19125.x, _22837.y ? _5540.y : _19125.y);
                        _22479 = int2(_22837.x ? _5534.x : _19119.x, _22837.y ? _5534.y : _19119.y);
                        _22468 = _19117;
                        _22457 = _19116;
                        _22453 = _5587 ? _5545 : _19115;
                    }
                    else
                    {
                        bool _5596 = _22401 < _22409;
                        bool2 _22833 = _5596.xx;
                        _22829 = _5596 ? _22401 : _22409;
                        _22512 = _19125;
                        _22479 = _19119;
                        _22468 = float2(_22833.x ? _5540.x : _19117.x, _22833.y ? _5540.y : _19117.y);
                        _22457 = int2(_22833.x ? _5534.x : _19116.x, _22833.y ? _5534.y : _19116.y);
                        _22453 = _19115;
                    }
                    _22828 = _22829;
                    _22511 = _22512;
                    _22478 = _22479;
                    _22467 = _22468;
                    _22456 = _22457;
                    _22452 = _22453;
                }
                bool _5608 = _19115 < 0.0f;
                bool2 _22843 = _5608.xx;
                int2 _22846 = int2(_22843.x ? _19116.x : _19119.x, _22843.y ? _19116.y : _19119.y);
                _21600 = float3(1.0f, _5499, float(any(bool2(_22846.x != _5427.x, _22846.y != _5427.y))));
                _19350 = _22846;
                _19269 = _5608 ? false : true;
                _19127 = float2(_22843.x ? _19117.x : _19125.x, _22843.y ? _19117.y : _19125.y);
            }
            else
            {
                _21600 = _18672;
                _19350 = _5427;
                _19269 = false;
                _19127 = _7946;
            }
            _21599 = _21600;
            _19349 = _19350;
            _19268 = _19269;
            _19126 = _19127;
        }
        else
        {
            _21599 = 0.0f.xxx;
            _19349 = _5427;
            _19268 = false;
            _19126 = _7946;
        }
        float2 _19128;
        if (_7968)
        {
            float2 _8393 = clamp((((_19105 + (_19126 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8396 = tan(_8393.x);
            _19128 = (float2(_8396 / cbFI_DeviceToViewDepth.z, (tan(_8393.y) * sqrt(1.0f + (_8396 * _8396))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19128 = _19105 + (_19126 * cbFI_Timestep);
        }
        float _5631 = cbFI_Timestep - 1.0f;
        float2 _19130;
        if (_7968)
        {
            float2 _8464 = clamp((((_19105 + (_19126 * _5631)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8467 = tan(_8464.x);
            _19130 = (float2(_8467 / cbFI_DeviceToViewDepth.z, (tan(_8464.y) * sqrt(1.0f + (_8467 * _8467))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19130 = _19105 + (_19126 * _5631);
        }
        float _5636 = -cbFI_Timestep;
        float2 _19131;
        if (_7968)
        {
            float2 _8535 = clamp((((_19105 + (_7940 * _5636)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8538 = tan(_8535.x);
            _19131 = (float2(_8538 / cbFI_DeviceToViewDepth.z, (tan(_8535.y) * sqrt(1.0f + (_8538 * _8538))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19131 = _19105 + (_7940 * _5636);
        }
        float _5641 = 1.0f - cbFI_Timestep;
        float2 _19132;
        if (_7968)
        {
            float2 _8606 = clamp((((_19105 + (_7940 * _5641)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8609 = tan(_8606.x);
            _19132 = (float2(_8609 / cbFI_DeviceToViewDepth.z, (tan(_8606.y) * sqrt(1.0f + (_8609 * _8609))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19132 = _19105 + (_7940 * _5641);
        }
        float4 _8644 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19128, 0.0f);
        float3 _8645 = _8644.xyz;
        float4 _8652 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19130, 0.0f);
        float3 _8653 = _8652.xyz;
        float4 _8660 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19131, 0.0f);
        float3 _8661 = _8660.xyz;
        float4 _8668 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19132, 0.0f);
        float3 _8669 = _8668.xyz;
        float4 _8683 = exp(_7934 - max(max(max(_7934.x, _7934.y), _7934.z), _7934.w).xxxx);
        float4 _8690 = _8683 / (dot(_8683, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5657 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19339;
        float _20647;
        if (_5657)
        {
            float2 _5663 = 0.5f.xx / _5418;
            float _5666 = _5663.x;
            float _5667 = -_5666;
            float _5669 = _5663.y;
            float _5670 = -_5669;
            float2 _5672 = _5416 + float2(_5667, _5670);
            float2 _5674 = float2(cbFI_DisplaySize);
            bool _19149;
            do
            {
                bool _8770 = all(bool2(_5672.x > 0.0f.xx.x, _5672.y > 0.0f.xx.y));
                bool _8776;
                if (_8770)
                {
                    _8776 = all(bool2(_5672.x < 1.0f.xx.x, _5672.y < 1.0f.xx.y));
                }
                else
                {
                    _8776 = _8770;
                }
                if (!_8776)
                {
                    _19149 = false;
                    break;
                }
                uint _8783_dummy_parameter;
                float4x4 _19147;
                do
                {
                    float4x4 _8797;
                    bool _19146;
                    do
                    {
                        _8797 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19146 = false;
                            break;
                        }
                        uint _8831 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8831 + 32u) * 4 + 0) != 1u)
                        {
                            _19146 = false;
                            break;
                        }
                        uint _19143;
                        _19143 = 0u;
                        for (; _19143 < 4u; _19143++)
                        {
                            for (uint _19144 = 0u; _19144 < 4u; )
                            {
                                _8797[_19143][_19144] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8831 + (_19143 * 4u)) + _19144) * 4 + 0));
                                _19144++;
                                continue;
                            }
                        }
                        _19146 = true;
                        break;
                    } while(false);
                    if (_19146)
                    {
                        _19147 = _8797;
                        break;
                    }
                    _19147 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19148;
                do
                {
                    float _8908 = _5672.x;
                    float _8911 = 1.0f - _5672.y;
                    float4 _8922 = mul(float4((float2(_8908, _8911) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5672 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8783_dummy_parameter))))), 0)).x, 1.0f), _19147);
                    float _8924 = _8922.w;
                    if (!(_8924 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19148 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8937 = ((_8922.xy / _8924.xx) + 1.0f.xx) * 0.5f;
                    _19148 = float2(_8937.x - _8908, _8911 - _8937.y);
                    break;
                } while(false);
                float2 _8734 = abs(_19148);
                if (any(bool2(_8734.x > 100000.0f.xx.x, _8734.y > 100000.0f.xx.y)))
                {
                    _19149 = false;
                    break;
                }
                float _8742 = length(_19148 * _5674);
                uint _8957_dummy_parameter;
                bool _8756 = _8742 > ((8.0f * _5674.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8763;
                if (_8756)
                {
                    _8763 = length((r_motion_tp1.Load(int3(int2(floor(_5672 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8957_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5674) < (0.20000000298023223876953125f * _8742);
                }
                else
                {
                    _8763 = _8756;
                }
                _19149 = _8763;
                break;
            } while(false);
            float2 _5684 = _5416 + float2(_5666, _5670);
            bool _19156;
            do
            {
                bool _9043 = all(bool2(_5684.x > 0.0f.xx.x, _5684.y > 0.0f.xx.y));
                bool _9049;
                if (_9043)
                {
                    _9049 = all(bool2(_5684.x < 1.0f.xx.x, _5684.y < 1.0f.xx.y));
                }
                else
                {
                    _9049 = _9043;
                }
                if (!_9049)
                {
                    _19156 = false;
                    break;
                }
                uint _9056_dummy_parameter;
                float4x4 _19154;
                do
                {
                    float4x4 _9070;
                    bool _19153;
                    do
                    {
                        _9070 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19153 = false;
                            break;
                        }
                        uint _9104 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9104 + 32u) * 4 + 0) != 1u)
                        {
                            _19153 = false;
                            break;
                        }
                        uint _19150;
                        _19150 = 0u;
                        for (; _19150 < 4u; _19150++)
                        {
                            for (uint _19151 = 0u; _19151 < 4u; )
                            {
                                _9070[_19150][_19151] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9104 + (_19150 * 4u)) + _19151) * 4 + 0));
                                _19151++;
                                continue;
                            }
                        }
                        _19153 = true;
                        break;
                    } while(false);
                    if (_19153)
                    {
                        _19154 = _9070;
                        break;
                    }
                    _19154 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19155;
                do
                {
                    float _9181 = _5684.x;
                    float _9184 = 1.0f - _5684.y;
                    float4 _9195 = mul(float4((float2(_9181, _9184) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5684 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9056_dummy_parameter))))), 0)).x, 1.0f), _19154);
                    float _9197 = _9195.w;
                    if (!(_9197 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19155 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9210 = ((_9195.xy / _9197.xx) + 1.0f.xx) * 0.5f;
                    _19155 = float2(_9210.x - _9181, _9184 - _9210.y);
                    break;
                } while(false);
                float2 _9007 = abs(_19155);
                if (any(bool2(_9007.x > 100000.0f.xx.x, _9007.y > 100000.0f.xx.y)))
                {
                    _19156 = false;
                    break;
                }
                float _9015 = length(_19155 * _5674);
                uint _9230_dummy_parameter;
                bool _9029 = _9015 > ((8.0f * _5674.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9036;
                if (_9029)
                {
                    _9036 = length((r_motion_tp1.Load(int3(int2(floor(_5684 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9230_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5674) < (0.20000000298023223876953125f * _9015);
                }
                else
                {
                    _9036 = _9029;
                }
                _19156 = _9036;
                break;
            } while(false);
            float2 _5697 = _5416 + float2(_5667, _5669);
            bool _19163;
            do
            {
                bool _9316 = all(bool2(_5697.x > 0.0f.xx.x, _5697.y > 0.0f.xx.y));
                bool _9322;
                if (_9316)
                {
                    _9322 = all(bool2(_5697.x < 1.0f.xx.x, _5697.y < 1.0f.xx.y));
                }
                else
                {
                    _9322 = _9316;
                }
                if (!_9322)
                {
                    _19163 = false;
                    break;
                }
                uint _9329_dummy_parameter;
                float4x4 _19161;
                do
                {
                    float4x4 _9343;
                    bool _19160;
                    do
                    {
                        _9343 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19160 = false;
                            break;
                        }
                        uint _9377 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9377 + 32u) * 4 + 0) != 1u)
                        {
                            _19160 = false;
                            break;
                        }
                        uint _19157;
                        _19157 = 0u;
                        for (; _19157 < 4u; _19157++)
                        {
                            for (uint _19158 = 0u; _19158 < 4u; )
                            {
                                _9343[_19157][_19158] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9377 + (_19157 * 4u)) + _19158) * 4 + 0));
                                _19158++;
                                continue;
                            }
                        }
                        _19160 = true;
                        break;
                    } while(false);
                    if (_19160)
                    {
                        _19161 = _9343;
                        break;
                    }
                    _19161 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19162;
                do
                {
                    float _9454 = _5697.x;
                    float _9457 = 1.0f - _5697.y;
                    float4 _9468 = mul(float4((float2(_9454, _9457) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5697 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9329_dummy_parameter))))), 0)).x, 1.0f), _19161);
                    float _9470 = _9468.w;
                    if (!(_9470 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19162 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9483 = ((_9468.xy / _9470.xx) + 1.0f.xx) * 0.5f;
                    _19162 = float2(_9483.x - _9454, _9457 - _9483.y);
                    break;
                } while(false);
                float2 _9280 = abs(_19162);
                if (any(bool2(_9280.x > 100000.0f.xx.x, _9280.y > 100000.0f.xx.y)))
                {
                    _19163 = false;
                    break;
                }
                float _9288 = length(_19162 * _5674);
                uint _9503_dummy_parameter;
                bool _9302 = _9288 > ((8.0f * _5674.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9309;
                if (_9302)
                {
                    _9309 = length((r_motion_tp1.Load(int3(int2(floor(_5697 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9503_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5674) < (0.20000000298023223876953125f * _9288);
                }
                else
                {
                    _9309 = _9302;
                }
                _19163 = _9309;
                break;
            } while(false);
            float2 _5709 = _5416 + _5663;
            bool _19170;
            do
            {
                bool _9589 = all(bool2(_5709.x > 0.0f.xx.x, _5709.y > 0.0f.xx.y));
                bool _9595;
                if (_9589)
                {
                    _9595 = all(bool2(_5709.x < 1.0f.xx.x, _5709.y < 1.0f.xx.y));
                }
                else
                {
                    _9595 = _9589;
                }
                if (!_9595)
                {
                    _19170 = false;
                    break;
                }
                uint _9602_dummy_parameter;
                float4x4 _19168;
                do
                {
                    float4x4 _9616;
                    bool _19167;
                    do
                    {
                        _9616 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19167 = false;
                            break;
                        }
                        uint _9650 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9650 + 32u) * 4 + 0) != 1u)
                        {
                            _19167 = false;
                            break;
                        }
                        uint _19164;
                        _19164 = 0u;
                        for (; _19164 < 4u; _19164++)
                        {
                            for (uint _19165 = 0u; _19165 < 4u; )
                            {
                                _9616[_19164][_19165] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9650 + (_19164 * 4u)) + _19165) * 4 + 0));
                                _19165++;
                                continue;
                            }
                        }
                        _19167 = true;
                        break;
                    } while(false);
                    if (_19167)
                    {
                        _19168 = _9616;
                        break;
                    }
                    _19168 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19169;
                do
                {
                    float _9727 = _5709.x;
                    float _9730 = 1.0f - _5709.y;
                    float4 _9741 = mul(float4((float2(_9727, _9730) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5709 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9602_dummy_parameter))))), 0)).x, 1.0f), _19168);
                    float _9743 = _9741.w;
                    if (!(_9743 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19169 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9756 = ((_9741.xy / _9743.xx) + 1.0f.xx) * 0.5f;
                    _19169 = float2(_9756.x - _9727, _9730 - _9756.y);
                    break;
                } while(false);
                float2 _9553 = abs(_19169);
                if (any(bool2(_9553.x > 100000.0f.xx.x, _9553.y > 100000.0f.xx.y)))
                {
                    _19170 = false;
                    break;
                }
                float _9561 = length(_19169 * _5674);
                uint _9776_dummy_parameter;
                bool _9575 = _9561 > ((8.0f * _5674.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9582;
                if (_9575)
                {
                    _9582 = length((r_motion_tp1.Load(int3(int2(floor(_5709 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9776_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5674) < (0.20000000298023223876953125f * _9561);
                }
                else
                {
                    _9582 = _9575;
                }
                _19170 = _9582;
                break;
            } while(false);
            float _5715 = 0.25f * (((float(_19149) + float(_19156)) + float(_19163)) + float(_19170));
            float4 _19340;
            if (_5715 < 1.0f)
            {
                bool _19177;
                do
                {
                    bool _9862 = all(bool2(_19128.x > 0.0f.xx.x, _19128.y > 0.0f.xx.y));
                    bool _9868;
                    if (_9862)
                    {
                        _9868 = all(bool2(_19128.x < 1.0f.xx.x, _19128.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9868 = _9862;
                    }
                    if (!_9868)
                    {
                        _19177 = false;
                        break;
                    }
                    uint _9875_dummy_parameter;
                    float4x4 _19175;
                    do
                    {
                        float4x4 _9889;
                        bool _19174;
                        do
                        {
                            _9889 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19174 = false;
                                break;
                            }
                            uint _9923 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9923 + 32u) * 4 + 0) != 1u)
                            {
                                _19174 = false;
                                break;
                            }
                            uint _19171;
                            _19171 = 0u;
                            for (; _19171 < 4u; _19171++)
                            {
                                for (uint _19172 = 0u; _19172 < 4u; )
                                {
                                    _9889[_19171][_19172] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9923 + (_19171 * 4u)) + _19172) * 4 + 0));
                                    _19172++;
                                    continue;
                                }
                            }
                            _19174 = true;
                            break;
                        } while(false);
                        if (_19174)
                        {
                            _19175 = _9889;
                            break;
                        }
                        _19175 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19176;
                    do
                    {
                        float _10003 = 1.0f - _19128.y;
                        float4 _10014 = mul(float4((float2(_19128.x, _10003) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19128 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9875_dummy_parameter))))), 0)).x, 1.0f), _19175);
                        float _10016 = _10014.w;
                        if (!(_10016 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19176 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10029 = ((_10014.xy / _10016.xx) + 1.0f.xx) * 0.5f;
                        _19176 = float2(_10029.x - _19128.x, _10003 - _10029.y);
                        break;
                    } while(false);
                    float2 _9826 = abs(_19176);
                    if (any(bool2(_9826.x > 100000.0f.xx.x, _9826.y > 100000.0f.xx.y)))
                    {
                        _19177 = false;
                        break;
                    }
                    float _9834 = length(_19176 * _5674);
                    uint _10049_dummy_parameter;
                    bool _9848 = _9834 > ((8.0f * _5674.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9855;
                    if (_9848)
                    {
                        _9855 = length((r_motion_tp1.Load(int3(int2(floor(_19128 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10049_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5674) < (0.20000000298023223876953125f * _9834);
                    }
                    else
                    {
                        _9855 = _9848;
                    }
                    _19177 = _9855;
                    break;
                } while(false);
                bool _19184;
                do
                {
                    bool _10135 = all(bool2(_19130.x > 0.0f.xx.x, _19130.y > 0.0f.xx.y));
                    bool _10141;
                    if (_10135)
                    {
                        _10141 = all(bool2(_19130.x < 1.0f.xx.x, _19130.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10141 = _10135;
                    }
                    if (!_10141)
                    {
                        _19184 = false;
                        break;
                    }
                    uint _10148_dummy_parameter;
                    float4x4 _19182;
                    do
                    {
                        float4x4 _10162;
                        bool _19181;
                        do
                        {
                            _10162 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19181 = false;
                                break;
                            }
                            uint _10196 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10196 + 32u) * 4 + 0) != 1u)
                            {
                                _19181 = false;
                                break;
                            }
                            uint _19178;
                            _19178 = 0u;
                            for (; _19178 < 4u; _19178++)
                            {
                                for (uint _19179 = 0u; _19179 < 4u; )
                                {
                                    _10162[_19178][_19179] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10196 + (_19178 * 4u)) + _19179) * 4 + 0));
                                    _19179++;
                                    continue;
                                }
                            }
                            _19181 = true;
                            break;
                        } while(false);
                        if (_19181)
                        {
                            _19182 = _10162;
                            break;
                        }
                        _19182 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19183;
                    do
                    {
                        float _10276 = 1.0f - _19130.y;
                        float4 _10287 = mul(float4((float2(_19130.x, _10276) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10148_dummy_parameter))))), 0)).x, 1.0f), _19182);
                        float _10289 = _10287.w;
                        if (!(_10289 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19183 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10302 = ((_10287.xy / _10289.xx) + 1.0f.xx) * 0.5f;
                        _19183 = float2(_10302.x - _19130.x, _10276 - _10302.y);
                        break;
                    } while(false);
                    float2 _10099 = abs(_19183);
                    if (any(bool2(_10099.x > 100000.0f.xx.x, _10099.y > 100000.0f.xx.y)))
                    {
                        _19184 = false;
                        break;
                    }
                    float _10107 = length(_19183 * _5674);
                    uint _10322_dummy_parameter;
                    bool _10121 = _10107 > ((8.0f * _5674.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10128;
                    if (_10121)
                    {
                        _10128 = length((r_motion_tp1.Load(int3(int2(floor(_19130 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10322_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5674) < (0.20000000298023223876953125f * _10107);
                    }
                    else
                    {
                        _10128 = _10121;
                    }
                    _19184 = _10128;
                    break;
                } while(false);
                bool _19191;
                do
                {
                    bool _10408 = all(bool2(_19131.x > 0.0f.xx.x, _19131.y > 0.0f.xx.y));
                    bool _10414;
                    if (_10408)
                    {
                        _10414 = all(bool2(_19131.x < 1.0f.xx.x, _19131.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10414 = _10408;
                    }
                    if (!_10414)
                    {
                        _19191 = false;
                        break;
                    }
                    uint _10421_dummy_parameter;
                    float4x4 _19189;
                    do
                    {
                        float4x4 _10435;
                        bool _19188;
                        do
                        {
                            _10435 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19188 = false;
                                break;
                            }
                            uint _10469 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10469 + 32u) * 4 + 0) != 1u)
                            {
                                _19188 = false;
                                break;
                            }
                            uint _19185;
                            _19185 = 0u;
                            for (; _19185 < 4u; _19185++)
                            {
                                for (uint _19186 = 0u; _19186 < 4u; )
                                {
                                    _10435[_19185][_19186] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10469 + (_19185 * 4u)) + _19186) * 4 + 0));
                                    _19186++;
                                    continue;
                                }
                            }
                            _19188 = true;
                            break;
                        } while(false);
                        if (_19188)
                        {
                            _19189 = _10435;
                            break;
                        }
                        _19189 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19190;
                    do
                    {
                        float _10549 = 1.0f - _19131.y;
                        float4 _10560 = mul(float4((float2(_19131.x, _10549) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19131 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10421_dummy_parameter))))), 0)).x, 1.0f), _19189);
                        float _10562 = _10560.w;
                        if (!(_10562 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19190 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10575 = ((_10560.xy / _10562.xx) + 1.0f.xx) * 0.5f;
                        _19190 = float2(_10575.x - _19131.x, _10549 - _10575.y);
                        break;
                    } while(false);
                    float2 _10372 = abs(_19190);
                    if (any(bool2(_10372.x > 100000.0f.xx.x, _10372.y > 100000.0f.xx.y)))
                    {
                        _19191 = false;
                        break;
                    }
                    float _10380 = length(_19190 * _5674);
                    uint _10595_dummy_parameter;
                    bool _10394 = _10380 > ((8.0f * _5674.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10401;
                    if (_10394)
                    {
                        _10401 = length((r_motion_tp1.Load(int3(int2(floor(_19131 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10595_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5674) < (0.20000000298023223876953125f * _10380);
                    }
                    else
                    {
                        _10401 = _10394;
                    }
                    _19191 = _10401;
                    break;
                } while(false);
                bool _19198;
                do
                {
                    bool _10681 = all(bool2(_19132.x > 0.0f.xx.x, _19132.y > 0.0f.xx.y));
                    bool _10687;
                    if (_10681)
                    {
                        _10687 = all(bool2(_19132.x < 1.0f.xx.x, _19132.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10687 = _10681;
                    }
                    if (!_10687)
                    {
                        _19198 = false;
                        break;
                    }
                    uint _10694_dummy_parameter;
                    float4x4 _19196;
                    do
                    {
                        float4x4 _10708;
                        bool _19195;
                        do
                        {
                            _10708 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19195 = false;
                                break;
                            }
                            uint _10742 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10742 + 32u) * 4 + 0) != 1u)
                            {
                                _19195 = false;
                                break;
                            }
                            uint _19192;
                            _19192 = 0u;
                            for (; _19192 < 4u; _19192++)
                            {
                                for (uint _19193 = 0u; _19193 < 4u; )
                                {
                                    _10708[_19192][_19193] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10742 + (_19192 * 4u)) + _19193) * 4 + 0));
                                    _19193++;
                                    continue;
                                }
                            }
                            _19195 = true;
                            break;
                        } while(false);
                        if (_19195)
                        {
                            _19196 = _10708;
                            break;
                        }
                        _19196 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19197;
                    do
                    {
                        float _10822 = 1.0f - _19132.y;
                        float4 _10833 = mul(float4((float2(_19132.x, _10822) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10694_dummy_parameter))))), 0)).x, 1.0f), _19196);
                        float _10835 = _10833.w;
                        if (!(_10835 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19197 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10848 = ((_10833.xy / _10835.xx) + 1.0f.xx) * 0.5f;
                        _19197 = float2(_10848.x - _19132.x, _10822 - _10848.y);
                        break;
                    } while(false);
                    float2 _10645 = abs(_19197);
                    if (any(bool2(_10645.x > 100000.0f.xx.x, _10645.y > 100000.0f.xx.y)))
                    {
                        _19198 = false;
                        break;
                    }
                    float _10653 = length(_19197 * _5674);
                    uint _10868_dummy_parameter;
                    bool _10667 = _10653 > ((8.0f * _5674.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10674;
                    if (_10667)
                    {
                        _10674 = length((r_motion_tp1.Load(int3(int2(floor(_19132 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10868_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5674) < (0.20000000298023223876953125f * _10653);
                    }
                    else
                    {
                        _10674 = _10667;
                    }
                    _19198 = _10674;
                    break;
                } while(false);
                float4 _5742 = _8690 * float4(_19177 ? 0.0f : 1.0f, _19184 ? 0.0f : 1.0f, _19191 ? 0.0f : 1.0f, _19198 ? 0.0f : 1.0f);
                float _5744 = dot(_5742, 1.0f.xxxx);
                float4 _19341;
                if (_5744 > 0.001000000047497451305389404296875f)
                {
                    _19341 = _5742 / _5744.xxxx;
                }
                else
                {
                    _19341 = _8690;
                }
                _19340 = _19341;
            }
            else
            {
                _19340 = _8690;
            }
            _20647 = _5715;
            _19339 = _19340;
        }
        else
        {
            _20647 = 0.0f;
            _19339 = _8690;
        }
        bool _5761 = _5453 && (!_19268);
        bool _5770;
        if (_5761)
        {
            _5770 = (_19339.z + _19339.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5770 = _5761;
        }
        bool _5781;
        if (_5770)
        {
            _5781 = length((_19131 - _19128) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5781 = _5770;
        }
        bool _19428;
        if (_5781)
        {
            uint4 _10897 = r_warped_motion_qdata_tp1.Load(int3(_19349, 0));
            uint _10898 = _10897.x;
            bool _19431;
            if (_10898 != 0u)
            {
                float _19417;
                if (_10898 == 0u)
                {
                    _19417 = -1.0f;
                }
                else
                {
                    _19417 = float((_10898 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5791 = _19417 - 0.12000000476837158203125f;
                bool _10917 = all(bool2(_19131.x > 0.0f.xx.x, _19131.y > 0.0f.xx.y));
                bool _10923;
                if (_10917)
                {
                    _10923 = all(bool2(_19131.x < 1.0f.xx.x, _19131.y < 1.0f.xx.y));
                }
                else
                {
                    _10923 = _10917;
                }
                bool _5801;
                if (_10923)
                {
                    uint _10930_dummy_parameter;
                    _5801 = (log((r_depth_tm1.Load(int3(int2(floor(_19131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10930_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5791;
                }
                else
                {
                    _5801 = _10923;
                }
                bool _5815;
                if (!_5801)
                {
                    bool _10960 = all(bool2(_19132.x > 0.0f.xx.x, _19132.y > 0.0f.xx.y));
                    bool _10966;
                    if (_10960)
                    {
                        _10966 = all(bool2(_19132.x < 1.0f.xx.x, _19132.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10966 = _10960;
                    }
                    bool _5813;
                    if (_10966)
                    {
                        uint _10973_dummy_parameter;
                        _5813 = (log((r_depth_tp1.Load(int3(int2(floor(_19132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10973_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5791;
                    }
                    else
                    {
                        _5813 = _10966;
                    }
                    _5815 = _5813;
                }
                else
                {
                    _5815 = _5801;
                }
                _19431 = _5815;
            }
            else
            {
                _19431 = false;
            }
            _19428 = _19431;
        }
        else
        {
            _19428 = false;
        }
        bool _5820 = _19268 || _19428;
        bool _5825;
        if (_5820)
        {
            bool _11003 = all(bool2(_19128.x > 0.0f.xx.x, _19128.y > 0.0f.xx.y));
            bool _11009;
            if (_11003)
            {
                _11009 = all(bool2(_19128.x < 1.0f.xx.x, _19128.y < 1.0f.xx.y));
            }
            else
            {
                _11009 = _11003;
            }
            _5825 = _11009;
        }
        else
        {
            _5825 = _5820;
        }
        bool _5830;
        if (_5825)
        {
            bool _11014 = all(bool2(_19130.x > 0.0f.xx.x, _19130.y > 0.0f.xx.y));
            bool _11020;
            if (_11014)
            {
                _11020 = all(bool2(_19130.x < 1.0f.xx.x, _19130.y < 1.0f.xx.y));
            }
            else
            {
                _11020 = _11014;
            }
            _5830 = _11020;
        }
        else
        {
            _5830 = _5825;
        }
        float4 _19551;
        if (_5830)
        {
            float _5836 = _19339.x + _19339.y;
            float _5841 = _19339.z + _19339.w;
            float _19446;
            if (_5836 > 0.001000000047497451305389404296875f)
            {
                _19446 = _19339.x / _5836;
            }
            else
            {
                _19446 = _5641;
            }
            _19551 = float4(_19339.x + (_5841 * _19446), _19339.y + (_5841 * (1.0f - _19446)), 0.0f, 0.0f);
        }
        else
        {
            _19551 = _19339;
        }
        bool _11048 = (cbFI_pad0 & 1024u) != 0u;
        bool _11024 = !_11048;
        bool _11025 = !_11024;
        bool _11042;
        if (_11025)
        {
            _11042 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19349.y * cbFI_MvDepthLaneSize.x) + _19349.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11042 = _11024;
        }
        bool _11074;
        if (_11025)
        {
            _11074 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5432.y * cbFI_FlowLaneSize.x) + _5432.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11074 = _11024;
        }
        float _5876 = float(_11074);
        bool _19572;
        float4 _19611;
        float3 _21341;
        if (_11048)
        {
            bool _5886;
            if (_11042)
            {
                _5886 = all(bool2(_19128.x > 0.0f.xx.x, _19128.y > 0.0f.xx.y));
            }
            else
            {
                _5886 = _11042;
            }
            bool _5892;
            if (_5886)
            {
                _5892 = all(bool2(_19128.x < 1.0f.xx.x, _19128.y < 1.0f.xx.y));
            }
            else
            {
                _5892 = _5886;
            }
            bool _5899;
            if (_11042)
            {
                _5899 = all(bool2(_19130.x > 0.0f.xx.x, _19130.y > 0.0f.xx.y));
            }
            else
            {
                _5899 = _11042;
            }
            bool _5905;
            if (_5899)
            {
                _5905 = all(bool2(_19130.x < 1.0f.xx.x, _19130.y < 1.0f.xx.y));
            }
            else
            {
                _5905 = _5899;
            }
            bool _5912;
            if (_11074)
            {
                _5912 = all(bool2(_19131.x > 0.0f.xx.x, _19131.y > 0.0f.xx.y));
            }
            else
            {
                _5912 = _11074;
            }
            bool _5918;
            if (_5912)
            {
                _5918 = all(bool2(_19131.x < 1.0f.xx.x, _19131.y < 1.0f.xx.y));
            }
            else
            {
                _5918 = _5912;
            }
            bool _5925;
            if (_11074)
            {
                _5925 = all(bool2(_19132.x > 0.0f.xx.x, _19132.y > 0.0f.xx.y));
            }
            else
            {
                _5925 = _11074;
            }
            bool _5931;
            if (_5925)
            {
                _5931 = all(bool2(_19132.x < 1.0f.xx.x, _19132.y < 1.0f.xx.y));
            }
            else
            {
                _5931 = _5925;
            }
            bool _5933 = !_11042;
            if (_5933)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11116;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11116);
                }
            }
            bool _5938 = !_11074;
            if (_5938)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11126;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11126);
                }
            }
            if (_11042 && _5938)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11136;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11136);
                }
            }
            if (_5933 && _11074)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11146;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11146);
                }
            }
            float _5957 = float(_5892);
            float _5959 = float(_5905);
            bool _5962 = _5918 && _5931;
            float _19480;
            if (_5962)
            {
                _19480 = 1.0f;
            }
            else
            {
                _19480 = (_5918 || _5931) ? 0.5f : 0.0f;
            }
            bool _19495;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5892)) && (!_5905))
            {
                bool _5992;
                if (_5962)
                {
                    float _19488;
                    do
                    {
                        bool _11230 = all(bool2(_19131.x > 0.0f.xx.x, _19131.y > 0.0f.xx.y));
                        bool _11236;
                        if (_11230)
                        {
                            _11236 = all(bool2(_19131.x < 1.0f.xx.x, _19131.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11236 = _11230;
                        }
                        bool _11167 = !_11236;
                        bool _11174;
                        if (!_11167)
                        {
                            bool _11241 = all(bool2(_19132.x > 0.0f.xx.x, _19132.y > 0.0f.xx.y));
                            bool _11247;
                            if (_11241)
                            {
                                _11247 = all(bool2(_19132.x < 1.0f.xx.x, _19132.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11247 = _11241;
                            }
                            _11174 = !_11247;
                        }
                        else
                        {
                            _11174 = _11167;
                        }
                        if (_11174)
                        {
                            _19488 = 0.0f;
                            break;
                        }
                        uint _11254_dummy_parameter;
                        uint _11270_dummy_parameter;
                        float4x4 _19487;
                        do
                        {
                            float4x4 _11284;
                            bool _19486;
                            do
                            {
                                _11284 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _19486 = false;
                                    break;
                                }
                                uint _11318 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11318 + 32u) * 4 + 0) != 1u)
                                {
                                    _19486 = false;
                                    break;
                                }
                                uint _19483;
                                _19483 = 0u;
                                for (; _19483 < 4u; _19483++)
                                {
                                    for (uint _19484 = 0u; _19484 < 4u; )
                                    {
                                        _11284[_19483][_19484] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11318 + 16u) + (_19483 * 4u)) + _19484) * 4 + 0));
                                        _19484++;
                                        continue;
                                    }
                                }
                                _19486 = true;
                                break;
                            } while(false);
                            if (_19486)
                            {
                                _19487 = _11284;
                                break;
                            }
                            _19487 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11195 = mul(float4((float2(_19131.x, 1.0f - _19131.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11254_dummy_parameter))))), 0)).x, 1.0f), _19487);
                        float _11197 = _11195.w;
                        if (abs(_11197) < 9.9999999747524270787835121154785e-07f)
                        {
                            _19488 = 0.0f;
                            break;
                        }
                        float _11208 = abs(cbFI_DeviceToViewDepth.y / ((_11195.z / _11197) - cbFI_DeviceToViewDepth.x));
                        float _11211 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11270_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _19488 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11208 - _11211) / max(max(_11208, _11211), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _5992 = _19488 >= 0.5f;
                }
                else
                {
                    _5992 = _5962;
                }
                bool _6000;
                if (_5992)
                {
                    _6000 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _6000 = _5992;
                }
                bool _19496;
                if (_6000)
                {
                    uint _11422_dummy_parameter;
                    float4x4 _19493;
                    do
                    {
                        float4x4 _11436;
                        bool _19492;
                        do
                        {
                            _11436 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19492 = false;
                                break;
                            }
                            uint _11470 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11470 + 32u) * 4 + 0) != 1u)
                            {
                                _19492 = false;
                                break;
                            }
                            uint _19489;
                            _19489 = 0u;
                            for (; _19489 < 4u; _19489++)
                            {
                                for (uint _19490 = 0u; _19490 < 4u; )
                                {
                                    _11436[_19489][_19490] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11470 + 16u) + (_19489 * 4u)) + _19490) * 4 + 0));
                                    _19490++;
                                    continue;
                                }
                            }
                            _19492 = true;
                            break;
                        } while(false);
                        if (_19492)
                        {
                            _19493 = _11436;
                            break;
                        }
                        _19493 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _19494;
                    do
                    {
                        float _11550 = 1.0f - _19131.y;
                        float4 _11561 = mul(float4((float2(_19131.x, _11550) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11422_dummy_parameter))))), 0)).x, 1.0f), _19493);
                        float _11563 = _11561.w;
                        if (!(_11563 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19494 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11576 = ((_11561.xy / _11563.xx) + 1.0f.xx) * 0.5f;
                        _19494 = float2(_11576.x - _19131.x, _11550 - _11576.y);
                        break;
                    } while(false);
                    float2 _6013 = float2(cbFI_DisplaySize);
                    _19496 = length(((_19131 + _19494) - _19132) * _6013) <= ((0.100000001490116119384765625f * length(_19494 * _6013)) + 8.0f);
                }
                else
                {
                    _19496 = _5992;
                }
                _19495 = _19496;
            }
            else
            {
                _19495 = true;
            }
            bool _6027 = !_19495;
            bool _22847 = _6027 ? false : _5931;
            bool _22848 = _6027 ? false : _5918;
            bool _19573;
            float4 _19612;
            if (!(((_5892 && _5905) && _22848) && _22847))
            {
                float4 _6049 = _19551 * float4(_5957, _5959, float(_22848), float(_22847));
                float _6051 = dot(_6049, 1.0f.xxxx);
                bool _6054 = !(_6051 > 0.0f);
                float4 _19613;
                if (!_6054)
                {
                    _19613 = _6049 / _6051.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11598;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11598);
                    }
                    _19613 = 0.0f.xxxx;
                }
                _19612 = _19613;
                _19573 = _6054;
            }
            else
            {
                _19612 = _19551;
                _19573 = false;
            }
            _21341 = float3(_5957, _5959, _19480);
            _19611 = _19612;
            _19572 = _19573;
        }
        else
        {
            _21341 = float3(float(_11042), _5876, 0.0f);
            _19611 = _19551;
            _19572 = false;
        }
        bool _6072 = !_19572;
        float4 _19704;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6072)
        {
            float _6079 = _19611.x + _19611.y;
            float4 _19705;
            if (_6079 > 0.001000000047497451305389404296875f)
            {
                _19705 = float4(_19611.x / _6079, _19611.y / _6079, 0.0f, 0.0f);
            }
            else
            {
                _19705 = float4(_5641, cbFI_Timestep, 0.0f, 0.0f);
            }
            _19704 = _19705;
        }
        else
        {
            _19704 = _19611;
        }
        float4 _19881;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6072) && _11042)
        {
            float _19678;
            do
            {
                uint4 _11738 = r_warped_motion_qdata_tp1.Load(int3(_19349, 0));
                uint _11739 = _11738.x;
                if (_11739 != 0u)
                {
                    float _19677;
                    if (_11739 == 0u)
                    {
                        _19677 = -1.0f;
                    }
                    else
                    {
                        _19677 = float((_11739 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19678 = _19677;
                    break;
                }
                int _19660;
                uint _19661;
                _19661 = _11739;
                _19660 = -1;
                uint _19676;
                for (; _19660 <= 1; _19661 = _19676, _19660++)
                {
                    _19676 = _19661;
                    for (int _19674 = -1; _19674 <= 1; )
                    {
                        _19676 = max(_19676, r_warped_motion_qdata_tp1.Load(int3(clamp(_19349 + int2(_19674, _19660), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _19674++;
                        continue;
                    }
                }
                if (_19661 != 0u)
                {
                    float _19673;
                    if (_19661 == 0u)
                    {
                        _19673 = -1.0f;
                    }
                    else
                    {
                        _19673 = float((_19661 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19678 = _19673;
                    break;
                }
                uint _19663;
                _19663 = 4294967295u;
                uint _22548;
                for (int _19662 = 0; _19662 < 8; _19663 = _22548, _19662++)
                {
                    int _19666 = 0;
                    for (;;)
                    {
                        if (_19666 < 5)
                        {
                            int2 _11689 = _19349 + (_1251[_19662] * _1260[_19666].xx);
                            bool _11692 = any(bool2(_11689.x < int2(0, 0).x, _11689.y < int2(0, 0).y));
                            bool _11700;
                            if (!_11692)
                            {
                                _11700 = any(bool2(_11689.x >= cbFI_MvDepthLaneSize.x, _11689.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11700 = _11692;
                            }
                            if (_11700)
                            {
                                _22548 = _19663;
                                break;
                            }
                            uint4 _11778 = r_warped_motion_qdata_tp1.Load(int3(_11689, 0));
                            uint _11779 = _11778.x;
                            if (_11779 != 0u)
                            {
                                _22548 = min(_19663, _11779);
                                break;
                            }
                            _19666++;
                            continue;
                        }
                        else
                        {
                            _22548 = _19663;
                            break;
                        }
                    }
                }
                float _19665;
                if (_19663 == 4294967295u)
                {
                    _19665 = -1.0f;
                }
                else
                {
                    float _19664;
                    if (_19663 == 0u)
                    {
                        _19664 = -1.0f;
                    }
                    else
                    {
                        _19664 = float((_19663 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _19665 = _19664;
                }
                _19678 = _19665;
                break;
            } while(false);
            float _6115 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6118 = r_warped_motion_qdata_tp1.Load(int3(_19349, 0)).x == 0u;
            bool _6124;
            if (_6118)
            {
                bool _11804 = all(bool2(_19128.x > 0.0f.xx.x, _19128.y > 0.0f.xx.y));
                bool _11810;
                if (_11804)
                {
                    _11810 = all(bool2(_19128.x < 1.0f.xx.x, _19128.y < 1.0f.xx.y));
                }
                else
                {
                    _11810 = _11804;
                }
                _6124 = _11810;
            }
            else
            {
                _6124 = _6118;
            }
            bool _6129;
            if (_6124)
            {
                bool _11815 = all(bool2(_19130.x > 0.0f.xx.x, _19130.y > 0.0f.xx.y));
                bool _11821;
                if (_11815)
                {
                    _11821 = all(bool2(_19130.x < 1.0f.xx.x, _19130.y < 1.0f.xx.y));
                }
                else
                {
                    _11821 = _11815;
                }
                _6129 = _11821;
            }
            else
            {
                _6129 = _6124;
            }
            bool _19690;
            float4 _19699;
            if (_6129)
            {
                uint _11828_dummy_parameter;
                float _11852 = log((r_depth_tm1.Load(int3(int2(floor(_19128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11828_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _11860_dummy_parameter;
                float _11884 = log((r_depth_tp1.Load(int3(int2(floor(_19130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11860_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _6140 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6147;
                if (_6140)
                {
                    _6147 = _11884 > (_11852 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6147 = _6140;
                }
                bool _19695;
                float4 _19717;
                if (_6147)
                {
                    _19717 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _19695 = true;
                }
                else
                {
                    bool _6153 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6160;
                    if (_6153)
                    {
                        _6160 = _11852 > (_11884 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6160 = _6153;
                    }
                    bool4 _22849 = _6160.xxxx;
                    _19717 = float4(_22849.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _19704.x, _22849.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _19704.y, _22849.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _19704.z, _22849.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _19704.w);
                    _19695 = _6160 ? true : false;
                }
                _19699 = _19717;
                _19690 = _19695;
            }
            else
            {
                _19699 = _19704;
                _19690 = false;
            }
            float4 _19772;
            if (_19690)
            {
                _19772 = 1.0f.xxxx;
            }
            else
            {
                bool _6171 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6177;
                if (_6171)
                {
                    _6177 = _19699.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6177 = _6171;
                }
                bool _6182;
                if (_6177)
                {
                    bool _11890 = all(bool2(_19130.x > 0.0f.xx.x, _19130.y > 0.0f.xx.y));
                    bool _11896;
                    if (_11890)
                    {
                        _11896 = all(bool2(_19130.x < 1.0f.xx.x, _19130.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11896 = _11890;
                    }
                    _6182 = _11896;
                }
                else
                {
                    _6182 = _6177;
                }
                float4 _19773;
                if (_6182)
                {
                    float _19726;
                    if (_19678 >= 0.0f)
                    {
                        _19726 = _19678 - _6115;
                    }
                    else
                    {
                        float _19722;
                        _19722 = 2.0f;
                        float _11953;
                        for (int _19721 = 0; _19721 < 24; _19722 = _11953, _19721++)
                        {
                            float _11917 = float(_19721 & 7) * 0.785398185253143310546875f;
                            int _11919 = _19721 >> 3;
                            int _19723;
                            if (_11919 == 0)
                            {
                                _19723 = 16;
                            }
                            else
                            {
                                _19723 = (_11919 == 1) ? 48 : 96;
                            }
                            uint _11985_dummy_parameter;
                            _11953 = min(_19722, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19130 + ((cbFI_MvDepthLaneSizeRcp * float(_19723)) * float2(cos(_11917), sin(_11917))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11985_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _19726 = _19722;
                    }
                    uint _12017_dummy_parameter;
                    float4 _19774;
                    if (r_depth_tp1.Load(int3(int2(floor(_19130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12017_dummy_parameter))))), 0)).x > ((exp((_19726 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _19774 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _19774 = 1.0f.xxxx;
                    }
                    _19773 = _19774;
                }
                else
                {
                    _19773 = 1.0f.xxxx;
                }
                _19772 = _19773;
            }
            bool _6210 = _19678 >= 0.0f;
            bool _6211 = (!_19690) && _6210;
            bool _6218;
            if (_6211)
            {
                _6218 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6218 = _6211;
            }
            bool _6224;
            if (_6218)
            {
                _6224 = _19699.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6224 = _6218;
            }
            bool _6229;
            if (_6224)
            {
                bool _12041 = all(bool2(_19128.x > 0.0f.xx.x, _19128.y > 0.0f.xx.y));
                bool _12047;
                if (_12041)
                {
                    _12047 = all(bool2(_19128.x < 1.0f.xx.x, _19128.y < 1.0f.xx.y));
                }
                else
                {
                    _12047 = _12041;
                }
                _6229 = _12047;
            }
            else
            {
                _6229 = _6224;
            }
            float4 _19797;
            if (_6229)
            {
                float _19766;
                if (_6210)
                {
                    _19766 = _19678 - _6115;
                }
                else
                {
                    float _19762;
                    _19762 = 2.0f;
                    float _12104;
                    for (int _19761 = 0; _19761 < 24; _19762 = _12104, _19761++)
                    {
                        float _12068 = float(_19761 & 7) * 0.785398185253143310546875f;
                        int _12070 = _19761 >> 3;
                        int _19763;
                        if (_12070 == 0)
                        {
                            _19763 = 16;
                        }
                        else
                        {
                            _19763 = (_12070 == 1) ? 48 : 96;
                        }
                        uint _12120_dummy_parameter;
                        _12104 = min(_19762, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19128 + ((cbFI_MvDepthLaneSizeRcp * float(_19763)) * float2(cos(_12068), sin(_12068))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12120_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _19766 = _19762;
                }
                uint _12168_dummy_parameter;
                float4 _19798;
                if (r_depth_tm1.Load(int3(int2(floor(_19128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12168_dummy_parameter))))), 0)).x > ((exp((_19766 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _18824 = _19772;
                    _18824.x = 0.0f;
                    _19798 = _18824;
                }
                else
                {
                    _19798 = _19772;
                }
                _19797 = _19798;
            }
            else
            {
                _19797 = _19772;
            }
            float4 _19810;
            if (_6211)
            {
                float _12194 = (exp(((_19678 - _6115) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6267 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6273;
                if (_6267)
                {
                    _6273 = _19699.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6273 = _6267;
                }
                bool _6278;
                if (_6273)
                {
                    bool _12199 = all(bool2(_19132.x > 0.0f.xx.x, _19132.y > 0.0f.xx.y));
                    bool _12205;
                    if (_12199)
                    {
                        _12205 = all(bool2(_19132.x < 1.0f.xx.x, _19132.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12205 = _12199;
                    }
                    _6278 = _12205;
                }
                else
                {
                    _6278 = _6273;
                }
                bool _6286;
                if (_6278)
                {
                    uint _12212_dummy_parameter;
                    _6286 = r_depth_tp1.Load(int3(int2(floor(_19132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12212_dummy_parameter))))), 0)).x > _12194;
                }
                else
                {
                    _6286 = _6278;
                }
                float4 _19808;
                if (_6286)
                {
                    float4 _18827 = _19797;
                    _18827.w = 0.0f;
                    _19808 = _18827;
                }
                else
                {
                    _19808 = _19797;
                }
                bool _6293 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6299;
                if (_6293)
                {
                    _6299 = _19699.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6299 = _6293;
                }
                bool _6304;
                if (_6299)
                {
                    bool _12229 = all(bool2(_19131.x > 0.0f.xx.x, _19131.y > 0.0f.xx.y));
                    bool _12235;
                    if (_12229)
                    {
                        _12235 = all(bool2(_19131.x < 1.0f.xx.x, _19131.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12235 = _12229;
                    }
                    _6304 = _12235;
                }
                else
                {
                    _6304 = _6299;
                }
                bool _6312;
                if (_6304)
                {
                    uint _12242_dummy_parameter;
                    _6312 = r_depth_tm1.Load(int3(int2(floor(_19131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12242_dummy_parameter))))), 0)).x > _12194;
                }
                else
                {
                    _6312 = _6304;
                }
                float4 _19811;
                if (_6312)
                {
                    float4 _18830 = _19808;
                    _18830.z = 0.0f;
                    _19811 = _18830;
                }
                else
                {
                    _19811 = _19808;
                }
                _19810 = _19811;
            }
            else
            {
                _19810 = _19797;
            }
            float4 _19882;
            if (any(bool4(_19810.x < 1.0f.xxxx.x, _19810.y < 1.0f.xxxx.y, _19810.z < 1.0f.xxxx.z, _19810.w < 1.0f.xxxx.w)))
            {
                float4 _6323 = _19699 * _19810;
                float _6325 = dot(_6323, 1.0f.xxxx);
                float4 _19883;
                if (_6325 > 0.0f)
                {
                    _19883 = _6323 / _6325.xxxx;
                }
                else
                {
                    bool _6336 = _19810.y == 0.0f;
                    bool _6342;
                    if (_6336)
                    {
                        _6342 = _19810.x > 0.0f;
                    }
                    else
                    {
                        _6342 = _6336;
                    }
                    bool _6347;
                    if (_6342)
                    {
                        bool _12259 = all(bool2(_19128.x > 0.0f.xx.x, _19128.y > 0.0f.xx.y));
                        bool _12265;
                        if (_12259)
                        {
                            _12265 = all(bool2(_19128.x < 1.0f.xx.x, _19128.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12265 = _12259;
                        }
                        _6347 = _12265;
                    }
                    else
                    {
                        _6347 = _6342;
                    }
                    float4 _19884;
                    if (_6347)
                    {
                        _19884 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6352 = _19810.x == 0.0f;
                        bool _6358;
                        if (_6352)
                        {
                            _6358 = _19810.y > 0.0f;
                        }
                        else
                        {
                            _6358 = _6352;
                        }
                        bool _6363;
                        if (_6358)
                        {
                            bool _12270 = all(bool2(_19130.x > 0.0f.xx.x, _19130.y > 0.0f.xx.y));
                            bool _12276;
                            if (_12270)
                            {
                                _12276 = all(bool2(_19130.x < 1.0f.xx.x, _19130.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12276 = _12270;
                            }
                            _6363 = _12276;
                        }
                        else
                        {
                            _6363 = _6358;
                        }
                        bool4 _22852 = _6363.xxxx;
                        _19884 = float4(_22852.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _19699.x, _22852.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _19699.y, _22852.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _19699.z, _22852.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _19699.w);
                    }
                    _19883 = _19884;
                }
                _19882 = _19883;
            }
            else
            {
                _19882 = _19699;
            }
            _19881 = _19882;
        }
        else
        {
            _19881 = _19704;
        }
        float4 _20611;
        bool _20917;
        float3 _21089;
        if (((cbFI_pad0 & 32768u) != 0u) && _6072)
        {
            bool _6380 = _19881.x > 0.00999999977648258209228515625f;
            bool _6383 = _19881.y > 0.00999999977648258209228515625f;
            bool _6392 = (_19881.z + _19881.w) > 0.0199999995529651641845703125f;
            bool _6398;
            if (_6392)
            {
                bool _12281 = all(bool2(_19131.x > 0.0f.xx.x, _19131.y > 0.0f.xx.y));
                bool _12287;
                if (_12281)
                {
                    _12287 = all(bool2(_19131.x < 1.0f.xx.x, _19131.y < 1.0f.xx.y));
                }
                else
                {
                    _12287 = _12281;
                }
                _6398 = _12287;
            }
            else
            {
                _6398 = _6392;
            }
            bool _6403;
            if (_6398)
            {
                bool _12292 = all(bool2(_19132.x > 0.0f.xx.x, _19132.y > 0.0f.xx.y));
                bool _12298;
                if (_12292)
                {
                    _12298 = all(bool2(_19132.x < 1.0f.xx.x, _19132.y < 1.0f.xx.y));
                }
                else
                {
                    _12298 = _12292;
                }
                _6403 = _12298;
            }
            else
            {
                _6403 = _6398;
            }
            bool _6410;
            if (_6403)
            {
                float _19897;
                do
                {
                    bool _12381 = all(bool2(_19131.x > 0.0f.xx.x, _19131.y > 0.0f.xx.y));
                    bool _12387;
                    if (_12381)
                    {
                        _12387 = all(bool2(_19131.x < 1.0f.xx.x, _19131.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12387 = _12381;
                    }
                    bool _12318 = !_12387;
                    bool _12325;
                    if (!_12318)
                    {
                        bool _12392 = all(bool2(_19132.x > 0.0f.xx.x, _19132.y > 0.0f.xx.y));
                        bool _12398;
                        if (_12392)
                        {
                            _12398 = all(bool2(_19132.x < 1.0f.xx.x, _19132.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12398 = _12392;
                        }
                        _12325 = !_12398;
                    }
                    else
                    {
                        _12325 = _12318;
                    }
                    if (_12325)
                    {
                        _19897 = 0.0f;
                        break;
                    }
                    uint _12405_dummy_parameter;
                    uint _12421_dummy_parameter;
                    float4x4 _19896;
                    do
                    {
                        float4x4 _12435;
                        bool _19895;
                        do
                        {
                            _12435 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19895 = false;
                                break;
                            }
                            uint _12469 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12469 + 32u) * 4 + 0) != 1u)
                            {
                                _19895 = false;
                                break;
                            }
                            uint _19892;
                            _19892 = 0u;
                            for (; _19892 < 4u; _19892++)
                            {
                                for (uint _19893 = 0u; _19893 < 4u; )
                                {
                                    _12435[_19892][_19893] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12469 + 16u) + (_19892 * 4u)) + _19893) * 4 + 0));
                                    _19893++;
                                    continue;
                                }
                            }
                            _19895 = true;
                            break;
                        } while(false);
                        if (_19895)
                        {
                            _19896 = _12435;
                            break;
                        }
                        _19896 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12346 = mul(float4((float2(_19131.x, 1.0f - _19131.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12405_dummy_parameter))))), 0)).x, 1.0f), _19896);
                    float _12348 = _12346.w;
                    if (abs(_12348) < 9.9999999747524270787835121154785e-07f)
                    {
                        _19897 = 0.0f;
                        break;
                    }
                    float _12359 = abs(cbFI_DeviceToViewDepth.y / ((_12346.z / _12348) - cbFI_DeviceToViewDepth.x));
                    float _12362 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12421_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _19897 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12359 - _12362) / max(max(_12359, _12362), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6410 = _19897 < 0.5f;
            }
            else
            {
                _6410 = _6403;
            }
            float4 _19916;
            if (_6410)
            {
                uint _12573_dummy_parameter;
                uint _12604_dummy_parameter;
                float4 _19917;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12573_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12604_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _19917 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _19917 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _19916 = _19917;
            }
            else
            {
                _19916 = 1.0f.xxxx;
            }
            bool _6434;
            if (_11042)
            {
                bool _12633 = all(bool2(_19128.x > 0.0f.xx.x, _19128.y > 0.0f.xx.y));
                bool _12639;
                if (_12633)
                {
                    _12639 = all(bool2(_19128.x < 1.0f.xx.x, _19128.y < 1.0f.xx.y));
                }
                else
                {
                    _12639 = _12633;
                }
                _6434 = _12639;
            }
            else
            {
                _6434 = _11042;
            }
            bool _6440;
            if (_11042)
            {
                bool _12644 = all(bool2(_19130.x > 0.0f.xx.x, _19130.y > 0.0f.xx.y));
                bool _12650;
                if (_12644)
                {
                    _12650 = all(bool2(_19130.x < 1.0f.xx.x, _19130.y < 1.0f.xx.y));
                }
                else
                {
                    _12650 = _12644;
                }
                _6440 = _12650;
            }
            else
            {
                _6440 = _11042;
            }
            bool _6446;
            if (_11074)
            {
                bool _12655 = all(bool2(_19131.x > 0.0f.xx.x, _19131.y > 0.0f.xx.y));
                bool _12661;
                if (_12655)
                {
                    _12661 = all(bool2(_19131.x < 1.0f.xx.x, _19131.y < 1.0f.xx.y));
                }
                else
                {
                    _12661 = _12655;
                }
                _6446 = _12661;
            }
            else
            {
                _6446 = _11074;
            }
            bool _6452;
            if (_11074)
            {
                bool _12666 = all(bool2(_19132.x > 0.0f.xx.x, _19132.y > 0.0f.xx.y));
                bool _12672;
                if (_12666)
                {
                    _12672 = all(bool2(_19132.x < 1.0f.xx.x, _19132.y < 1.0f.xx.y));
                }
                else
                {
                    _12672 = _12666;
                }
                _6452 = _12672;
            }
            else
            {
                _6452 = _11074;
            }
            bool _6455 = _6446 != _6452;
            bool _6461;
            if (_6455)
            {
                _6461 = _6434 || _6440;
            }
            else
            {
                _6461 = _6455;
            }
            float4 _20019;
            if (_6461)
            {
                float4 _18857 = _19916;
                _18857.z = 0.0f;
                _18857.w = 0.0f;
                _20019 = _18857;
            }
            else
            {
                _20019 = _19916;
            }
            bool _6468 = _6434 && _6380;
            bool _6471 = _6440 && _6383;
            float4 _20124;
            float3 _21198;
            if (_6468 || _6471)
            {
                float _20014;
                do
                {
                    uint4 _12811 = r_warped_motion_qdata_tp1.Load(int3(_19349, 0));
                    uint _12812 = _12811.x;
                    if (_12812 != 0u)
                    {
                        float _20013;
                        if (_12812 == 0u)
                        {
                            _20013 = -1.0f;
                        }
                        else
                        {
                            _20013 = float((_12812 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20014 = _20013;
                        break;
                    }
                    int _19996;
                    uint _19997;
                    _19997 = _12812;
                    _19996 = -1;
                    uint _20012;
                    for (; _19996 <= 1; _19997 = _20012, _19996++)
                    {
                        _20012 = _19997;
                        for (int _20010 = -1; _20010 <= 1; )
                        {
                            _20012 = max(_20012, r_warped_motion_qdata_tp1.Load(int3(clamp(_19349 + int2(_20010, _19996), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20010++;
                            continue;
                        }
                    }
                    if (_19997 != 0u)
                    {
                        float _20009;
                        if (_19997 == 0u)
                        {
                            _20009 = -1.0f;
                        }
                        else
                        {
                            _20009 = float((_19997 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20014 = _20009;
                        break;
                    }
                    uint _19999;
                    _19999 = 4294967295u;
                    uint _22549;
                    for (int _19998 = 0; _19998 < 8; _19999 = _22549, _19998++)
                    {
                        int _20002 = 0;
                        for (;;)
                        {
                            if (_20002 < 5)
                            {
                                int2 _12762 = _19349 + (_1251[_19998] * _1260[_20002].xx);
                                bool _12765 = any(bool2(_12762.x < int2(0, 0).x, _12762.y < int2(0, 0).y));
                                bool _12773;
                                if (!_12765)
                                {
                                    _12773 = any(bool2(_12762.x >= cbFI_MvDepthLaneSize.x, _12762.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12773 = _12765;
                                }
                                if (_12773)
                                {
                                    _22549 = _19999;
                                    break;
                                }
                                uint4 _12851 = r_warped_motion_qdata_tp1.Load(int3(_12762, 0));
                                uint _12852 = _12851.x;
                                if (_12852 != 0u)
                                {
                                    _22549 = min(_19999, _12852);
                                    break;
                                }
                                _20002++;
                                continue;
                            }
                            else
                            {
                                _22549 = _19999;
                                break;
                            }
                        }
                    }
                    float _20001;
                    if (_19999 == 4294967295u)
                    {
                        _20001 = -1.0f;
                    }
                    else
                    {
                        float _20000;
                        if (_19999 == 0u)
                        {
                            _20000 = -1.0f;
                        }
                        else
                        {
                            _20000 = float((_19999 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20001 = _20000;
                    }
                    _20014 = _20001;
                    break;
                } while(false);
                bool _6479 = _20014 < 0.0f;
                float _20015;
                if (_6479)
                {
                    _20015 = 0.0f;
                }
                else
                {
                    _20015 = _20014 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12873_dummy_parameter;
                uint _12905_dummy_parameter;
                float4 _20052;
                if ((_6479 && _6468) && _6471)
                {
                    uint _12937_dummy_parameter;
                    float _12961 = log((r_depth_tm1.Load(int3(int2(floor(_19128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12937_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12969_dummy_parameter;
                    float _12993 = log((r_depth_tp1.Load(int3(int2(floor(_19130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12969_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20053;
                    if (_12961 > (_12993 + 0.07999999821186065673828125f))
                    {
                        float4 _18861 = _20019;
                        _18861.x = 0.0f;
                        _20053 = _18861;
                    }
                    else
                    {
                        float4 _20054;
                        if (_12993 > (_12961 + 0.07999999821186065673828125f))
                        {
                            float4 _18863 = _20019;
                            _18863.y = 0.0f;
                            _20054 = _18863;
                        }
                        else
                        {
                            _20054 = _20019;
                        }
                        _20053 = _20054;
                    }
                    _20052 = _20053;
                }
                else
                {
                    _20052 = _20019;
                }
                float _6531 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6533 = _20014 >= 0.0f;
                float _20035;
                if (_6533)
                {
                    _20035 = _20014 - _6531;
                }
                else
                {
                    float _20031;
                    if (_6468)
                    {
                        float _20030;
                        _20030 = 2.0f;
                        float _13051;
                        for (int _20029 = 0; _20029 < 24; _20030 = _13051, _20029++)
                        {
                            float _13015 = float(_20029 & 7) * 0.785398185253143310546875f;
                            int _13017 = _20029 >> 3;
                            int _20032;
                            if (_13017 == 0)
                            {
                                _20032 = 16;
                            }
                            else
                            {
                                _20032 = (_13017 == 1) ? 48 : 96;
                            }
                            uint _13067_dummy_parameter;
                            _13051 = min(_20030, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19128 + ((cbFI_MvDepthLaneSizeRcp * float(_20032)) * float2(cos(_13015), sin(_13015))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13067_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20031 = _20030;
                    }
                    else
                    {
                        _20031 = 0.0f;
                    }
                    _20035 = _20031;
                }
                float _20042;
                if (_6533)
                {
                    _20042 = _20014 - _6531;
                }
                else
                {
                    float _20038;
                    if (_6471)
                    {
                        float _20037;
                        _20037 = 2.0f;
                        float _13165;
                        for (int _20036 = 0; _20036 < 24; _20037 = _13165, _20036++)
                        {
                            float _13129 = float(_20036 & 7) * 0.785398185253143310546875f;
                            int _13131 = _20036 >> 3;
                            int _20039;
                            if (_13131 == 0)
                            {
                                _20039 = 16;
                            }
                            else
                            {
                                _20039 = (_13131 == 1) ? 48 : 96;
                            }
                            uint _13197_dummy_parameter;
                            _13165 = min(_20037, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19130 + ((cbFI_MvDepthLaneSizeRcp * float(_20039)) * float2(cos(_13129), sin(_13129))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13197_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20038 = _20037;
                    }
                    else
                    {
                        _20038 = 0.0f;
                    }
                    _20042 = _20038;
                }
                float _20043;
                if (_6468)
                {
                    uint _13229_dummy_parameter;
                    _20043 = r_depth_tm1.Load(int3(int2(floor(_19128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13229_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20043 = 0.0f;
                }
                float _20044;
                if (_6471)
                {
                    uint _13248_dummy_parameter;
                    _20044 = r_depth_tp1.Load(int3(int2(floor(_19130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13248_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20044 = 0.0f;
                }
                bool _6588;
                if (_6468)
                {
                    _6588 = _20043 > ((exp((_20035 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6588 = _6468;
                }
                float4 _20060;
                if (_6588)
                {
                    float4 _18865 = _20052;
                    _18865.x = 0.0f;
                    _20060 = _18865;
                }
                else
                {
                    _20060 = _20052;
                }
                bool _6600;
                if (_6471)
                {
                    _6600 = _20044 > ((exp((_20042 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6600 = _6471;
                }
                float4 _20062;
                if (_6600)
                {
                    float4 _18867 = _20060;
                    _18867.y = 0.0f;
                    _20062 = _18867;
                }
                else
                {
                    _20062 = _20060;
                }
                float4 _20125;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6533)
                {
                    bool _6620;
                    if (_6468)
                    {
                        _6620 = _20043 < ((exp((_20035 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6620 = _6468;
                    }
                    float4 _20064;
                    if (_6620)
                    {
                        float4 _18869 = _20062;
                        _18869.x = 0.0f;
                        _20064 = _18869;
                    }
                    else
                    {
                        _20064 = _20062;
                    }
                    bool _6632;
                    if (_6471)
                    {
                        _6632 = _20044 < ((exp((_20042 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6632 = _6471;
                    }
                    float4 _20126;
                    if (_6632)
                    {
                        float4 _18871 = _20064;
                        _18871.y = 0.0f;
                        _20126 = _18871;
                    }
                    else
                    {
                        _20126 = _20064;
                    }
                    _20125 = _20126;
                }
                else
                {
                    _20125 = _20062;
                }
                _21198 = float3(_20015, log((r_depth_tm1.Load(int3(int2(floor(_19128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12873_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_19130 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12905_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _20124 = _20125;
            }
            else
            {
                _21198 = float3(0.0f, 0.0f, 0.5f);
                _20124 = _20019;
            }
            bool _6643 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6392;
            bool _6649;
            if (_6643)
            {
                _6649 = _6446 || _6452;
            }
            else
            {
                _6649 = _6643;
            }
            float4 _20167;
            if (_6649)
            {
                float _20119;
                do
                {
                    uint4 _13427 = r_warped_motion_qdata_tp1.Load(int3(_19349, 0));
                    uint _13428 = _13427.x;
                    if (_13428 != 0u)
                    {
                        float _20118;
                        if (_13428 == 0u)
                        {
                            _20118 = -1.0f;
                        }
                        else
                        {
                            _20118 = float((_13428 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20119 = _20118;
                        break;
                    }
                    int _20101;
                    uint _20102;
                    _20102 = _13428;
                    _20101 = -1;
                    uint _20117;
                    for (; _20101 <= 1; _20102 = _20117, _20101++)
                    {
                        _20117 = _20102;
                        for (int _20115 = -1; _20115 <= 1; )
                        {
                            _20117 = max(_20117, r_warped_motion_qdata_tp1.Load(int3(clamp(_19349 + int2(_20115, _20101), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20115++;
                            continue;
                        }
                    }
                    if (_20102 != 0u)
                    {
                        float _20114;
                        if (_20102 == 0u)
                        {
                            _20114 = -1.0f;
                        }
                        else
                        {
                            _20114 = float((_20102 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20119 = _20114;
                        break;
                    }
                    uint _20104;
                    _20104 = 4294967295u;
                    uint _22550;
                    for (int _20103 = 0; _20103 < 8; _20104 = _22550, _20103++)
                    {
                        int _20107 = 0;
                        for (;;)
                        {
                            if (_20107 < 5)
                            {
                                int2 _13378 = _19349 + (_1251[_20103] * _1260[_20107].xx);
                                bool _13381 = any(bool2(_13378.x < int2(0, 0).x, _13378.y < int2(0, 0).y));
                                bool _13389;
                                if (!_13381)
                                {
                                    _13389 = any(bool2(_13378.x >= cbFI_MvDepthLaneSize.x, _13378.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13389 = _13381;
                                }
                                if (_13389)
                                {
                                    _22550 = _20104;
                                    break;
                                }
                                uint4 _13467 = r_warped_motion_qdata_tp1.Load(int3(_13378, 0));
                                uint _13468 = _13467.x;
                                if (_13468 != 0u)
                                {
                                    _22550 = min(_20104, _13468);
                                    break;
                                }
                                _20107++;
                                continue;
                            }
                            else
                            {
                                _22550 = _20104;
                                break;
                            }
                        }
                    }
                    float _20106;
                    if (_20104 == 4294967295u)
                    {
                        _20106 = -1.0f;
                    }
                    else
                    {
                        float _20105;
                        if (_20104 == 0u)
                        {
                            _20105 = -1.0f;
                        }
                        else
                        {
                            _20105 = float((_20104 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20106 = _20105;
                    }
                    _20119 = _20106;
                    break;
                } while(false);
                float4 _20168;
                if (_20119 >= 0.0f)
                {
                    float _13489 = (exp((_20119 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6668;
                    if (_6446)
                    {
                        uint _13496_dummy_parameter;
                        _6668 = r_depth_tm1.Load(int3(int2(floor(_19131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13496_dummy_parameter))))), 0)).x > _13489;
                    }
                    else
                    {
                        _6668 = _6446;
                    }
                    float4 _20137;
                    if (_6668)
                    {
                        float4 _18873 = _20124;
                        _18873.z = 0.0f;
                        _20137 = _18873;
                    }
                    else
                    {
                        _20137 = _20124;
                    }
                    bool _6680;
                    if (_6452)
                    {
                        uint _13515_dummy_parameter;
                        _6680 = r_depth_tp1.Load(int3(int2(floor(_19132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13515_dummy_parameter))))), 0)).x > _13489;
                    }
                    else
                    {
                        _6680 = _6452;
                    }
                    float4 _20169;
                    if (_6680)
                    {
                        float4 _18875 = _20137;
                        _18875.w = 0.0f;
                        _20169 = _18875;
                    }
                    else
                    {
                        _20169 = _20137;
                    }
                    _20168 = _20169;
                }
                else
                {
                    _20168 = _20124;
                }
                _20167 = _20168;
            }
            else
            {
                _20167 = _20124;
            }
            bool _6688 = _6434 != _6440;
            bool _6695;
            if (_6688)
            {
                _6695 = _6434 ? _6380 : _6383;
            }
            else
            {
                _6695 = _6688;
            }
            bool _6702;
            if (_6695)
            {
                _6702 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6702 = _6695;
            }
            float4 _20270;
            if (_6702)
            {
                bool2 _6707 = _6434.xx;
                float2 _6708 = float2(_6707.x ? _19128.x : _19130.x, _6707.y ? _19128.y : _19130.y);
                float _20151;
                if (_6434)
                {
                    uint _13534_dummy_parameter;
                    _20151 = r_depth_tm1.Load(int3(int2(floor(_6708 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13534_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13550_dummy_parameter;
                    _20151 = r_depth_tp1.Load(int3(int2(floor(_6708 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13550_dummy_parameter))))), 0)).x;
                }
                float4x4 _20158;
                if (_6434)
                {
                    float4x4 _20147;
                    do
                    {
                        float4x4 _13564;
                        bool _20146;
                        do
                        {
                            _13564 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20146 = false;
                                break;
                            }
                            uint _13598 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13598 + 32u) * 4 + 0) != 1u)
                            {
                                _20146 = false;
                                break;
                            }
                            uint _20143;
                            _20143 = 0u;
                            for (; _20143 < 4u; _20143++)
                            {
                                for (uint _20144 = 0u; _20144 < 4u; )
                                {
                                    _13564[_20143][_20144] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13598 + 16u) + (_20143 * 4u)) + _20144) * 4 + 0));
                                    _20144++;
                                    continue;
                                }
                            }
                            _20146 = true;
                            break;
                        } while(false);
                        if (_20146)
                        {
                            _20147 = _13564;
                            break;
                        }
                        _20147 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20158 = _20147;
                }
                else
                {
                    float4x4 _20142;
                    do
                    {
                        float4x4 _13670;
                        bool _20141;
                        do
                        {
                            _13670 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20141 = false;
                                break;
                            }
                            uint _13704 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13704 + 32u) * 4 + 0) != 1u)
                            {
                                _20141 = false;
                                break;
                            }
                            uint _20138;
                            _20138 = 0u;
                            for (; _20138 < 4u; _20138++)
                            {
                                for (uint _20139 = 0u; _20139 < 4u; )
                                {
                                    _13670[_20138][_20139] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13704 + (_20138 * 4u)) + _20139) * 4 + 0));
                                    _20139++;
                                    continue;
                                }
                            }
                            _20141 = true;
                            break;
                        } while(false);
                        if (_20141)
                        {
                            _20142 = _13670;
                            break;
                        }
                        _20142 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20158 = _20142;
                }
                float2 _20159;
                do
                {
                    float _13781 = _6708.x;
                    float _13784 = 1.0f - _6708.y;
                    float4 _13795 = mul(float4((float2(_13781, _13784) * 2.0f) - 1.0f.xx, _20151, 1.0f), _20158);
                    float _13797 = _13795.w;
                    if (!(_13797 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20159 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13810 = ((_13795.xy / _13797.xx) + 1.0f.xx) * 0.5f;
                    _20159 = float2(_13810.x - _13781, _13784 - _13810.y);
                    break;
                } while(false);
                float2 _6738 = float2(cbFI_DisplaySize);
                float4 _20271;
                if (!(length(((_6708 + _20159) - float2(_6707.x ? _19130.x : _19128.x, _6707.y ? _19130.y : _19128.y)) * _6738) <= ((0.100000001490116119384765625f * length(_20159 * _6738)) + 8.0f)))
                {
                    float4 _20272;
                    if (_6434)
                    {
                        float4 _18885 = _20167;
                        _18885.x = 0.0f;
                        _20272 = _18885;
                    }
                    else
                    {
                        float4 _18887 = _20167;
                        _18887.y = 0.0f;
                        _20272 = _18887;
                    }
                    _20271 = _20272;
                }
                else
                {
                    _20271 = _20167;
                }
                _20270 = _20271;
            }
            else
            {
                _20270 = _20167;
            }
            float4 _6763 = _19881 * _20270;
            float _6765 = dot(_6763, 1.0f.xxxx);
            float4 _20612;
            bool _20918;
            if (_6765 > 0.0f)
            {
                _20918 = _19572;
                _20612 = _6763 / _6765.xxxx;
            }
            else
            {
                bool _6776 = any(bool4(_20270.x < 1.0f.xxxx.x, _20270.y < 1.0f.xxxx.y, _20270.z < 1.0f.xxxx.z, _20270.w < 1.0f.xxxx.w));
                if (_6776)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13832;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13832);
                    }
                }
                bool4 _22855 = _6776.xxxx;
                _20918 = _6776 ? true : _19572;
                _20612 = float4(_22855.x ? 0.0f.xxxx.x : _19881.x, _22855.y ? 0.0f.xxxx.y : _19881.y, _22855.z ? 0.0f.xxxx.z : _19881.z, _22855.w ? 0.0f.xxxx.w : _19881.w);
            }
            _21089 = _21198;
            _20917 = _20918;
            _20611 = _20612;
        }
        else
        {
            _21089 = float3(0.0f, 0.0f, 0.5f);
            _20917 = _19572;
            _20611 = _19881;
        }
        uint _6785 = (cbFI_pad0 >> 24u) & 31u;
        uint _6789 = (cbFI_pad0 >> 16u) & 255u;
        bool _6791 = _6785 != 0u;
        bool _6793 = _6789 == 12u;
        bool _6796 = _6789 == 13u;
        float4 _20632;
        if ((_6791 || _6793) || _6796)
        {
            float _20278;
            do
            {
                bool _13916 = all(bool2(_19131.x > 0.0f.xx.x, _19131.y > 0.0f.xx.y));
                bool _13922;
                if (_13916)
                {
                    _13922 = all(bool2(_19131.x < 1.0f.xx.x, _19131.y < 1.0f.xx.y));
                }
                else
                {
                    _13922 = _13916;
                }
                bool _13853 = !_13922;
                bool _13860;
                if (!_13853)
                {
                    bool _13927 = all(bool2(_19132.x > 0.0f.xx.x, _19132.y > 0.0f.xx.y));
                    bool _13933;
                    if (_13927)
                    {
                        _13933 = all(bool2(_19132.x < 1.0f.xx.x, _19132.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13933 = _13927;
                    }
                    _13860 = !_13933;
                }
                else
                {
                    _13860 = _13853;
                }
                if (_13860)
                {
                    _20278 = 0.0f;
                    break;
                }
                uint _13940_dummy_parameter;
                uint _13956_dummy_parameter;
                float4x4 _20277;
                do
                {
                    float4x4 _13970;
                    bool _20276;
                    do
                    {
                        _13970 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20276 = false;
                            break;
                        }
                        uint _14004 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14004 + 32u) * 4 + 0) != 1u)
                        {
                            _20276 = false;
                            break;
                        }
                        uint _20273;
                        _20273 = 0u;
                        for (; _20273 < 4u; _20273++)
                        {
                            for (uint _20274 = 0u; _20274 < 4u; )
                            {
                                _13970[_20273][_20274] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14004 + 16u) + (_20273 * 4u)) + _20274) * 4 + 0));
                                _20274++;
                                continue;
                            }
                        }
                        _20276 = true;
                        break;
                    } while(false);
                    if (_20276)
                    {
                        _20277 = _13970;
                        break;
                    }
                    _20277 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13881 = mul(float4((float2(_19131.x, 1.0f - _19131.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19131 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13940_dummy_parameter))))), 0)).x, 1.0f), _20277);
                float _13883 = _13881.w;
                if (abs(_13883) < 9.9999999747524270787835121154785e-07f)
                {
                    _20278 = 0.0f;
                    break;
                }
                float _13894 = abs(cbFI_DeviceToViewDepth.y / ((_13881.z / _13883) - cbFI_DeviceToViewDepth.x));
                float _13897 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19132 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13956_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20278 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13894 - _13897) / max(max(_13894, _13897), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14106 = all(bool2(_19132.x > 0.0f.xx.x, _19132.y > 0.0f.xx.y));
            bool _14112;
            if (_14106)
            {
                _14112 = all(bool2(_19132.x < 1.0f.xx.x, _19132.y < 1.0f.xx.y));
            }
            else
            {
                _14112 = _14106;
            }
            float _20279;
            if (_14112)
            {
                uint _14119_dummy_parameter;
                _20279 = length((_7940 + (r_motion_tp1.Load(int3(int2(floor(_19132 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14119_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20279 = 1000000.0f;
            }
            float _20294;
            if ((_6785 & 1u) != 0u)
            {
                _20294 = _20278;
            }
            else
            {
                _20294 = 1.0f;
            }
            float _20295;
            if ((_6785 & 2u) != 0u)
            {
                _20295 = _20294 * (1.0f - smoothstep(2.0f, 8.0f, _20279));
            }
            else
            {
                _20295 = _20294;
            }
            float _20296;
            if ((_6785 & 4u) != 0u)
            {
                _20296 = _20295 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8661 - _8669) - length(_8645 - _8653))));
            }
            else
            {
                _20296 = _20295;
            }
            float _20626;
            if ((_6785 & 8u) != 0u)
            {
                _20626 = lerp(1.0f, _20296, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8645 - _8653)));
            }
            else
            {
                _20626 = _20296;
            }
            bool _6871 = (_6785 & 16u) != 0u;
            bool _6880;
            if (_6871)
            {
                _6880 = length(_19126 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6880 = _6871;
            }
            float _22857 = _6880 ? 1.0f : _20626;
            bool _6886 = _6791 && _11042;
            bool _6891;
            if (_6886)
            {
                bool _14144 = all(bool2(_19128.x > 0.0f.xx.x, _19128.y > 0.0f.xx.y));
                bool _14150;
                if (_14144)
                {
                    _14150 = all(bool2(_19128.x < 1.0f.xx.x, _19128.y < 1.0f.xx.y));
                }
                else
                {
                    _14150 = _14144;
                }
                _6891 = _14150;
            }
            else
            {
                _6891 = _6886;
            }
            bool _6896;
            if (_6891)
            {
                bool _14155 = all(bool2(_19130.x > 0.0f.xx.x, _19130.y > 0.0f.xx.y));
                bool _14161;
                if (_14155)
                {
                    _14161 = all(bool2(_19130.x < 1.0f.xx.x, _19130.y < 1.0f.xx.y));
                }
                else
                {
                    _14161 = _14155;
                }
                _6896 = _14161;
            }
            else
            {
                _6896 = _6891;
            }
            float4 _20633;
            if (_6896)
            {
                float _6902 = _20611.x + _20611.y;
                float _6911 = (_20611.z + _20611.w) * (1.0f - _22857);
                float _20629;
                if (_6902 > 9.9999997473787516355514526367188e-06f)
                {
                    _20629 = _20611.x / _6902;
                }
                else
                {
                    _20629 = _5641;
                }
                _20633 = float4(_20611.x + (_6911 * _20629), _20611.y + (_6911 * (1.0f - _20629)), _20611.zw * _22857);
            }
            else
            {
                _20633 = _20611;
            }
            _20632 = _20633;
        }
        else
        {
            _20632 = _20611;
        }
        float3 _6972 = (((_8645 * _20632.x) + (_8653 * _20632.y)) + (_8661 * _20632.z)) + (_8669 * _20632.w);
        float3 _22166;
        if (_5657 && (_20647 > 0.0f))
        {
            uint _14168_dummy_parameter;
            float2 _14183 = r_motion_tp1.Load(int3(int2(floor(_5416 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14168_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _20909;
            if (_7968)
            {
                float2 _14228 = clamp((((_19105 + (_14183 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14231 = tan(_14228.x);
                _20909 = (float2(_14231 / cbFI_DeviceToViewDepth.z, (tan(_14228.y) * sqrt(1.0f + (_14231 * _14231))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _20909 = _19105 + (_14183 * cbFI_Timestep);
            }
            float2 _20910;
            if (_7968)
            {
                float2 _14307 = clamp((((_19105 + (_14183 * _5631)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14310 = tan(_14307.x);
                _20910 = (float2(_14310 / cbFI_DeviceToViewDepth.z, (tan(_14307.y) * sqrt(1.0f + (_14310 * _14310))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _20910 = _19105 + (_14183 * _5631);
            }
            _22166 = lerp(_6972, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _20909, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _20910, 0.0f).xyz, cbFI_Timestep.xxx), _20647.xxx);
        }
        else
        {
            _22166 = _6972;
        }
        float3 _22165;
        if (_20917)
        {
            float3 _14352 = r_current_interpolation_source.Load(int3(_4904, 0)).xyz;
            float3 _22167;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11042)
            {
                uint _14359_dummy_parameter;
                float _21040;
                _21040 = r_depth_tm1.Load(int3(int2(floor(_19128 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14359_dummy_parameter))))), 0)).x;
                float _7053;
                for (int _21039 = 0; _21039 < 24; _21040 = _7053, _21039++)
                {
                    float _7025 = float(_21039 & 7) * 0.785398185253143310546875f;
                    int _7027 = _21039 >> 3;
                    int _22392;
                    if (_7027 == 0)
                    {
                        _22392 = 16;
                    }
                    else
                    {
                        _22392 = (_7027 == 1) ? 48 : 96;
                    }
                    uint _14379_dummy_parameter;
                    _7053 = min(_21040, r_depth_tm1.Load(int3(int2(floor(clamp(_19128 + ((cbFI_MvDepthLaneSizeRcp * float(_22392)) * float2(cos(_7025), sin(_7025))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14379_dummy_parameter))))), 0)).x);
                }
                float2 _21041;
                do
                {
                    float _14401 = 1.0f - _19128.y;
                    float4 _14412 = mul(float4((float2(_19128.x, _14401) * 2.0f) - 1.0f.xx, _21040, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14414 = _14412.w;
                    if (!(_14414 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21041 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14427 = ((_14412.xy / _14414.xx) + 1.0f.xx) * 0.5f;
                    _21041 = float2(_14427.x - _19128.x, _14401 - _14427.y);
                    break;
                } while(false);
                float2 _7064 = _19128 + _21041;
                bool _14445 = all(bool2(_7064.x > 0.0f.xx.x, _7064.y > 0.0f.xx.y));
                bool _14451;
                if (_14445)
                {
                    _14451 = all(bool2(_7064.x < 1.0f.xx.x, _7064.y < 1.0f.xx.y));
                }
                else
                {
                    _14451 = _14445;
                }
                float3 _22168;
                if (_14451)
                {
                    float _7070 = abs(cbFI_DeviceToViewDepth.y / (_21040 - cbFI_DeviceToViewDepth.x));
                    uint _14471_dummy_parameter;
                    int2 _14471 = int2(spvTextureSize(r_depth_m2, uint(0), _14471_dummy_parameter));
                    float _7074 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7064 * float2(_14471))), int2(0, 0), _14471 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _22173;
                    if (abs(_7074 - _7070) <= (0.20000000298023223876953125f * max(_7074, _7070)))
                    {
                        uint _14505_dummy_parameter;
                        int2 _14505 = int2(spvTextureSize(r_colour_m2, uint(0), _14505_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14528;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14528);
                        }
                        _22173 = r_colour_m2.Load(int3(clamp(int2(floor(_7064 * float2(_14505))), int2(0, 0), _14505 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14538;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14538);
                        }
                        _22173 = _14352;
                    }
                    _22168 = _22173;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14548;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14548);
                    }
                    _22168 = _14352;
                }
                _22167 = _22168;
            }
            else
            {
                _22167 = _14352;
            }
            _22165 = _22167;
        }
        else
        {
            _22165 = _22166;
        }
        bool _7099 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _22164;
        float _22240;
        if (_7099)
        {
            float _14734;
            float2 _7103 = float2(cbFI_DisplaySize);
            float3 _21080;
            do
            {
                bool _14795;
                float4x4 _21048;
                do
                {
                    float4x4 _14771;
                    bool _21047;
                    do
                    {
                        _14771 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14795 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14795)
                        {
                            _21047 = false;
                            break;
                        }
                        uint _14805 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14805 + 32u) * 4 + 0) != 1u)
                        {
                            _21047 = false;
                            break;
                        }
                        uint _21044;
                        _21044 = 0u;
                        for (; _21044 < 4u; _21044++)
                        {
                            for (uint _21045 = 0u; _21045 < 4u; )
                            {
                                _14771[_21044][_21045] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14805 + (_21044 * 4u)) + _21045) * 4 + 0));
                                _21045++;
                                continue;
                            }
                        }
                        _21047 = true;
                        break;
                    } while(false);
                    if (_21047)
                    {
                        _21048 = _14771;
                        break;
                    }
                    _21048 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float _14882;
                float _14885;
                float4 _14895;
                float4x4 _14602 = spvInverse(_21048);
                float2 _21049;
                do
                {
                    _14882 = _5416.x;
                    _14885 = 1.0f - _5416.y;
                    _14895 = float4((float2(_14882, _14885) * 2.0f) - 1.0f.xx, 1.0000000116860974230803549289703e-07f, 1.0f);
                    float4 _14896 = mul(_14895, _21048);
                    float _14898 = _14896.w;
                    if (!(_14898 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21049 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14911 = ((_14896.xy / _14898.xx) + 1.0f.xx) * 0.5f;
                    _21049 = float2(_14911.x - _14882, _14885 - _14911.y);
                    break;
                } while(false);
                float2 _21050;
                do
                {
                    float4 _14948 = mul(_14895, _14602);
                    float _14950 = _14948.w;
                    if (!(_14950 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21050 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14963 = ((_14948.xy / _14950.xx) + 1.0f.xx) * 0.5f;
                    _21050 = float2(_14963.x - _14882, _14885 - _14963.y);
                    break;
                } while(false);
                float2 _14610 = abs(_21049);
                bool2 _22858 = any(bool2(_14610.x > 4.0f.xx.x, _14610.y > 4.0f.xx.y)).xx;
                float2 _14616 = abs(_21050);
                bool2 _22860 = any(bool2(_14616.x > 4.0f.xx.x, _14616.y > 4.0f.xx.y)).xx;
                float2 _14977[3];
                _14977[0] = _5416;
                float2 _15097 = clamp(_5416, 0.0f.xx, 1.0f.xx);
                uint _15105_dummy_parameter;
                _14977[1] = _5416 - ((r_motion_tp1.Load(int3(int2(floor(_15097 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15105_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5641);
                _14977[2] = _5416 - (float2(_22858.x ? 0.0f.xx.x : _21049.x, _22858.y ? 0.0f.xx.y : _21049.y) * _5641);
                float _21056;
                float2 _21057;
                _21057 = _5416;
                _21056 = 1000000000.0f;
                float _22862;
                float2 _22864;
                float _22865;
                int _21055 = 0;
                float _22384 = -1.0f;
                for (; _21055 < 3; _22384 = _22862, _21057 = _22864, _21056 = _22865, _21055++)
                {
                    float2 _22374;
                    _22374 = _14977[_21055];
                    for (int _22373 = 0; _22373 < 30; )
                    {
                        uint _15619_dummy_parameter;
                        _22374 += (((_5416 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_22374, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15619_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5641)) - _22374) * 0.699999988079071044921875f);
                        _22373++;
                        continue;
                    }
                    float2 _16049 = clamp(_22374, 0.0f.xx, 1.0f.xx);
                    uint _16057_dummy_parameter;
                    bool _16487 = all(bool2(_22374.x > 0.0f.xx.x, _22374.y > 0.0f.xx.y));
                    bool _16493;
                    if (_16487)
                    {
                        _16493 = all(bool2(_22374.x < 1.0f.xx.x, _22374.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _16493 = _16487;
                    }
                    float _22376;
                    if (_16493)
                    {
                        _22376 = length(((_22374 + ((r_motion_tp1.Load(int3(int2(floor(_16049 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16057_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5641)) - _5416) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22376 = 1000000000.0f;
                    }
                    uint _16504_dummy_parameter;
                    float _16544 = log((r_depth_tp1.Load(int3(int2(floor(_16049 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16504_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15057 = _22376 < 0.3499999940395355224609375f;
                    bool _15059 = _21056 < 0.3499999940395355224609375f;
                    bool _15069;
                    if (_15057)
                    {
                        _15069 = (!_15059) || (_16544 > _22384);
                    }
                    else
                    {
                        _15069 = _15057;
                    }
                    bool _15082;
                    if (!_15069)
                    {
                        _15082 = ((!_15057) && (!_15059)) && (_22376 < _21056);
                    }
                    else
                    {
                        _15082 = _15069;
                    }
                    _22862 = _15082 ? _16544 : _22384;
                    bool2 _22863 = _15082.xx;
                    _22864 = float2(_22863.x ? _22374.x : _21057.x, _22863.y ? _22374.y : _21057.y);
                    _22865 = _15082 ? _22376 : _21056;
                }
                float2 _16546[3];
                _16546[0] = _5416;
                float2 _21076;
                do
                {
                    bool _21066;
                    do
                    {
                        bool _16793 = all(bool2(_15097.x > 0.0f.xx.x, _15097.y > 0.0f.xx.y));
                        bool _16799;
                        if (_16793)
                        {
                            _16799 = all(bool2(_15097.x < 1.0f.xx.x, _15097.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _16799 = _16793;
                        }
                        if (!_16799)
                        {
                            _21066 = false;
                            break;
                        }
                        uint _16806_dummy_parameter;
                        float4x4 _21064;
                        do
                        {
                            float4x4 _16820;
                            bool _21063;
                            do
                            {
                                _16820 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14795)
                                {
                                    _21063 = false;
                                    break;
                                }
                                uint _16854 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_16854 + 32u) * 4 + 0) != 1u)
                                {
                                    _21063 = false;
                                    break;
                                }
                                uint _21060;
                                _21060 = 0u;
                                for (; _21060 < 4u; _21060++)
                                {
                                    for (uint _21061 = 0u; _21061 < 4u; )
                                    {
                                        _16820[_21060][_21061] = asfloat(rw_nfru_diagnostics.Load<uint>(((_16854 + (_21060 * 4u)) + _21061) * 4 + 0));
                                        _21061++;
                                        continue;
                                    }
                                }
                                _21063 = true;
                                break;
                            } while(false);
                            if (_21063)
                            {
                                _21064 = _16820;
                                break;
                            }
                            _21064 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21065;
                        do
                        {
                            float _16931 = _15097.x;
                            float _16934 = 1.0f - _15097.y;
                            float4 _16945 = mul(float4((float2(_16931, _16934) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15097 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _16806_dummy_parameter))))), 0)).x, 1.0f), _21064);
                            float _16947 = _16945.w;
                            if (!(_16947 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21065 = 1000000.0f.xx;
                                break;
                            }
                            float2 _16960 = ((_16945.xy / _16947.xx) + 1.0f.xx) * 0.5f;
                            _21065 = float2(_16960.x - _16931, _16934 - _16960.y);
                            break;
                        } while(false);
                        float2 _16757 = abs(_21065);
                        if (any(bool2(_16757.x > 100000.0f.xx.x, _16757.y > 100000.0f.xx.y)))
                        {
                            _21066 = false;
                            break;
                        }
                        float _16765 = length(_21065 * _7103);
                        uint _16980_dummy_parameter;
                        bool _16779 = _16765 > ((8.0f * _7103.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _16786;
                        if (_16779)
                        {
                            _16786 = length((r_motion_tp1.Load(int3(int2(floor(_15097 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16980_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7103) < (0.20000000298023223876953125f * _16765);
                        }
                        else
                        {
                            _16786 = _16779;
                        }
                        _21066 = _16786;
                        break;
                    } while(false);
                    if (_21066)
                    {
                        uint _17011_dummy_parameter;
                        _21076 = -(r_motion_tp1.Load(int3(int2(floor(_15097 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17011_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17038_dummy_parameter;
                    float2 _21075;
                    do
                    {
                        float _17057 = _15097.x;
                        float _17060 = 1.0f - _15097.y;
                        float4 _17071 = mul(float4((float2(_17057, _17060) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15097 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17038_dummy_parameter))))), 0)).x, 1.0f), _14602);
                        float _17073 = _17071.w;
                        if (!(_17073 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21075 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17086 = ((_17071.xy / _17073.xx) + 1.0f.xx) * 0.5f;
                        _21075 = float2(_17086.x - _17057, _17060 - _17086.y);
                        break;
                    } while(false);
                    float2 _16724 = abs(_21075);
                    bool2 _16728 = any(bool2(_16724.x > 4.0f.xx.x, _16724.y > 4.0f.xx.y)).xx;
                    _21076 = float2(_16728.x ? 0.0f.xx.x : _21075.x, _16728.y ? 0.0f.xx.y : _21075.y);
                    break;
                } while(false);
                _16546[1] = _5416 - (_21076 * cbFI_Timestep);
                _16546[2] = _5416 - (float2(_22860.x ? 0.0f.xx.x : _21050.x, _22860.y ? 0.0f.xx.y : _21050.y) * cbFI_Timestep);
                float _21078;
                float2 _21079;
                _21079 = _5416;
                _21078 = 1000000000.0f;
                float _22866;
                float2 _22868;
                float _22869;
                float4x4 _17334;
                float4x4 _17772;
                int _21077 = 0;
                float _22311 = -1.0f;
                for (; _21077 < 3; _22311 = _22866, _21079 = _22868, _21078 = _22869, _21077++)
                {
                    float2 _22261;
                    _22261 = _16546[_21077];
                    float2 _17143;
                    for (int _22260 = 0; _22260 < 30; _22261 = _17143, _22260++)
                    {
                        float2 _22352;
                        do
                        {
                            float2 _17223 = clamp(_22261, 0.0f.xx, 1.0f.xx);
                            bool _22342;
                            do
                            {
                                bool _17307 = all(bool2(_17223.x > 0.0f.xx.x, _17223.y > 0.0f.xx.y));
                                bool _17313;
                                if (_17307)
                                {
                                    _17313 = all(bool2(_17223.x < 1.0f.xx.x, _17223.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17313 = _17307;
                                }
                                if (!_17313)
                                {
                                    _22342 = false;
                                    break;
                                }
                                uint _17320_dummy_parameter;
                                float4x4 _22340;
                                do
                                {
                                    bool _22339;
                                    do
                                    {
                                        _17334 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14795)
                                        {
                                            _22339 = false;
                                            break;
                                        }
                                        uint _17368 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17368 + 32u) * 4 + 0) != 1u)
                                        {
                                            _22339 = false;
                                            break;
                                        }
                                        uint _22336;
                                        _22336 = 0u;
                                        for (; _22336 < 4u; _22336++)
                                        {
                                            for (uint _22337 = 0u; _22337 < 4u; )
                                            {
                                                _17334[_22336][_22337] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17368 + (_22336 * 4u)) + _22337) * 4 + 0));
                                                _22337++;
                                                continue;
                                            }
                                        }
                                        _22339 = true;
                                        break;
                                    } while(false);
                                    if (_22339)
                                    {
                                        _22340 = _17334;
                                        break;
                                    }
                                    _22340 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _22341;
                                do
                                {
                                    float _17445 = _17223.x;
                                    float _17448 = 1.0f - _17223.y;
                                    float4 _17459 = mul(float4((float2(_17445, _17448) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17223 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17320_dummy_parameter))))), 0)).x, 1.0f), _22340);
                                    float _17461 = _17459.w;
                                    if (!(_17461 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _22341 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _17474 = ((_17459.xy / _17461.xx) + 1.0f.xx) * 0.5f;
                                    _22341 = float2(_17474.x - _17445, _17448 - _17474.y);
                                    break;
                                } while(false);
                                float2 _17271 = abs(_22341);
                                if (any(bool2(_17271.x > 100000.0f.xx.x, _17271.y > 100000.0f.xx.y)))
                                {
                                    _22342 = false;
                                    break;
                                }
                                float _17279 = length(_22341 * _7103);
                                uint _17494_dummy_parameter;
                                bool _17293 = _17279 > ((8.0f * _7103.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17300;
                                if (_17293)
                                {
                                    _17300 = length((r_motion_tp1.Load(int3(int2(floor(_17223 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17494_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7103) < (0.20000000298023223876953125f * _17279);
                                }
                                else
                                {
                                    _17300 = _17293;
                                }
                                _22342 = _17300;
                                break;
                            } while(false);
                            if (_22342)
                            {
                                uint _17525_dummy_parameter;
                                _22352 = -(r_motion_tp1.Load(int3(int2(floor(_17223 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17525_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _17552_dummy_parameter;
                            float2 _22351;
                            do
                            {
                                float _17571 = _17223.x;
                                float _17574 = 1.0f - _17223.y;
                                float4 _17585 = mul(float4((float2(_17571, _17574) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17223 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17552_dummy_parameter))))), 0)).x, 1.0f), _14602);
                                float _17587 = _17585.w;
                                if (!(_17587 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22351 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17600 = ((_17585.xy / _17587.xx) + 1.0f.xx) * 0.5f;
                                _22351 = float2(_17600.x - _17571, _17574 - _17600.y);
                                break;
                            } while(false);
                            float2 _17238 = abs(_22351);
                            bool2 _17242 = any(bool2(_17238.x > 4.0f.xx.x, _17238.y > 4.0f.xx.y)).xx;
                            _22352 = float2(_17242.x ? 0.0f.xx.x : _22351.x, _17242.y ? 0.0f.xx.y : _22351.y);
                            break;
                        } while(false);
                        _17143 = _22261 + (((_5416 - (_22352 * cbFI_Timestep)) - _22261) * 0.699999988079071044921875f);
                    }
                    float2 _17661;
                    float2 _22278;
                    do
                    {
                        _17661 = clamp(_22261, 0.0f.xx, 1.0f.xx);
                        bool _22268;
                        do
                        {
                            bool _17745 = all(bool2(_17661.x > 0.0f.xx.x, _17661.y > 0.0f.xx.y));
                            bool _17751;
                            if (_17745)
                            {
                                _17751 = all(bool2(_17661.x < 1.0f.xx.x, _17661.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _17751 = _17745;
                            }
                            if (!_17751)
                            {
                                _22268 = false;
                                break;
                            }
                            uint _17758_dummy_parameter;
                            float4x4 _22266;
                            do
                            {
                                bool _22265;
                                do
                                {
                                    _17772 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14795)
                                    {
                                        _22265 = false;
                                        break;
                                    }
                                    uint _17806 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_17806 + 32u) * 4 + 0) != 1u)
                                    {
                                        _22265 = false;
                                        break;
                                    }
                                    uint _22262;
                                    _22262 = 0u;
                                    for (; _22262 < 4u; _22262++)
                                    {
                                        for (uint _22263 = 0u; _22263 < 4u; )
                                        {
                                            _17772[_22262][_22263] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17806 + (_22262 * 4u)) + _22263) * 4 + 0));
                                            _22263++;
                                            continue;
                                        }
                                    }
                                    _22265 = true;
                                    break;
                                } while(false);
                                if (_22265)
                                {
                                    _22266 = _17772;
                                    break;
                                }
                                _22266 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _22267;
                            do
                            {
                                float _17886 = 1.0f - _17661.y;
                                float4 _17897 = mul(float4((float2(_17661.x, _17886) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17661 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17758_dummy_parameter))))), 0)).x, 1.0f), _22266);
                                float _17899 = _17897.w;
                                if (!(_17899 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _22267 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _17912 = ((_17897.xy / _17899.xx) + 1.0f.xx) * 0.5f;
                                _22267 = float2(_17912.x - _17661.x, _17886 - _17912.y);
                                break;
                            } while(false);
                            float2 _17709 = abs(_22267);
                            if (any(bool2(_17709.x > 100000.0f.xx.x, _17709.y > 100000.0f.xx.y)))
                            {
                                _22268 = false;
                                break;
                            }
                            float _17717 = length(_22267 * _7103);
                            uint _17932_dummy_parameter;
                            bool _17731 = _17717 > ((8.0f * _7103.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _17738;
                            if (_17731)
                            {
                                _17738 = length((r_motion_tp1.Load(int3(int2(floor(_17661 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17932_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7103) < (0.20000000298023223876953125f * _17717);
                            }
                            else
                            {
                                _17738 = _17731;
                            }
                            _22268 = _17738;
                            break;
                        } while(false);
                        if (_22268)
                        {
                            uint _17963_dummy_parameter;
                            _22278 = -(r_motion_tp1.Load(int3(int2(floor(_17661 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17963_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _17990_dummy_parameter;
                        float2 _22277;
                        do
                        {
                            float _18012 = 1.0f - _17661.y;
                            float4 _18023 = mul(float4((float2(_17661.x, _18012) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17661 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17990_dummy_parameter))))), 0)).x, 1.0f), _14602);
                            float _18025 = _18023.w;
                            if (!(_18025 > 9.9999999747524270787835121154785e-07f))
                            {
                                _22277 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18038 = ((_18023.xy / _18025.xx) + 1.0f.xx) * 0.5f;
                            _22277 = float2(_18038.x - _17661.x, _18012 - _18038.y);
                            break;
                        } while(false);
                        float2 _17676 = abs(_22277);
                        bool2 _17680 = any(bool2(_17676.x > 4.0f.xx.x, _17676.y > 4.0f.xx.y)).xx;
                        _22278 = float2(_17680.x ? 0.0f.xx.x : _22277.x, _17680.y ? 0.0f.xx.y : _22277.y);
                        break;
                    } while(false);
                    bool _18056 = all(bool2(_22261.x > 0.0f.xx.x, _22261.y > 0.0f.xx.y));
                    bool _18062;
                    if (_18056)
                    {
                        _18062 = all(bool2(_22261.x < 1.0f.xx.x, _22261.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18062 = _18056;
                    }
                    float _22290;
                    if (_18062)
                    {
                        _22290 = length(((_22261 + (_22278 * cbFI_Timestep)) - _5416) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _22290 = 1000000000.0f;
                    }
                    uint _18089_dummy_parameter;
                    float _18113 = log((r_depth_tm1.Load(int3(int2(floor(_17661 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18089_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _16626 = _22290 < 0.3499999940395355224609375f;
                    bool _16628 = _21078 < 0.3499999940395355224609375f;
                    bool _16638;
                    if (_16626)
                    {
                        _16638 = (!_16628) || (_18113 > _22311);
                    }
                    else
                    {
                        _16638 = _16626;
                    }
                    bool _16651;
                    if (!_16638)
                    {
                        _16651 = ((!_16626) && (!_16628)) && (_22290 < _21078);
                    }
                    else
                    {
                        _16651 = _16638;
                    }
                    _22866 = _16651 ? _18113 : _22311;
                    bool2 _22867 = _16651.xx;
                    _22868 = float2(_22867.x ? _22261.x : _21079.x, _22867.y ? _22261.y : _21079.y);
                    _22869 = _16651 ? _22290 : _21078;
                }
                float3 _18122 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21057, 0.0f).xyz;
                float3 _18130 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21079, 0.0f).xyz;
                uint _18137_dummy_parameter;
                uint _18168_dummy_parameter;
                float _14656 = exp((_21056 * (-2.0f)) * (_21056 * 2.0f));
                float _14663 = exp((_21078 * (-2.0f)) * (_21078 * 2.0f));
                float _14676 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21079, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18168_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21057, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18137_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14690 = ((_14656 * cbFI_Timestep) * ((1.0f - _14663) + ((_14663 * 2.0f) * _14676))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14700 = 1.0f - _14676;
                float _14707 = ((_14663 * _5641) * ((1.0f - _14656) + ((_14656 * 2.0f) * _14700))) + (9.9999997473787516355514526367188e-05f * _5641);
                float _14716 = (((_14656 * _14663) * 4.0f) * _14676) * _14700;
                _14734 = (_14716 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18130 - _18122, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14716)) * max(_14656, _14663));
                if (_6789 == 30u)
                {
                    _21080 = _18122;
                    break;
                }
                if (_6789 == 31u)
                {
                    _21080 = _18130;
                    break;
                }
                if (_6789 == 32u)
                {
                    _21080 = float3(_14656, _14663, _14676);
                    break;
                }
                _21080 = ((_18122 * _14690) + (_18130 * _14707)) / (_14690 + _14707).xxx;
                break;
            } while(false);
            _22240 = _14734;
            _22164 = _21080;
        }
        else
        {
            _22240 = 1.0f;
            _22164 = _22165;
        }
        uint _7119 = cbFI_pad0 & 255u;
        bool _22016;
        float3 _22163;
        if (_7119 != 0u)
        {
            float3 _7124 = r_present_backbuffer.Load(int3(_4904, 0)).xyz;
            float3 _7128 = r_current_interpolation_source.Load(int3(_4904, 0)).xyz;
            float3 _7132 = abs(_7124 - _7128);
            float3 _21081;
            if (_7119 == 2u)
            {
                _21081 = (abs(_7128) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21081 = 0.000244140625f.xxx;
            }
            bool _7148 = any(bool3(_7132.x > _21081.x, _7132.y > _21081.y, _7132.z > _21081.z));
            bool3 _22870 = _7148.xxx;
            _22163 = float3(_22870.x ? _7124.x : _22164.x, _22870.y ? _7124.y : _22164.y, _22870.z ? _7124.z : _22164.z);
            _22016 = _7148;
        }
        else
        {
            _22163 = _22164;
            _22016 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18206;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18206);
        }
        float3 _22145;
        if (_6789 == 1u)
        {
            _22145 = lerp(_8645, _8653, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _22146;
            if (_6789 == 2u)
            {
                _22146 = lerp(_8661, _8669, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _22147;
                if (_6789 == 3u)
                {
                    _22147 = float(_22016).xxx;
                }
                else
                {
                    float3 _22148;
                    if (_6789 == 4u)
                    {
                        _22148 = float3(((_19126 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _22149;
                        if (_6789 == 5u)
                        {
                            _22149 = float3(((_7940 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _22150;
                            if (_6789 == 6u)
                            {
                                _22150 = float3(_20632.xy, _20632.z + _20632.w);
                            }
                            else
                            {
                                float3 _22151;
                                if (_6789 == 7u)
                                {
                                    _22151 = r_current_interpolation_source.Load(int3(_4904, 0)).xyz;
                                }
                                else
                                {
                                    float3 _22152;
                                    if (_6789 == 8u)
                                    {
                                        _22152 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5416, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _22153;
                                        if (_6793)
                                        {
                                            uint _18228_dummy_parameter;
                                            uint _18260_dummy_parameter;
                                            _22153 = float3(log((r_depth_tp1.Load(int3(int2(floor(_5416 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18228_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_5416 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18260_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _22154;
                                            if (_6796)
                                            {
                                                _22154 = _8661;
                                            }
                                            else
                                            {
                                                float3 _22155;
                                                if (_6789 == 20u)
                                                {
                                                    _22155 = _8645;
                                                }
                                                else
                                                {
                                                    float3 _22156;
                                                    if (_6789 == 21u)
                                                    {
                                                        _22156 = _8653;
                                                    }
                                                    else
                                                    {
                                                        float3 _22157;
                                                        if (_6789 == 22u)
                                                        {
                                                            _22157 = _8669;
                                                        }
                                                        else
                                                        {
                                                            float3 _22158;
                                                            if (_6789 == 18u)
                                                            {
                                                                _22158 = _21599;
                                                            }
                                                            else
                                                            {
                                                                float3 _22159;
                                                                if (_6789 == 19u)
                                                                {
                                                                    _22159 = _21341;
                                                                }
                                                                else
                                                                {
                                                                    float3 _22160;
                                                                    if (_6789 == 23u)
                                                                    {
                                                                        _22160 = _21089;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _22161;
                                                                        if (_6789 == 24u)
                                                                        {
                                                                            uint _7292 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7297 = float(rw_nfru_diagnostics.Load<uint>((_7292 + 35u) * 4 + 0));
                                                                            float _21082;
                                                                            if (_7297 > 0.0f)
                                                                            {
                                                                                _21082 = float(rw_nfru_diagnostics.Load<uint>((_7292 + 34u) * 4 + 0)) / _7297;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21082 = 0.0f;
                                                                            }
                                                                            _22161 = float3(float(rw_nfru_diagnostics.Load<uint>((_7292 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7292 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21082);
                                                                        }
                                                                        else
                                                                        {
                                                                            _22161 = _22163;
                                                                        }
                                                                        _22160 = _22161;
                                                                    }
                                                                    _22159 = _22160;
                                                                }
                                                                _22158 = _22159;
                                                            }
                                                            _22157 = _22158;
                                                        }
                                                        _22156 = _22157;
                                                    }
                                                    _22155 = _22156;
                                                }
                                                _22154 = _22155;
                                            }
                                            _22153 = _22154;
                                        }
                                        _22152 = _22153;
                                    }
                                    _22151 = _22152;
                                }
                                _22150 = _22151;
                            }
                            _22149 = _22150;
                        }
                        _22148 = _22149;
                    }
                    _22147 = _22148;
                }
                _22146 = _22147;
            }
            _22145 = _22146;
        }
        float3 _22144;
        if ((_6789 >= 9u) && (_6789 <= 11u))
        {
            uint _7357 = 64u + uint((_19349.y * cbFI_MvDepthLaneSize.x) + _19349.x);
            uint _7361 = rw_nfru_diagnostics.Load<uint>(_7357 * 4 + 0) & 15u;
            float3 _22178;
            if (_6789 == 10u)
            {
                float3 _22143;
                if ((rw_nfru_diagnostics.Load<uint>(_7357 * 4 + 0) & 32u) != 0u)
                {
                    _22143 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _22142;
                    if ((rw_nfru_diagnostics.Load<uint>(_7357 * 4 + 0) & 16u) != 0u)
                    {
                        _22142 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7382 = ((rw_nfru_diagnostics.Load<uint>(_7357 * 4 + 0) & 64u) != 0u).xxx;
                        _22142 = float3(_7382.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7382.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7382.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _22143 = _22142;
                }
                _22178 = _22143;
            }
            else
            {
                float3 _22179;
                if (_6789 == 11u)
                {
                    uint _7395 = (rw_nfru_diagnostics.Load<uint>(_7357 * 4 + 0) >> 8u) & 15u;
                    uint _7398 = (rw_nfru_diagnostics.Load<uint>(_7357 * 4 + 0) >> 12u) & 15u;
                    float3 _22135;
                    if ((_7361 == 2u) || (_7361 == 3u))
                    {
                        _22135 = _4586[_7361];
                    }
                    else
                    {
                        bool _7410 = _7395 == 3u;
                        bool _7412 = _7398 == 3u;
                        float3 _22136;
                        if (_7410 && _7412)
                        {
                            _22136 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _22137;
                            if (_7410)
                            {
                                _22137 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _22138;
                                if (_7412)
                                {
                                    _22138 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _22139;
                                    if ((_7395 == 4u) || (_7398 == 4u))
                                    {
                                        _22139 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _22140;
                                        if ((_7395 == 1u) || (_7398 == 1u))
                                        {
                                            _22140 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _22872 = (_7361 == 1u).xxx;
                                            _22140 = float3(_22872.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _22872.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _22872.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _22139 = _22140;
                                    }
                                    _22138 = _22139;
                                }
                                _22137 = _22138;
                            }
                            _22136 = _22137;
                        }
                        _22135 = _22136;
                    }
                    _22179 = _22135;
                }
                else
                {
                    _22179 = _4586[min(_7361, 7u)];
                }
                _22178 = _22179;
            }
            _22144 = _22178;
        }
        else
        {
            _22144 = _22145;
        }
        float4 _22182;
        if ((_6789 >= 14u) && (_6789 <= 16u))
        {
            float2 _22180;
            if (_6789 == 14u)
            {
                uint _7468_dummy_parameter;
                uint _7474_dummy_parameter;
                _22180 = r_flow_tm1.Load(int3(clamp(int2(floor(_5416 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7468_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7474_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _22181;
                if (_6789 == 16u)
                {
                    uint _18336 = r_warped_flow_qdata_tm1.Load(int3(_5432, 0)).x & 2147483647u;
                    uint _18368 = uint(max((int((_18336 >> 16u) & 15u) - 6), 0));
                    _22181 = ((float2(float((1 - (2 * int((_18336 >> 15u) & 1u))) * int(((_18336 >> uint(7)) & 127u) << _18368)), float((1 - (2 * int((_18336 >> 14u) & 1u))) * int((_18336 & 127u) << _18368))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _22181 = _7940 * float2(cbFI_DisplaySize);
                }
                _22180 = _22181;
            }
            uint2 _7507 = uint2(clamp(round(_22180 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7509 = _7507.x;
            uint _7516 = _7507.y;
            _22182 = float4(float(_7509 & 255u), float((_7509 >> 8u) | ((_7516 & 15u) << 4u)), float(_7516 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _22183;
            if (_6789 == 17u)
            {
                _22183 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5432, 0)).x != 0u), _5876, 0.0f, 1.0f);
            }
            else
            {
                _22183 = float4(_22144, 1.0f);
            }
            _22182 = _22183;
        }
        rw_output[_4904] = _22182.xyz;
        if (_7099)
        {
            uint _18413 = uint((_4904.y * cbFI_DisplaySize.x) + _4904.x) * 2u;
            rw_nfru_select.Store<uint>(_18413 * 4 + 0, spvPackHalf2x16(_22182.xy));
            rw_nfru_select.Store<uint>((_18413 + 1u) * 4 + 0, spvPackHalf2x16(float2(_22182.z, (_22016 || (_6789 != 0u)) ? 2.0f : _22240)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7574 = ((uint(_4904.y) * uint(cbFI_DisplaySize.x)) + uint(_4904.x)) * 6u;
            uint _18439 = spvPackHalf2x16(clamp(_8644.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7574 * 4 + 0, (((_18439 & 32767u) >> 4u) | ((((_18439 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8644.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18474 = spvPackHalf2x16(clamp(_8652.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7574 + 1u) * 4 + 0, (((_18474 & 32767u) >> 4u) | ((((_18474 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8652.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18509 = spvPackHalf2x16(clamp(_8660.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7574 + 2u) * 4 + 0, (((_18509 & 32767u) >> 4u) | ((((_18509 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8660.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18544 = spvPackHalf2x16(clamp(_8668.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7574 + 3u) * 4 + 0, (((_18544 & 32767u) >> 4u) | ((((_18544 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8668.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _18571 = r_current_interpolation_source.Load(int3(_4904, 0));
            uint _18585 = spvPackHalf2x16(clamp(_18571.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7574 + 4u) * 4 + 0, (((_18585 & 32767u) >> 4u) | ((((_18585 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_18571.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _22259;
            if (_22016 || (_6789 != 0u))
            {
                _22259 = 4294967295u;
            }
            else
            {
                uint _18620 = spvPackHalf2x16(clamp(_22182.xy, 0.0f.xx, 65000.0f.xx));
                _22259 = (((_18620 & 32767u) >> 4u) | ((((_18620 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_22182.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7574 + 5u) * 4 + 0, _22259);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4904] = float4(r_current_interpolation_source.Load(int3(_4904, 0)).xyz, 1.0f).xyz;
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
