static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19643;

static const int2 _1243[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1252[5] = { 2, 4, 7, 11, 16 };
static const float3 _4634[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4935 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4935.x >= cbFI_DisplaySize.x, _4935.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4935] = float4(r_present_backbuffer.Load(int3(_4935, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7788 = cbFI_DisplaySize - int2(1, 1);
                int2 _7789 = clamp(_4935, int2(0, 0), _7788);
                uint _7799 = uint((_7789.y * cbFI_DisplaySize.x) + _7789.x) * 2u;
                uint _7802 = rw_nfru_select.Load<uint>(_7799 * 4 + 0);
                float2 _7803 = spvUnpackHalf2x16(_7802);
                uint _7807 = rw_nfru_select.Load<uint>((_7799 + 1u) * 4 + 0);
                float2 _7808 = spvUnpackHalf2x16(_7807);
                float _7809 = _7803.x;
                float _7811 = _7808.x;
                if (_7808.y > 1.5f)
                {
                    rw_output[_4935] = float4(_7809, _7803.y, _7811, 1.0f).xyz;
                    break;
                }
                int _23262;
                float _23263;
                float3 _23264;
                float _23265;
                float _23266;
                _23266 = 0.0f;
                _23265 = 0.0f;
                _23264 = 0.0f.xxx;
                _23263 = 0.0f;
                _23262 = -2;
                float3 _23269;
                float _23270;
                float _23271;
                float _23272;
                for (; _23262 <= 2; _23266 = _23272, _23265 = _23271, _23264 = _23269, _23263 = _23270, _23262++)
                {
                    _23272 = _23266;
                    _23271 = _23265;
                    _23270 = _23263;
                    _23269 = _23264;
                    for (int _23267 = -2; _23267 <= 2; )
                    {
                        float _7705 = float((_23267 * _23267) + (_23262 * _23262));
                        float _7710 = exp(_7705 * (-0.319999992847442626953125f));
                        int2 _7715 = int2(_23267, _23262);
                        int2 _7825 = clamp(_4935 + (_7715 * int2(2, 2)), int2(0, 0), _7788);
                        uint _7835 = uint((_7825.y * cbFI_DisplaySize.x) + _7825.x) * 2u;
                        float _7732 = exp(_7705 * (-0.5f));
                        int2 _7857 = clamp(_4935 + (_7715 * int2(6, 6)), int2(0, 0), _7788);
                        _23272 += _7732;
                        _23271 += (_7732 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7857.y * cbFI_DisplaySize.x) + _7857.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23270 += _7710;
                        _23269 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7835 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7835 + 1u) * 4 + 0)).x, _19643).xyz * _7710);
                        _23267++;
                        continue;
                    }
                }
                float3 _7762 = _23264 / _23263.xxx;
                rw_output[_4935] = float4(_7762 + ((float4(_7809, _7803.y, _7811, _7808.y).xyz - _7762) * clamp(_23265 / _23266, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5434 = (float2(_4935) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5436 = float2(cbFI_MvDepthLaneSize);
        int2 _5445 = int2(floor(_5434 * _5436));
        int2 _5450 = int2(floor(_5434 * float2(cbFI_FlowLaneSize)));
        float4 _7928 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5434 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _7934 = r_warped_filled_flow_tm1.Load(int3(_5450, 0)).xy;
        float2 _7940 = r_warped_filled_motion_tp1.Load(int3(_5445, 0)).xy;
        bool _7962 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19644;
        if (_7962)
        {
            float _7975 = ((2.0f * _5434.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19644 = float2(atan(_7975) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5434.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_7975 * _7975))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19644 = _5434;
        }
        bool _5471 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19665;
        bool _19807;
        int2 _19888;
        float3 _22380;
        if (_5471)
        {
            float _19646;
            float _19648;
            _19648 = 2.0f;
            _19646 = -1.0f;
            uint _5032[9];
            float _23273;
            float _23276;
            for (int _19645 = 0; _19645 < 9; _19648 = _23276, _19646 = _23273, _19645++)
            {
                _5032[_19645] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5445 + int2((_19645 % 3) - 1, (_19645 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_5032[_19645] != 0u)
                {
                    float _23257;
                    if (_5032[_19645] == 0u)
                    {
                        _23257 = -1.0f;
                    }
                    else
                    {
                        _23257 = float((_5032[_19645] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23276 = min(_19648, _23257);
                    _23273 = max(_19646, _23257);
                }
                else
                {
                    _23276 = _19648;
                    _23273 = _19646;
                }
            }
            float _5517 = float(_19646 >= 0.0f);
            float3 _19186 = 0.0f.xxx;
            _19186.y = _5517;
            float2 _19666;
            bool _19808;
            int2 _19889;
            float3 _22381;
            if ((_19646 - _19648) > 0.0199999995529651641845703125f)
            {
                float _19654;
                int2 _19655;
                float2 _19656;
                int2 _19658;
                float2 _19664;
                _19664 = _7940;
                _19658 = _5445;
                _19656 = _7940;
                _19655 = _5445;
                _19654 = -1.0f;
                float _23281;
                int2 _23285;
                float2 _23296;
                int2 _23307;
                float2 _23340;
                float _23465;
                int _19653 = 0;
                float _23238 = 1000000000.0f;
                for (; _19653 < 9; _23238 = _23465, _19664 = _23340, _19658 = _23307, _19656 = _23296, _19655 = _23285, _19654 = _23281, _19653++)
                {
                    if (_5032[_19653] == 0u)
                    {
                        _23465 = _23238;
                        _23340 = _19664;
                        _23307 = _19658;
                        _23296 = _19656;
                        _23285 = _19655;
                        _23281 = _19654;
                        continue;
                    }
                    int2 _5552 = clamp(_5445 + int2((_19653 % 3) - 1, (_19653 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8050 = _5032[_19653] & 2147483647u;
                    uint _8082 = uint(max((int((_8050 >> 16u) & 15u) - 6), 0));
                    float2 _5558 = (float2(float((1 - (2 * int((_8050 >> 15u) & 1u))) * int(((_8050 >> uint(7)) & 127u) << _8082)), float((1 - (2 * int((_8050 >> 14u) & 1u))) * int((_8050 & 127u) << _8082))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23224;
                    if (_5032[_19653] == 0u)
                    {
                        _23224 = -1.0f;
                    }
                    else
                    {
                        _23224 = float((_5032[_19653] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5563 = _23224 - 0.100000001490116119384765625f;
                    float2 _23225;
                    if (_7962)
                    {
                        float2 _8159 = clamp((((_19644 + (_5558 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8162 = tan(_8159.x);
                        _23225 = (float2(_8162 / cbFI_DeviceToViewDepth.z, (tan(_8159.y) * sqrt(1.0f + (_8162 * _8162))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23225 = _19644 + (_5558 * cbFI_Timestep);
                    }
                    float _5570 = cbFI_Timestep - 1.0f;
                    float2 _23226;
                    if (_7962)
                    {
                        float2 _8230 = clamp((((_19644 + (_5558 * _5570)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8233 = tan(_8230.x);
                        _23226 = (float2(_8233 / cbFI_DeviceToViewDepth.z, (tan(_8230.y) * sqrt(1.0f + (_8233 * _8233))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23226 = _19644 + (_5558 * _5570);
                    }
                    bool _8266 = all(bool2(_23225.x > 0.0f.xx.x, _23225.y > 0.0f.xx.y));
                    bool _8272;
                    if (_8266)
                    {
                        _8272 = all(bool2(_23225.x < 1.0f.xx.x, _23225.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8272 = _8266;
                    }
                    float _23229;
                    if (_8272)
                    {
                        uint _8279_dummy_parameter;
                        _23229 = max((_5563 - (log(((r_depth_tm1.Load(int3(int2(floor(_23225 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8279_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23229 = 0.0f;
                    }
                    bool _8309 = all(bool2(_23226.x > 0.0f.xx.x, _23226.y > 0.0f.xx.y));
                    bool _8315;
                    if (_8309)
                    {
                        _8315 = all(bool2(_23226.x < 1.0f.xx.x, _23226.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8315 = _8309;
                    }
                    float _23230;
                    if (_8315)
                    {
                        uint _8322_dummy_parameter;
                        _23230 = _23229 + max((_5563 - (log(((r_depth_tp1.Load(int3(int2(floor(_23226 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8322_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23230 = _23229;
                    }
                    float _23282;
                    int2 _23286;
                    float2 _23297;
                    int2 _23308;
                    float2 _23341;
                    float _23466;
                    if (_23230 == 0.0f)
                    {
                        bool _5605 = _5563 > _19654;
                        bool2 _23474 = _5605.xx;
                        _23466 = _23238;
                        _23341 = float2(_23474.x ? _5558.x : _19664.x, _23474.y ? _5558.y : _19664.y);
                        _23308 = int2(_23474.x ? _5552.x : _19658.x, _23474.y ? _5552.y : _19658.y);
                        _23297 = _19656;
                        _23286 = _19655;
                        _23282 = _5605 ? _5563 : _19654;
                    }
                    else
                    {
                        bool _5614 = _23230 < _23238;
                        bool2 _23470 = _5614.xx;
                        _23466 = _5614 ? _23230 : _23238;
                        _23341 = _19664;
                        _23308 = _19658;
                        _23297 = float2(_23470.x ? _5558.x : _19656.x, _23470.y ? _5558.y : _19656.y);
                        _23286 = int2(_23470.x ? _5552.x : _19655.x, _23470.y ? _5552.y : _19655.y);
                        _23282 = _19654;
                    }
                    _23465 = _23466;
                    _23340 = _23341;
                    _23307 = _23308;
                    _23296 = _23297;
                    _23285 = _23286;
                    _23281 = _23282;
                }
                bool _5626 = _19654 < 0.0f;
                bool2 _23480 = _5626.xx;
                int2 _23483 = int2(_23480.x ? _19655.x : _19658.x, _23480.y ? _19655.y : _19658.y);
                _22381 = float3(1.0f, _5517, float(any(bool2(_23483.x != _5445.x, _23483.y != _5445.y))));
                _19889 = _23483;
                _19808 = _5626 ? false : true;
                _19666 = float2(_23480.x ? _19656.x : _19664.x, _23480.y ? _19656.y : _19664.y);
            }
            else
            {
                _22381 = _19186;
                _19889 = _5445;
                _19808 = false;
                _19666 = _7940;
            }
            _22380 = _22381;
            _19888 = _19889;
            _19807 = _19808;
            _19665 = _19666;
        }
        else
        {
            _22380 = 0.0f.xxx;
            _19888 = _5445;
            _19807 = false;
            _19665 = _7940;
        }
        float2 _19667;
        if (_7962)
        {
            float2 _8387 = clamp((((_19644 + (_19665 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8390 = tan(_8387.x);
            _19667 = (float2(_8390 / cbFI_DeviceToViewDepth.z, (tan(_8387.y) * sqrt(1.0f + (_8390 * _8390))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19667 = _19644 + (_19665 * cbFI_Timestep);
        }
        float _5649 = cbFI_Timestep - 1.0f;
        float2 _19669;
        if (_7962)
        {
            float2 _8458 = clamp((((_19644 + (_19665 * _5649)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8461 = tan(_8458.x);
            _19669 = (float2(_8461 / cbFI_DeviceToViewDepth.z, (tan(_8458.y) * sqrt(1.0f + (_8461 * _8461))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19669 = _19644 + (_19665 * _5649);
        }
        float _5654 = -cbFI_Timestep;
        float2 _19670;
        if (_7962)
        {
            float2 _8529 = clamp((((_19644 + (_7934 * _5654)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8532 = tan(_8529.x);
            _19670 = (float2(_8532 / cbFI_DeviceToViewDepth.z, (tan(_8529.y) * sqrt(1.0f + (_8532 * _8532))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19670 = _19644 + (_7934 * _5654);
        }
        float _5659 = 1.0f - cbFI_Timestep;
        float2 _19671;
        if (_7962)
        {
            float2 _8600 = clamp((((_19644 + (_7934 * _5659)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8603 = tan(_8600.x);
            _19671 = (float2(_8603 / cbFI_DeviceToViewDepth.z, (tan(_8600.y) * sqrt(1.0f + (_8603 * _8603))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19671 = _19644 + (_7934 * _5659);
        }
        float4 _8638 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19667, 0.0f);
        float3 _8639 = _8638.xyz;
        float4 _8646 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19669, 0.0f);
        float3 _8647 = _8646.xyz;
        float4 _8654 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19670, 0.0f);
        float3 _8655 = _8654.xyz;
        float4 _8662 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19671, 0.0f);
        float3 _8663 = _8662.xyz;
        float4 _8677 = exp(_7928 - max(max(max(_7928.x, _7928.y), _7928.z), _7928.w).xxxx);
        float4 _8684 = _8677 / (dot(_8677, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5675 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19878;
        float _21186;
        if (_5675)
        {
            float2 _5681 = 0.5f.xx / _5436;
            float _5684 = _5681.x;
            float _5685 = -_5684;
            float _5687 = _5681.y;
            float _5688 = -_5687;
            float2 _5690 = _5434 + float2(_5685, _5688);
            float2 _5692 = float2(cbFI_DisplaySize);
            bool _19688;
            do
            {
                bool _8764 = all(bool2(_5690.x > 0.0f.xx.x, _5690.y > 0.0f.xx.y));
                bool _8770;
                if (_8764)
                {
                    _8770 = all(bool2(_5690.x < 1.0f.xx.x, _5690.y < 1.0f.xx.y));
                }
                else
                {
                    _8770 = _8764;
                }
                if (!_8770)
                {
                    _19688 = false;
                    break;
                }
                uint _8777_dummy_parameter;
                float4x4 _19686;
                do
                {
                    float4x4 _8791;
                    bool _19685;
                    do
                    {
                        _8791 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19685 = false;
                            break;
                        }
                        uint _8825 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8825 + 32u) * 4 + 0) != 1u)
                        {
                            _19685 = false;
                            break;
                        }
                        uint _19682;
                        _19682 = 0u;
                        for (; _19682 < 4u; _19682++)
                        {
                            for (uint _19683 = 0u; _19683 < 4u; )
                            {
                                _8791[_19682][_19683] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8825 + (_19682 * 4u)) + _19683) * 4 + 0));
                                _19683++;
                                continue;
                            }
                        }
                        _19685 = true;
                        break;
                    } while(false);
                    if (_19685)
                    {
                        _19686 = _8791;
                        break;
                    }
                    _19686 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19687;
                do
                {
                    float _8902 = _5690.x;
                    float _8905 = 1.0f - _5690.y;
                    float4 _8916 = mul(float4((float2(_8902, _8905) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5690 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8777_dummy_parameter))))), 0)).x, 1.0f), _19686);
                    float _8918 = _8916.w;
                    if (!(_8918 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19687 = 1000000.0f.xx;
                        break;
                    }
                    float2 _8931 = ((_8916.xy / _8918.xx) + 1.0f.xx) * 0.5f;
                    _19687 = float2(_8931.x - _8902, _8905 - _8931.y);
                    break;
                } while(false);
                float2 _8728 = abs(_19687);
                if (any(bool2(_8728.x > 100000.0f.xx.x, _8728.y > 100000.0f.xx.y)))
                {
                    _19688 = false;
                    break;
                }
                float _8736 = length(_19687 * _5692);
                uint _8951_dummy_parameter;
                bool _8750 = _8736 > ((8.0f * _5692.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8757;
                if (_8750)
                {
                    _8757 = length((r_motion_tp1.Load(int3(int2(floor(_5690 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _8951_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5692) < (0.20000000298023223876953125f * _8736);
                }
                else
                {
                    _8757 = _8750;
                }
                _19688 = _8757;
                break;
            } while(false);
            float2 _5702 = _5434 + float2(_5684, _5688);
            bool _19695;
            do
            {
                bool _9037 = all(bool2(_5702.x > 0.0f.xx.x, _5702.y > 0.0f.xx.y));
                bool _9043;
                if (_9037)
                {
                    _9043 = all(bool2(_5702.x < 1.0f.xx.x, _5702.y < 1.0f.xx.y));
                }
                else
                {
                    _9043 = _9037;
                }
                if (!_9043)
                {
                    _19695 = false;
                    break;
                }
                uint _9050_dummy_parameter;
                float4x4 _19693;
                do
                {
                    float4x4 _9064;
                    bool _19692;
                    do
                    {
                        _9064 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19692 = false;
                            break;
                        }
                        uint _9098 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9098 + 32u) * 4 + 0) != 1u)
                        {
                            _19692 = false;
                            break;
                        }
                        uint _19689;
                        _19689 = 0u;
                        for (; _19689 < 4u; _19689++)
                        {
                            for (uint _19690 = 0u; _19690 < 4u; )
                            {
                                _9064[_19689][_19690] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9098 + (_19689 * 4u)) + _19690) * 4 + 0));
                                _19690++;
                                continue;
                            }
                        }
                        _19692 = true;
                        break;
                    } while(false);
                    if (_19692)
                    {
                        _19693 = _9064;
                        break;
                    }
                    _19693 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19694;
                do
                {
                    float _9175 = _5702.x;
                    float _9178 = 1.0f - _5702.y;
                    float4 _9189 = mul(float4((float2(_9175, _9178) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5702 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9050_dummy_parameter))))), 0)).x, 1.0f), _19693);
                    float _9191 = _9189.w;
                    if (!(_9191 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19694 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9204 = ((_9189.xy / _9191.xx) + 1.0f.xx) * 0.5f;
                    _19694 = float2(_9204.x - _9175, _9178 - _9204.y);
                    break;
                } while(false);
                float2 _9001 = abs(_19694);
                if (any(bool2(_9001.x > 100000.0f.xx.x, _9001.y > 100000.0f.xx.y)))
                {
                    _19695 = false;
                    break;
                }
                float _9009 = length(_19694 * _5692);
                uint _9224_dummy_parameter;
                bool _9023 = _9009 > ((8.0f * _5692.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9030;
                if (_9023)
                {
                    _9030 = length((r_motion_tp1.Load(int3(int2(floor(_5702 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9224_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5692) < (0.20000000298023223876953125f * _9009);
                }
                else
                {
                    _9030 = _9023;
                }
                _19695 = _9030;
                break;
            } while(false);
            float2 _5715 = _5434 + float2(_5685, _5687);
            bool _19702;
            do
            {
                bool _9310 = all(bool2(_5715.x > 0.0f.xx.x, _5715.y > 0.0f.xx.y));
                bool _9316;
                if (_9310)
                {
                    _9316 = all(bool2(_5715.x < 1.0f.xx.x, _5715.y < 1.0f.xx.y));
                }
                else
                {
                    _9316 = _9310;
                }
                if (!_9316)
                {
                    _19702 = false;
                    break;
                }
                uint _9323_dummy_parameter;
                float4x4 _19700;
                do
                {
                    float4x4 _9337;
                    bool _19699;
                    do
                    {
                        _9337 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19699 = false;
                            break;
                        }
                        uint _9371 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9371 + 32u) * 4 + 0) != 1u)
                        {
                            _19699 = false;
                            break;
                        }
                        uint _19696;
                        _19696 = 0u;
                        for (; _19696 < 4u; _19696++)
                        {
                            for (uint _19697 = 0u; _19697 < 4u; )
                            {
                                _9337[_19696][_19697] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9371 + (_19696 * 4u)) + _19697) * 4 + 0));
                                _19697++;
                                continue;
                            }
                        }
                        _19699 = true;
                        break;
                    } while(false);
                    if (_19699)
                    {
                        _19700 = _9337;
                        break;
                    }
                    _19700 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19701;
                do
                {
                    float _9448 = _5715.x;
                    float _9451 = 1.0f - _5715.y;
                    float4 _9462 = mul(float4((float2(_9448, _9451) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5715 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9323_dummy_parameter))))), 0)).x, 1.0f), _19700);
                    float _9464 = _9462.w;
                    if (!(_9464 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19701 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9477 = ((_9462.xy / _9464.xx) + 1.0f.xx) * 0.5f;
                    _19701 = float2(_9477.x - _9448, _9451 - _9477.y);
                    break;
                } while(false);
                float2 _9274 = abs(_19701);
                if (any(bool2(_9274.x > 100000.0f.xx.x, _9274.y > 100000.0f.xx.y)))
                {
                    _19702 = false;
                    break;
                }
                float _9282 = length(_19701 * _5692);
                uint _9497_dummy_parameter;
                bool _9296 = _9282 > ((8.0f * _5692.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9303;
                if (_9296)
                {
                    _9303 = length((r_motion_tp1.Load(int3(int2(floor(_5715 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9497_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5692) < (0.20000000298023223876953125f * _9282);
                }
                else
                {
                    _9303 = _9296;
                }
                _19702 = _9303;
                break;
            } while(false);
            float2 _5727 = _5434 + _5681;
            bool _19709;
            do
            {
                bool _9583 = all(bool2(_5727.x > 0.0f.xx.x, _5727.y > 0.0f.xx.y));
                bool _9589;
                if (_9583)
                {
                    _9589 = all(bool2(_5727.x < 1.0f.xx.x, _5727.y < 1.0f.xx.y));
                }
                else
                {
                    _9589 = _9583;
                }
                if (!_9589)
                {
                    _19709 = false;
                    break;
                }
                uint _9596_dummy_parameter;
                float4x4 _19707;
                do
                {
                    float4x4 _9610;
                    bool _19706;
                    do
                    {
                        _9610 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19706 = false;
                            break;
                        }
                        uint _9644 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9644 + 32u) * 4 + 0) != 1u)
                        {
                            _19706 = false;
                            break;
                        }
                        uint _19703;
                        _19703 = 0u;
                        for (; _19703 < 4u; _19703++)
                        {
                            for (uint _19704 = 0u; _19704 < 4u; )
                            {
                                _9610[_19703][_19704] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9644 + (_19703 * 4u)) + _19704) * 4 + 0));
                                _19704++;
                                continue;
                            }
                        }
                        _19706 = true;
                        break;
                    } while(false);
                    if (_19706)
                    {
                        _19707 = _9610;
                        break;
                    }
                    _19707 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19708;
                do
                {
                    float _9721 = _5727.x;
                    float _9724 = 1.0f - _5727.y;
                    float4 _9735 = mul(float4((float2(_9721, _9724) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5727 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9596_dummy_parameter))))), 0)).x, 1.0f), _19707);
                    float _9737 = _9735.w;
                    if (!(_9737 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19708 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9750 = ((_9735.xy / _9737.xx) + 1.0f.xx) * 0.5f;
                    _19708 = float2(_9750.x - _9721, _9724 - _9750.y);
                    break;
                } while(false);
                float2 _9547 = abs(_19708);
                if (any(bool2(_9547.x > 100000.0f.xx.x, _9547.y > 100000.0f.xx.y)))
                {
                    _19709 = false;
                    break;
                }
                float _9555 = length(_19708 * _5692);
                uint _9770_dummy_parameter;
                bool _9569 = _9555 > ((8.0f * _5692.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9576;
                if (_9569)
                {
                    _9576 = length((r_motion_tp1.Load(int3(int2(floor(_5727 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9770_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5692) < (0.20000000298023223876953125f * _9555);
                }
                else
                {
                    _9576 = _9569;
                }
                _19709 = _9576;
                break;
            } while(false);
            float _5733 = 0.25f * (((float(_19688) + float(_19695)) + float(_19702)) + float(_19709));
            float4 _19879;
            if (_5733 < 1.0f)
            {
                bool _19716;
                do
                {
                    bool _9856 = all(bool2(_19667.x > 0.0f.xx.x, _19667.y > 0.0f.xx.y));
                    bool _9862;
                    if (_9856)
                    {
                        _9862 = all(bool2(_19667.x < 1.0f.xx.x, _19667.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9862 = _9856;
                    }
                    if (!_9862)
                    {
                        _19716 = false;
                        break;
                    }
                    uint _9869_dummy_parameter;
                    float4x4 _19714;
                    do
                    {
                        float4x4 _9883;
                        bool _19713;
                        do
                        {
                            _9883 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19713 = false;
                                break;
                            }
                            uint _9917 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9917 + 32u) * 4 + 0) != 1u)
                            {
                                _19713 = false;
                                break;
                            }
                            uint _19710;
                            _19710 = 0u;
                            for (; _19710 < 4u; _19710++)
                            {
                                for (uint _19711 = 0u; _19711 < 4u; )
                                {
                                    _9883[_19710][_19711] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9917 + (_19710 * 4u)) + _19711) * 4 + 0));
                                    _19711++;
                                    continue;
                                }
                            }
                            _19713 = true;
                            break;
                        } while(false);
                        if (_19713)
                        {
                            _19714 = _9883;
                            break;
                        }
                        _19714 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19715;
                    do
                    {
                        float _9997 = 1.0f - _19667.y;
                        float4 _10008 = mul(float4((float2(_19667.x, _9997) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19667 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9869_dummy_parameter))))), 0)).x, 1.0f), _19714);
                        float _10010 = _10008.w;
                        if (!(_10010 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19715 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10023 = ((_10008.xy / _10010.xx) + 1.0f.xx) * 0.5f;
                        _19715 = float2(_10023.x - _19667.x, _9997 - _10023.y);
                        break;
                    } while(false);
                    float2 _9820 = abs(_19715);
                    if (any(bool2(_9820.x > 100000.0f.xx.x, _9820.y > 100000.0f.xx.y)))
                    {
                        _19716 = false;
                        break;
                    }
                    float _9828 = length(_19715 * _5692);
                    uint _10043_dummy_parameter;
                    bool _9842 = _9828 > ((8.0f * _5692.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9849;
                    if (_9842)
                    {
                        _9849 = length((r_motion_tp1.Load(int3(int2(floor(_19667 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10043_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5692) < (0.20000000298023223876953125f * _9828);
                    }
                    else
                    {
                        _9849 = _9842;
                    }
                    _19716 = _9849;
                    break;
                } while(false);
                bool _19723;
                do
                {
                    bool _10129 = all(bool2(_19669.x > 0.0f.xx.x, _19669.y > 0.0f.xx.y));
                    bool _10135;
                    if (_10129)
                    {
                        _10135 = all(bool2(_19669.x < 1.0f.xx.x, _19669.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10135 = _10129;
                    }
                    if (!_10135)
                    {
                        _19723 = false;
                        break;
                    }
                    uint _10142_dummy_parameter;
                    float4x4 _19721;
                    do
                    {
                        float4x4 _10156;
                        bool _19720;
                        do
                        {
                            _10156 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19720 = false;
                                break;
                            }
                            uint _10190 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10190 + 32u) * 4 + 0) != 1u)
                            {
                                _19720 = false;
                                break;
                            }
                            uint _19717;
                            _19717 = 0u;
                            for (; _19717 < 4u; _19717++)
                            {
                                for (uint _19718 = 0u; _19718 < 4u; )
                                {
                                    _10156[_19717][_19718] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10190 + (_19717 * 4u)) + _19718) * 4 + 0));
                                    _19718++;
                                    continue;
                                }
                            }
                            _19720 = true;
                            break;
                        } while(false);
                        if (_19720)
                        {
                            _19721 = _10156;
                            break;
                        }
                        _19721 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19722;
                    do
                    {
                        float _10270 = 1.0f - _19669.y;
                        float4 _10281 = mul(float4((float2(_19669.x, _10270) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19669 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10142_dummy_parameter))))), 0)).x, 1.0f), _19721);
                        float _10283 = _10281.w;
                        if (!(_10283 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19722 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10296 = ((_10281.xy / _10283.xx) + 1.0f.xx) * 0.5f;
                        _19722 = float2(_10296.x - _19669.x, _10270 - _10296.y);
                        break;
                    } while(false);
                    float2 _10093 = abs(_19722);
                    if (any(bool2(_10093.x > 100000.0f.xx.x, _10093.y > 100000.0f.xx.y)))
                    {
                        _19723 = false;
                        break;
                    }
                    float _10101 = length(_19722 * _5692);
                    uint _10316_dummy_parameter;
                    bool _10115 = _10101 > ((8.0f * _5692.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10122;
                    if (_10115)
                    {
                        _10122 = length((r_motion_tp1.Load(int3(int2(floor(_19669 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10316_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5692) < (0.20000000298023223876953125f * _10101);
                    }
                    else
                    {
                        _10122 = _10115;
                    }
                    _19723 = _10122;
                    break;
                } while(false);
                bool _19730;
                do
                {
                    bool _10402 = all(bool2(_19670.x > 0.0f.xx.x, _19670.y > 0.0f.xx.y));
                    bool _10408;
                    if (_10402)
                    {
                        _10408 = all(bool2(_19670.x < 1.0f.xx.x, _19670.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10408 = _10402;
                    }
                    if (!_10408)
                    {
                        _19730 = false;
                        break;
                    }
                    uint _10415_dummy_parameter;
                    float4x4 _19728;
                    do
                    {
                        float4x4 _10429;
                        bool _19727;
                        do
                        {
                            _10429 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19727 = false;
                                break;
                            }
                            uint _10463 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10463 + 32u) * 4 + 0) != 1u)
                            {
                                _19727 = false;
                                break;
                            }
                            uint _19724;
                            _19724 = 0u;
                            for (; _19724 < 4u; _19724++)
                            {
                                for (uint _19725 = 0u; _19725 < 4u; )
                                {
                                    _10429[_19724][_19725] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10463 + (_19724 * 4u)) + _19725) * 4 + 0));
                                    _19725++;
                                    continue;
                                }
                            }
                            _19727 = true;
                            break;
                        } while(false);
                        if (_19727)
                        {
                            _19728 = _10429;
                            break;
                        }
                        _19728 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19729;
                    do
                    {
                        float _10543 = 1.0f - _19670.y;
                        float4 _10554 = mul(float4((float2(_19670.x, _10543) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19670 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10415_dummy_parameter))))), 0)).x, 1.0f), _19728);
                        float _10556 = _10554.w;
                        if (!(_10556 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19729 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10569 = ((_10554.xy / _10556.xx) + 1.0f.xx) * 0.5f;
                        _19729 = float2(_10569.x - _19670.x, _10543 - _10569.y);
                        break;
                    } while(false);
                    float2 _10366 = abs(_19729);
                    if (any(bool2(_10366.x > 100000.0f.xx.x, _10366.y > 100000.0f.xx.y)))
                    {
                        _19730 = false;
                        break;
                    }
                    float _10374 = length(_19729 * _5692);
                    uint _10589_dummy_parameter;
                    bool _10388 = _10374 > ((8.0f * _5692.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10395;
                    if (_10388)
                    {
                        _10395 = length((r_motion_tp1.Load(int3(int2(floor(_19670 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10589_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5692) < (0.20000000298023223876953125f * _10374);
                    }
                    else
                    {
                        _10395 = _10388;
                    }
                    _19730 = _10395;
                    break;
                } while(false);
                bool _19737;
                do
                {
                    bool _10675 = all(bool2(_19671.x > 0.0f.xx.x, _19671.y > 0.0f.xx.y));
                    bool _10681;
                    if (_10675)
                    {
                        _10681 = all(bool2(_19671.x < 1.0f.xx.x, _19671.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10681 = _10675;
                    }
                    if (!_10681)
                    {
                        _19737 = false;
                        break;
                    }
                    uint _10688_dummy_parameter;
                    float4x4 _19735;
                    do
                    {
                        float4x4 _10702;
                        bool _19734;
                        do
                        {
                            _10702 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19734 = false;
                                break;
                            }
                            uint _10736 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10736 + 32u) * 4 + 0) != 1u)
                            {
                                _19734 = false;
                                break;
                            }
                            uint _19731;
                            _19731 = 0u;
                            for (; _19731 < 4u; _19731++)
                            {
                                for (uint _19732 = 0u; _19732 < 4u; )
                                {
                                    _10702[_19731][_19732] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10736 + (_19731 * 4u)) + _19732) * 4 + 0));
                                    _19732++;
                                    continue;
                                }
                            }
                            _19734 = true;
                            break;
                        } while(false);
                        if (_19734)
                        {
                            _19735 = _10702;
                            break;
                        }
                        _19735 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19736;
                    do
                    {
                        float _10816 = 1.0f - _19671.y;
                        float4 _10827 = mul(float4((float2(_19671.x, _10816) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19671 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10688_dummy_parameter))))), 0)).x, 1.0f), _19735);
                        float _10829 = _10827.w;
                        if (!(_10829 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19736 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10842 = ((_10827.xy / _10829.xx) + 1.0f.xx) * 0.5f;
                        _19736 = float2(_10842.x - _19671.x, _10816 - _10842.y);
                        break;
                    } while(false);
                    float2 _10639 = abs(_19736);
                    if (any(bool2(_10639.x > 100000.0f.xx.x, _10639.y > 100000.0f.xx.y)))
                    {
                        _19737 = false;
                        break;
                    }
                    float _10647 = length(_19736 * _5692);
                    uint _10862_dummy_parameter;
                    bool _10661 = _10647 > ((8.0f * _5692.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10668;
                    if (_10661)
                    {
                        _10668 = length((r_motion_tp1.Load(int3(int2(floor(_19671 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10862_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5692) < (0.20000000298023223876953125f * _10647);
                    }
                    else
                    {
                        _10668 = _10661;
                    }
                    _19737 = _10668;
                    break;
                } while(false);
                float4 _5760 = _8684 * float4(_19716 ? 0.0f : 1.0f, _19723 ? 0.0f : 1.0f, _19730 ? 0.0f : 1.0f, _19737 ? 0.0f : 1.0f);
                float _5762 = dot(_5760, 1.0f.xxxx);
                float4 _19880;
                if (_5762 > 0.001000000047497451305389404296875f)
                {
                    _19880 = _5760 / _5762.xxxx;
                }
                else
                {
                    _19880 = _8684;
                }
                _19879 = _19880;
            }
            else
            {
                _19879 = _8684;
            }
            _21186 = _5733;
            _19878 = _19879;
        }
        else
        {
            _21186 = 0.0f;
            _19878 = _8684;
        }
        bool _5779 = _5471 && (!_19807);
        bool _5788;
        if (_5779)
        {
            _5788 = (_19878.z + _19878.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5788 = _5779;
        }
        bool _5799;
        if (_5788)
        {
            _5799 = length((_19670 - _19667) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5799 = _5788;
        }
        bool _19967;
        if (_5799)
        {
            uint4 _10891 = r_warped_motion_qdata_tp1.Load(int3(_19888, 0));
            uint _10892 = _10891.x;
            bool _19970;
            if (_10892 != 0u)
            {
                float _19956;
                if (_10892 == 0u)
                {
                    _19956 = -1.0f;
                }
                else
                {
                    _19956 = float((_10892 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5809 = _19956 - 0.12000000476837158203125f;
                bool _10911 = all(bool2(_19670.x > 0.0f.xx.x, _19670.y > 0.0f.xx.y));
                bool _10917;
                if (_10911)
                {
                    _10917 = all(bool2(_19670.x < 1.0f.xx.x, _19670.y < 1.0f.xx.y));
                }
                else
                {
                    _10917 = _10911;
                }
                bool _5819;
                if (_10917)
                {
                    uint _10924_dummy_parameter;
                    _5819 = (log(((r_depth_tm1.Load(int3(int2(floor(_19670 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10924_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5809;
                }
                else
                {
                    _5819 = _10917;
                }
                bool _5833;
                if (!_5819)
                {
                    bool _10954 = all(bool2(_19671.x > 0.0f.xx.x, _19671.y > 0.0f.xx.y));
                    bool _10960;
                    if (_10954)
                    {
                        _10960 = all(bool2(_19671.x < 1.0f.xx.x, _19671.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10960 = _10954;
                    }
                    bool _5831;
                    if (_10960)
                    {
                        uint _10967_dummy_parameter;
                        _5831 = (log(((r_depth_tp1.Load(int3(int2(floor(_19671 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10967_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f) < _5809;
                    }
                    else
                    {
                        _5831 = _10960;
                    }
                    _5833 = _5831;
                }
                else
                {
                    _5833 = _5819;
                }
                _19970 = _5833;
            }
            else
            {
                _19970 = false;
            }
            _19967 = _19970;
        }
        else
        {
            _19967 = false;
        }
        bool _5838 = _19807 || _19967;
        bool _5843;
        if (_5838)
        {
            bool _10997 = all(bool2(_19667.x > 0.0f.xx.x, _19667.y > 0.0f.xx.y));
            bool _11003;
            if (_10997)
            {
                _11003 = all(bool2(_19667.x < 1.0f.xx.x, _19667.y < 1.0f.xx.y));
            }
            else
            {
                _11003 = _10997;
            }
            _5843 = _11003;
        }
        else
        {
            _5843 = _5838;
        }
        bool _5848;
        if (_5843)
        {
            bool _11008 = all(bool2(_19669.x > 0.0f.xx.x, _19669.y > 0.0f.xx.y));
            bool _11014;
            if (_11008)
            {
                _11014 = all(bool2(_19669.x < 1.0f.xx.x, _19669.y < 1.0f.xx.y));
            }
            else
            {
                _11014 = _11008;
            }
            _5848 = _11014;
        }
        else
        {
            _5848 = _5843;
        }
        float4 _20090;
        if (_5848)
        {
            float _5854 = _19878.x + _19878.y;
            float _5859 = _19878.z + _19878.w;
            float _19985;
            if (_5854 > 0.001000000047497451305389404296875f)
            {
                _19985 = _19878.x / _5854;
            }
            else
            {
                _19985 = _5659;
            }
            _20090 = float4(_19878.x + (_5859 * _19985), _19878.y + (_5859 * (1.0f - _19985)), 0.0f, 0.0f);
        }
        else
        {
            _20090 = _19878;
        }
        bool _11042 = (cbFI_pad0 & 1024u) != 0u;
        bool _11018 = !_11042;
        bool _11019 = !_11018;
        bool _11036;
        if (_11019)
        {
            _11036 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19888.y * cbFI_MvDepthLaneSize.x) + _19888.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11036 = _11018;
        }
        bool _11068;
        if (_11019)
        {
            _11068 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5450.y * cbFI_FlowLaneSize.x) + _5450.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11068 = _11018;
        }
        float _5894 = float(_11068);
        bool _20111;
        float4 _20150;
        float3 _22077;
        if (_11042)
        {
            bool _5904;
            if (_11036)
            {
                _5904 = all(bool2(_19667.x > 0.0f.xx.x, _19667.y > 0.0f.xx.y));
            }
            else
            {
                _5904 = _11036;
            }
            bool _5910;
            if (_5904)
            {
                _5910 = all(bool2(_19667.x < 1.0f.xx.x, _19667.y < 1.0f.xx.y));
            }
            else
            {
                _5910 = _5904;
            }
            bool _5917;
            if (_11036)
            {
                _5917 = all(bool2(_19669.x > 0.0f.xx.x, _19669.y > 0.0f.xx.y));
            }
            else
            {
                _5917 = _11036;
            }
            bool _5923;
            if (_5917)
            {
                _5923 = all(bool2(_19669.x < 1.0f.xx.x, _19669.y < 1.0f.xx.y));
            }
            else
            {
                _5923 = _5917;
            }
            bool _5930;
            if (_11068)
            {
                _5930 = all(bool2(_19670.x > 0.0f.xx.x, _19670.y > 0.0f.xx.y));
            }
            else
            {
                _5930 = _11068;
            }
            bool _5936;
            if (_5930)
            {
                _5936 = all(bool2(_19670.x < 1.0f.xx.x, _19670.y < 1.0f.xx.y));
            }
            else
            {
                _5936 = _5930;
            }
            bool _5943;
            if (_11068)
            {
                _5943 = all(bool2(_19671.x > 0.0f.xx.x, _19671.y > 0.0f.xx.y));
            }
            else
            {
                _5943 = _11068;
            }
            bool _5949;
            if (_5943)
            {
                _5949 = all(bool2(_19671.x < 1.0f.xx.x, _19671.y < 1.0f.xx.y));
            }
            else
            {
                _5949 = _5943;
            }
            bool _5951 = !_11036;
            if (_5951)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11110;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11110);
                }
            }
            bool _5956 = !_11068;
            if (_5956)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11120;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11120);
                }
            }
            if (_11036 && _5956)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11130;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11130);
                }
            }
            if (_5951 && _11068)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11140;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11140);
                }
            }
            float _5975 = float(_5910);
            float _5977 = float(_5923);
            bool _5980 = _5936 && _5949;
            float _20019;
            if (_5980)
            {
                _20019 = 1.0f;
            }
            else
            {
                _20019 = (_5936 || _5949) ? 0.5f : 0.0f;
            }
            bool _20034;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5910)) && (!_5923))
            {
                bool _6010;
                if (_5980)
                {
                    float _20027;
                    do
                    {
                        bool _11224 = all(bool2(_19670.x > 0.0f.xx.x, _19670.y > 0.0f.xx.y));
                        bool _11230;
                        if (_11224)
                        {
                            _11230 = all(bool2(_19670.x < 1.0f.xx.x, _19670.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11230 = _11224;
                        }
                        bool _11161 = !_11230;
                        bool _11168;
                        if (!_11161)
                        {
                            bool _11235 = all(bool2(_19671.x > 0.0f.xx.x, _19671.y > 0.0f.xx.y));
                            bool _11241;
                            if (_11235)
                            {
                                _11241 = all(bool2(_19671.x < 1.0f.xx.x, _19671.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11241 = _11235;
                            }
                            _11168 = !_11241;
                        }
                        else
                        {
                            _11168 = _11161;
                        }
                        if (_11168)
                        {
                            _20027 = 0.0f;
                            break;
                        }
                        uint _11248_dummy_parameter;
                        uint _11264_dummy_parameter;
                        float4x4 _20026;
                        do
                        {
                            float4x4 _11278;
                            bool _20025;
                            do
                            {
                                _11278 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20025 = false;
                                    break;
                                }
                                uint _11312 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11312 + 32u) * 4 + 0) != 1u)
                                {
                                    _20025 = false;
                                    break;
                                }
                                uint _20022;
                                _20022 = 0u;
                                for (; _20022 < 4u; _20022++)
                                {
                                    for (uint _20023 = 0u; _20023 < 4u; )
                                    {
                                        _11278[_20022][_20023] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11312 + 16u) + (_20022 * 4u)) + _20023) * 4 + 0));
                                        _20023++;
                                        continue;
                                    }
                                }
                                _20025 = true;
                                break;
                            } while(false);
                            if (_20025)
                            {
                                _20026 = _11278;
                                break;
                            }
                            _20026 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11189 = mul(float4((float2(_19670.x, 1.0f - _19670.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19670 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11248_dummy_parameter))))), 0)).x, 1.0f), _20026);
                        float _11191 = _11189.w;
                        if (abs(_11191) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20027 = 0.0f;
                            break;
                        }
                        float _11202 = abs(cbFI_DeviceToViewDepth.y / ((_11189.z / _11191) - cbFI_DeviceToViewDepth.x));
                        float _11205 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19671 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11264_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20027 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11202 - _11205) / max(max(_11202, _11205), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _6010 = _20027 >= 0.5f;
                }
                else
                {
                    _6010 = _5980;
                }
                bool _6018;
                if (_6010)
                {
                    _6018 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _6018 = _6010;
                }
                bool _20035;
                if (_6018)
                {
                    uint _11416_dummy_parameter;
                    float4x4 _20032;
                    do
                    {
                        float4x4 _11430;
                        bool _20031;
                        do
                        {
                            _11430 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20031 = false;
                                break;
                            }
                            uint _11464 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11464 + 32u) * 4 + 0) != 1u)
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
                                    _11430[_20028][_20029] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11464 + 16u) + (_20028 * 4u)) + _20029) * 4 + 0));
                                    _20029++;
                                    continue;
                                }
                            }
                            _20031 = true;
                            break;
                        } while(false);
                        if (_20031)
                        {
                            _20032 = _11430;
                            break;
                        }
                        _20032 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20033;
                    do
                    {
                        float _11544 = 1.0f - _19670.y;
                        float4 _11555 = mul(float4((float2(_19670.x, _11544) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19670 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11416_dummy_parameter))))), 0)).x, 1.0f), _20032);
                        float _11557 = _11555.w;
                        if (!(_11557 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20033 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11570 = ((_11555.xy / _11557.xx) + 1.0f.xx) * 0.5f;
                        _20033 = float2(_11570.x - _19670.x, _11544 - _11570.y);
                        break;
                    } while(false);
                    float2 _6031 = float2(cbFI_DisplaySize);
                    _20035 = length(((_19670 + _20033) - _19671) * _6031) <= ((0.100000001490116119384765625f * length(_20033 * _6031)) + 8.0f);
                }
                else
                {
                    _20035 = _6010;
                }
                _20034 = _20035;
            }
            else
            {
                _20034 = true;
            }
            bool _6045 = !_20034;
            bool _23484 = _6045 ? false : _5949;
            bool _23485 = _6045 ? false : _5936;
            bool _20112;
            float4 _20151;
            if (!(((_5910 && _5923) && _23485) && _23484))
            {
                float4 _6067 = _20090 * float4(_5975, _5977, float(_23485), float(_23484));
                float _6069 = dot(_6067, 1.0f.xxxx);
                bool _6072 = !(_6069 > 0.0f);
                float4 _20152;
                if (!_6072)
                {
                    _20152 = _6067 / _6069.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11592;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11592);
                    }
                    _20152 = 0.0f.xxxx;
                }
                _20151 = _20152;
                _20112 = _6072;
            }
            else
            {
                _20151 = _20090;
                _20112 = false;
            }
            _22077 = float3(_5975, _5977, _20019);
            _20150 = _20151;
            _20111 = _20112;
        }
        else
        {
            _22077 = float3(float(_11036), _5894, 0.0f);
            _20150 = _20090;
            _20111 = false;
        }
        bool _6090 = !_20111;
        float4 _20243;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6090)
        {
            float _6097 = _20150.x + _20150.y;
            float4 _20244;
            if (_6097 > 0.001000000047497451305389404296875f)
            {
                _20244 = float4(_20150.x / _6097, _20150.y / _6097, 0.0f, 0.0f);
            }
            else
            {
                _20244 = float4(_5659, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20243 = _20244;
        }
        else
        {
            _20243 = _20150;
        }
        float4 _20420;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6090) && _11036)
        {
            float _20217;
            do
            {
                uint4 _11732 = r_warped_motion_qdata_tp1.Load(int3(_19888, 0));
                uint _11733 = _11732.x;
                if (_11733 != 0u)
                {
                    float _20216;
                    if (_11733 == 0u)
                    {
                        _20216 = -1.0f;
                    }
                    else
                    {
                        _20216 = float((_11733 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20217 = _20216;
                    break;
                }
                int _20199;
                uint _20200;
                _20200 = _11733;
                _20199 = -1;
                uint _20215;
                for (; _20199 <= 1; _20200 = _20215, _20199++)
                {
                    _20215 = _20200;
                    for (int _20213 = -1; _20213 <= 1; )
                    {
                        _20215 = max(_20215, r_warped_motion_qdata_tp1.Load(int3(clamp(_19888 + int2(_20213, _20199), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20213++;
                        continue;
                    }
                }
                if (_20200 != 0u)
                {
                    float _20212;
                    if (_20200 == 0u)
                    {
                        _20212 = -1.0f;
                    }
                    else
                    {
                        _20212 = float((_20200 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20217 = _20212;
                    break;
                }
                uint _20202;
                _20202 = 4294967295u;
                uint _23377;
                for (int _20201 = 0; _20201 < 8; _20202 = _23377, _20201++)
                {
                    int _20205 = 0;
                    for (;;)
                    {
                        if (_20205 < 5)
                        {
                            int2 _11683 = _19888 + (_1243[_20201] * _1252[_20205].xx);
                            bool _11686 = any(bool2(_11683.x < int2(0, 0).x, _11683.y < int2(0, 0).y));
                            bool _11694;
                            if (!_11686)
                            {
                                _11694 = any(bool2(_11683.x >= cbFI_MvDepthLaneSize.x, _11683.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11694 = _11686;
                            }
                            if (_11694)
                            {
                                _23377 = _20202;
                                break;
                            }
                            uint4 _11772 = r_warped_motion_qdata_tp1.Load(int3(_11683, 0));
                            uint _11773 = _11772.x;
                            if (_11773 != 0u)
                            {
                                _23377 = min(_20202, _11773);
                                break;
                            }
                            _20205++;
                            continue;
                        }
                        else
                        {
                            _23377 = _20202;
                            break;
                        }
                    }
                }
                float _20204;
                if (_20202 == 4294967295u)
                {
                    _20204 = -1.0f;
                }
                else
                {
                    float _20203;
                    if (_20202 == 0u)
                    {
                        _20203 = -1.0f;
                    }
                    else
                    {
                        _20203 = float((_20202 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20204 = _20203;
                }
                _20217 = _20204;
                break;
            } while(false);
            float _6133 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6136 = r_warped_motion_qdata_tp1.Load(int3(_19888, 0)).x == 0u;
            bool _6142;
            if (_6136)
            {
                bool _11798 = all(bool2(_19667.x > 0.0f.xx.x, _19667.y > 0.0f.xx.y));
                bool _11804;
                if (_11798)
                {
                    _11804 = all(bool2(_19667.x < 1.0f.xx.x, _19667.y < 1.0f.xx.y));
                }
                else
                {
                    _11804 = _11798;
                }
                _6142 = _11804;
            }
            else
            {
                _6142 = _6136;
            }
            bool _6147;
            if (_6142)
            {
                bool _11809 = all(bool2(_19669.x > 0.0f.xx.x, _19669.y > 0.0f.xx.y));
                bool _11815;
                if (_11809)
                {
                    _11815 = all(bool2(_19669.x < 1.0f.xx.x, _19669.y < 1.0f.xx.y));
                }
                else
                {
                    _11815 = _11809;
                }
                _6147 = _11815;
            }
            else
            {
                _6147 = _6142;
            }
            bool _20229;
            float4 _20238;
            if (_6147)
            {
                uint _11822_dummy_parameter;
                float _11846 = log(((r_depth_tm1.Load(int3(int2(floor(_19667 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11822_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                uint _11854_dummy_parameter;
                float _11878 = log(((r_depth_tp1.Load(int3(int2(floor(_19669 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11854_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                bool _6158 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6165;
                if (_6158)
                {
                    _6165 = _11878 > (_11846 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6165 = _6158;
                }
                bool _20234;
                float4 _20256;
                if (_6165)
                {
                    _20256 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20234 = true;
                }
                else
                {
                    bool _6171 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6178;
                    if (_6171)
                    {
                        _6178 = _11846 > (_11878 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6178 = _6171;
                    }
                    bool4 _23486 = _6178.xxxx;
                    _20256 = float4(_23486.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20243.x, _23486.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20243.y, _23486.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20243.z, _23486.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20243.w);
                    _20234 = _6178 ? true : false;
                }
                _20238 = _20256;
                _20229 = _20234;
            }
            else
            {
                _20238 = _20243;
                _20229 = false;
            }
            float4 _20311;
            if (_20229)
            {
                _20311 = 1.0f.xxxx;
            }
            else
            {
                bool _6189 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6195;
                if (_6189)
                {
                    _6195 = _20238.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6195 = _6189;
                }
                bool _6200;
                if (_6195)
                {
                    bool _11884 = all(bool2(_19669.x > 0.0f.xx.x, _19669.y > 0.0f.xx.y));
                    bool _11890;
                    if (_11884)
                    {
                        _11890 = all(bool2(_19669.x < 1.0f.xx.x, _19669.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11890 = _11884;
                    }
                    _6200 = _11890;
                }
                else
                {
                    _6200 = _6195;
                }
                float4 _20312;
                if (_6200)
                {
                    float _20265;
                    if (_20217 >= 0.0f)
                    {
                        _20265 = _20217 - _6133;
                    }
                    else
                    {
                        float _20261;
                        _20261 = 2.0f;
                        float _11947;
                        for (int _20260 = 0; _20260 < 24; _20261 = _11947, _20260++)
                        {
                            float _11911 = float(_20260 & 7) * 0.785398185253143310546875f;
                            int _11913 = _20260 >> 3;
                            int _20262;
                            if (_11913 == 0)
                            {
                                _20262 = 16;
                            }
                            else
                            {
                                _20262 = (_11913 == 1) ? 48 : 96;
                            }
                            uint _11979_dummy_parameter;
                            _11947 = min(_20261, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19669 + ((cbFI_MvDepthLaneSizeRcp * float(_20262)) * float2(cos(_11911), sin(_11911))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11979_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20265 = _20261;
                    }
                    uint _12011_dummy_parameter;
                    float4 _20313;
                    if ((1.0f - r_depth_tp1.Load(int3(int2(floor(_19669 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12011_dummy_parameter))))), 0)).x) > ((exp((_20265 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20313 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20313 = 1.0f.xxxx;
                    }
                    _20312 = _20313;
                }
                else
                {
                    _20312 = 1.0f.xxxx;
                }
                _20311 = _20312;
            }
            bool _6228 = _20217 >= 0.0f;
            bool _6229 = (!_20229) && _6228;
            bool _6236;
            if (_6229)
            {
                _6236 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6236 = _6229;
            }
            bool _6242;
            if (_6236)
            {
                _6242 = _20238.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6242 = _6236;
            }
            bool _6247;
            if (_6242)
            {
                bool _12036 = all(bool2(_19667.x > 0.0f.xx.x, _19667.y > 0.0f.xx.y));
                bool _12042;
                if (_12036)
                {
                    _12042 = all(bool2(_19667.x < 1.0f.xx.x, _19667.y < 1.0f.xx.y));
                }
                else
                {
                    _12042 = _12036;
                }
                _6247 = _12042;
            }
            else
            {
                _6247 = _6242;
            }
            float4 _20336;
            if (_6247)
            {
                float _20305;
                if (_6228)
                {
                    _20305 = _20217 - _6133;
                }
                else
                {
                    float _20301;
                    _20301 = 2.0f;
                    float _12099;
                    for (int _20300 = 0; _20300 < 24; _20301 = _12099, _20300++)
                    {
                        float _12063 = float(_20300 & 7) * 0.785398185253143310546875f;
                        int _12065 = _20300 >> 3;
                        int _20302;
                        if (_12065 == 0)
                        {
                            _20302 = 16;
                        }
                        else
                        {
                            _20302 = (_12065 == 1) ? 48 : 96;
                        }
                        uint _12115_dummy_parameter;
                        _12099 = min(_20301, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19667 + ((cbFI_MvDepthLaneSizeRcp * float(_20302)) * float2(cos(_12063), sin(_12063))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12115_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20305 = _20301;
                }
                uint _12163_dummy_parameter;
                float4 _20337;
                if ((1.0f - r_depth_tm1.Load(int3(int2(floor(_19667 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12163_dummy_parameter))))), 0)).x) > ((exp((_20305 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19338 = _20311;
                    _19338.x = 0.0f;
                    _20337 = _19338;
                }
                else
                {
                    _20337 = _20311;
                }
                _20336 = _20337;
            }
            else
            {
                _20336 = _20311;
            }
            float4 _20349;
            if (_6229)
            {
                float _12190 = (exp(((_20217 - _6133) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6285 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6291;
                if (_6285)
                {
                    _6291 = _20238.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6291 = _6285;
                }
                bool _6296;
                if (_6291)
                {
                    bool _12195 = all(bool2(_19671.x > 0.0f.xx.x, _19671.y > 0.0f.xx.y));
                    bool _12201;
                    if (_12195)
                    {
                        _12201 = all(bool2(_19671.x < 1.0f.xx.x, _19671.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12201 = _12195;
                    }
                    _6296 = _12201;
                }
                else
                {
                    _6296 = _6291;
                }
                bool _6304;
                if (_6296)
                {
                    uint _12208_dummy_parameter;
                    _6304 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19671 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12208_dummy_parameter))))), 0)).x) > _12190;
                }
                else
                {
                    _6304 = _6296;
                }
                float4 _20347;
                if (_6304)
                {
                    float4 _19341 = _20336;
                    _19341.w = 0.0f;
                    _20347 = _19341;
                }
                else
                {
                    _20347 = _20336;
                }
                bool _6311 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6317;
                if (_6311)
                {
                    _6317 = _20238.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6317 = _6311;
                }
                bool _6322;
                if (_6317)
                {
                    bool _12226 = all(bool2(_19670.x > 0.0f.xx.x, _19670.y > 0.0f.xx.y));
                    bool _12232;
                    if (_12226)
                    {
                        _12232 = all(bool2(_19670.x < 1.0f.xx.x, _19670.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12232 = _12226;
                    }
                    _6322 = _12232;
                }
                else
                {
                    _6322 = _6317;
                }
                bool _6330;
                if (_6322)
                {
                    uint _12239_dummy_parameter;
                    _6330 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19670 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12239_dummy_parameter))))), 0)).x) > _12190;
                }
                else
                {
                    _6330 = _6322;
                }
                float4 _20350;
                if (_6330)
                {
                    float4 _19344 = _20347;
                    _19344.z = 0.0f;
                    _20350 = _19344;
                }
                else
                {
                    _20350 = _20347;
                }
                _20349 = _20350;
            }
            else
            {
                _20349 = _20336;
            }
            float4 _20421;
            if (any(bool4(_20349.x < 1.0f.xxxx.x, _20349.y < 1.0f.xxxx.y, _20349.z < 1.0f.xxxx.z, _20349.w < 1.0f.xxxx.w)))
            {
                float4 _6341 = _20238 * _20349;
                float _6343 = dot(_6341, 1.0f.xxxx);
                float4 _20422;
                if (_6343 > 0.0f)
                {
                    _20422 = _6341 / _6343.xxxx;
                }
                else
                {
                    bool _6354 = _20349.y == 0.0f;
                    bool _6360;
                    if (_6354)
                    {
                        _6360 = _20349.x > 0.0f;
                    }
                    else
                    {
                        _6360 = _6354;
                    }
                    bool _6365;
                    if (_6360)
                    {
                        bool _12257 = all(bool2(_19667.x > 0.0f.xx.x, _19667.y > 0.0f.xx.y));
                        bool _12263;
                        if (_12257)
                        {
                            _12263 = all(bool2(_19667.x < 1.0f.xx.x, _19667.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12263 = _12257;
                        }
                        _6365 = _12263;
                    }
                    else
                    {
                        _6365 = _6360;
                    }
                    float4 _20423;
                    if (_6365)
                    {
                        _20423 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6370 = _20349.x == 0.0f;
                        bool _6376;
                        if (_6370)
                        {
                            _6376 = _20349.y > 0.0f;
                        }
                        else
                        {
                            _6376 = _6370;
                        }
                        bool _6381;
                        if (_6376)
                        {
                            bool _12268 = all(bool2(_19669.x > 0.0f.xx.x, _19669.y > 0.0f.xx.y));
                            bool _12274;
                            if (_12268)
                            {
                                _12274 = all(bool2(_19669.x < 1.0f.xx.x, _19669.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12274 = _12268;
                            }
                            _6381 = _12274;
                        }
                        else
                        {
                            _6381 = _6376;
                        }
                        bool4 _23489 = _6381.xxxx;
                        _20423 = float4(_23489.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20238.x, _23489.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20238.y, _23489.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20238.z, _23489.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20238.w);
                    }
                    _20422 = _20423;
                }
                _20421 = _20422;
            }
            else
            {
                _20421 = _20238;
            }
            _20420 = _20421;
        }
        else
        {
            _20420 = _20243;
        }
        float4 _21150;
        bool _21456;
        float3 _21780;
        if (((cbFI_pad0 & 32768u) != 0u) && _6090)
        {
            bool _6398 = _20420.x > 0.00999999977648258209228515625f;
            bool _6401 = _20420.y > 0.00999999977648258209228515625f;
            bool _6410 = (_20420.z + _20420.w) > 0.0199999995529651641845703125f;
            bool _6416;
            if (_6410)
            {
                bool _12279 = all(bool2(_19670.x > 0.0f.xx.x, _19670.y > 0.0f.xx.y));
                bool _12285;
                if (_12279)
                {
                    _12285 = all(bool2(_19670.x < 1.0f.xx.x, _19670.y < 1.0f.xx.y));
                }
                else
                {
                    _12285 = _12279;
                }
                _6416 = _12285;
            }
            else
            {
                _6416 = _6410;
            }
            bool _6421;
            if (_6416)
            {
                bool _12290 = all(bool2(_19671.x > 0.0f.xx.x, _19671.y > 0.0f.xx.y));
                bool _12296;
                if (_12290)
                {
                    _12296 = all(bool2(_19671.x < 1.0f.xx.x, _19671.y < 1.0f.xx.y));
                }
                else
                {
                    _12296 = _12290;
                }
                _6421 = _12296;
            }
            else
            {
                _6421 = _6416;
            }
            bool _6428;
            if (_6421)
            {
                float _20436;
                do
                {
                    bool _12379 = all(bool2(_19670.x > 0.0f.xx.x, _19670.y > 0.0f.xx.y));
                    bool _12385;
                    if (_12379)
                    {
                        _12385 = all(bool2(_19670.x < 1.0f.xx.x, _19670.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12385 = _12379;
                    }
                    bool _12316 = !_12385;
                    bool _12323;
                    if (!_12316)
                    {
                        bool _12390 = all(bool2(_19671.x > 0.0f.xx.x, _19671.y > 0.0f.xx.y));
                        bool _12396;
                        if (_12390)
                        {
                            _12396 = all(bool2(_19671.x < 1.0f.xx.x, _19671.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12396 = _12390;
                        }
                        _12323 = !_12396;
                    }
                    else
                    {
                        _12323 = _12316;
                    }
                    if (_12323)
                    {
                        _20436 = 0.0f;
                        break;
                    }
                    uint _12403_dummy_parameter;
                    uint _12419_dummy_parameter;
                    float4x4 _20435;
                    do
                    {
                        float4x4 _12433;
                        bool _20434;
                        do
                        {
                            _12433 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20434 = false;
                                break;
                            }
                            uint _12467 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12467 + 32u) * 4 + 0) != 1u)
                            {
                                _20434 = false;
                                break;
                            }
                            uint _20431;
                            _20431 = 0u;
                            for (; _20431 < 4u; _20431++)
                            {
                                for (uint _20432 = 0u; _20432 < 4u; )
                                {
                                    _12433[_20431][_20432] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12467 + 16u) + (_20431 * 4u)) + _20432) * 4 + 0));
                                    _20432++;
                                    continue;
                                }
                            }
                            _20434 = true;
                            break;
                        } while(false);
                        if (_20434)
                        {
                            _20435 = _12433;
                            break;
                        }
                        _20435 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12344 = mul(float4((float2(_19670.x, 1.0f - _19670.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19670 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12403_dummy_parameter))))), 0)).x, 1.0f), _20435);
                    float _12346 = _12344.w;
                    if (abs(_12346) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20436 = 0.0f;
                        break;
                    }
                    float _12357 = abs(cbFI_DeviceToViewDepth.y / ((_12344.z / _12346) - cbFI_DeviceToViewDepth.x));
                    float _12360 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19671 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12419_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20436 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12357 - _12360) / max(max(_12357, _12360), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6428 = _20436 < 0.5f;
            }
            else
            {
                _6428 = _6421;
            }
            float4 _20455;
            if (_6428)
            {
                uint _12571_dummy_parameter;
                uint _12602_dummy_parameter;
                float4 _20456;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19670 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12571_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19671 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12602_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20456 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20456 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20455 = _20456;
            }
            else
            {
                _20455 = 1.0f.xxxx;
            }
            bool _6452;
            if (_11036)
            {
                bool _12631 = all(bool2(_19667.x > 0.0f.xx.x, _19667.y > 0.0f.xx.y));
                bool _12637;
                if (_12631)
                {
                    _12637 = all(bool2(_19667.x < 1.0f.xx.x, _19667.y < 1.0f.xx.y));
                }
                else
                {
                    _12637 = _12631;
                }
                _6452 = _12637;
            }
            else
            {
                _6452 = _11036;
            }
            bool _6458;
            if (_11036)
            {
                bool _12642 = all(bool2(_19669.x > 0.0f.xx.x, _19669.y > 0.0f.xx.y));
                bool _12648;
                if (_12642)
                {
                    _12648 = all(bool2(_19669.x < 1.0f.xx.x, _19669.y < 1.0f.xx.y));
                }
                else
                {
                    _12648 = _12642;
                }
                _6458 = _12648;
            }
            else
            {
                _6458 = _11036;
            }
            bool _6464;
            if (_11068)
            {
                bool _12653 = all(bool2(_19670.x > 0.0f.xx.x, _19670.y > 0.0f.xx.y));
                bool _12659;
                if (_12653)
                {
                    _12659 = all(bool2(_19670.x < 1.0f.xx.x, _19670.y < 1.0f.xx.y));
                }
                else
                {
                    _12659 = _12653;
                }
                _6464 = _12659;
            }
            else
            {
                _6464 = _11068;
            }
            bool _6470;
            if (_11068)
            {
                bool _12664 = all(bool2(_19671.x > 0.0f.xx.x, _19671.y > 0.0f.xx.y));
                bool _12670;
                if (_12664)
                {
                    _12670 = all(bool2(_19671.x < 1.0f.xx.x, _19671.y < 1.0f.xx.y));
                }
                else
                {
                    _12670 = _12664;
                }
                _6470 = _12670;
            }
            else
            {
                _6470 = _11068;
            }
            bool _6473 = _6464 != _6470;
            bool _6479;
            if (_6473)
            {
                _6479 = _6452 || _6458;
            }
            else
            {
                _6479 = _6473;
            }
            float4 _20558;
            if (_6479)
            {
                float4 _19371 = _20455;
                _19371.z = 0.0f;
                _19371.w = 0.0f;
                _20558 = _19371;
            }
            else
            {
                _20558 = _20455;
            }
            bool _6486 = _6452 && _6398;
            bool _6489 = _6458 && _6401;
            float4 _20663;
            float3 _21889;
            if (_6486 || _6489)
            {
                float _20553;
                do
                {
                    uint4 _12809 = r_warped_motion_qdata_tp1.Load(int3(_19888, 0));
                    uint _12810 = _12809.x;
                    if (_12810 != 0u)
                    {
                        float _20552;
                        if (_12810 == 0u)
                        {
                            _20552 = -1.0f;
                        }
                        else
                        {
                            _20552 = float((_12810 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20553 = _20552;
                        break;
                    }
                    int _20535;
                    uint _20536;
                    _20536 = _12810;
                    _20535 = -1;
                    uint _20551;
                    for (; _20535 <= 1; _20536 = _20551, _20535++)
                    {
                        _20551 = _20536;
                        for (int _20549 = -1; _20549 <= 1; )
                        {
                            _20551 = max(_20551, r_warped_motion_qdata_tp1.Load(int3(clamp(_19888 + int2(_20549, _20535), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20549++;
                            continue;
                        }
                    }
                    if (_20536 != 0u)
                    {
                        float _20548;
                        if (_20536 == 0u)
                        {
                            _20548 = -1.0f;
                        }
                        else
                        {
                            _20548 = float((_20536 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20553 = _20548;
                        break;
                    }
                    uint _20538;
                    _20538 = 4294967295u;
                    uint _23378;
                    for (int _20537 = 0; _20537 < 8; _20538 = _23378, _20537++)
                    {
                        int _20541 = 0;
                        for (;;)
                        {
                            if (_20541 < 5)
                            {
                                int2 _12760 = _19888 + (_1243[_20537] * _1252[_20541].xx);
                                bool _12763 = any(bool2(_12760.x < int2(0, 0).x, _12760.y < int2(0, 0).y));
                                bool _12771;
                                if (!_12763)
                                {
                                    _12771 = any(bool2(_12760.x >= cbFI_MvDepthLaneSize.x, _12760.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12771 = _12763;
                                }
                                if (_12771)
                                {
                                    _23378 = _20538;
                                    break;
                                }
                                uint4 _12849 = r_warped_motion_qdata_tp1.Load(int3(_12760, 0));
                                uint _12850 = _12849.x;
                                if (_12850 != 0u)
                                {
                                    _23378 = min(_20538, _12850);
                                    break;
                                }
                                _20541++;
                                continue;
                            }
                            else
                            {
                                _23378 = _20538;
                                break;
                            }
                        }
                    }
                    float _20540;
                    if (_20538 == 4294967295u)
                    {
                        _20540 = -1.0f;
                    }
                    else
                    {
                        float _20539;
                        if (_20538 == 0u)
                        {
                            _20539 = -1.0f;
                        }
                        else
                        {
                            _20539 = float((_20538 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20540 = _20539;
                    }
                    _20553 = _20540;
                    break;
                } while(false);
                bool _6497 = _20553 < 0.0f;
                float _20554;
                if (_6497)
                {
                    _20554 = 0.0f;
                }
                else
                {
                    _20554 = _20553 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12871_dummy_parameter;
                uint _12903_dummy_parameter;
                float4 _20591;
                if ((_6497 && _6486) && _6489)
                {
                    uint _12935_dummy_parameter;
                    float _12959 = log(((r_depth_tm1.Load(int3(int2(floor(_19667 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12935_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    uint _12967_dummy_parameter;
                    float _12991 = log(((r_depth_tp1.Load(int3(int2(floor(_19669 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12967_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20592;
                    if (_12959 > (_12991 + 0.07999999821186065673828125f))
                    {
                        float4 _19375 = _20558;
                        _19375.x = 0.0f;
                        _20592 = _19375;
                    }
                    else
                    {
                        float4 _20593;
                        if (_12991 > (_12959 + 0.07999999821186065673828125f))
                        {
                            float4 _19377 = _20558;
                            _19377.y = 0.0f;
                            _20593 = _19377;
                        }
                        else
                        {
                            _20593 = _20558;
                        }
                        _20592 = _20593;
                    }
                    _20591 = _20592;
                }
                else
                {
                    _20591 = _20558;
                }
                float _6549 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6551 = _20553 >= 0.0f;
                float _20574;
                if (_6551)
                {
                    _20574 = _20553 - _6549;
                }
                else
                {
                    float _20570;
                    if (_6486)
                    {
                        float _20569;
                        _20569 = 2.0f;
                        float _13049;
                        for (int _20568 = 0; _20568 < 24; _20569 = _13049, _20568++)
                        {
                            float _13013 = float(_20568 & 7) * 0.785398185253143310546875f;
                            int _13015 = _20568 >> 3;
                            int _20571;
                            if (_13015 == 0)
                            {
                                _20571 = 16;
                            }
                            else
                            {
                                _20571 = (_13015 == 1) ? 48 : 96;
                            }
                            uint _13065_dummy_parameter;
                            _13049 = min(_20569, log(((r_depth_tm1.Load(int3(int2(floor(clamp(_19667 + ((cbFI_MvDepthLaneSizeRcp * float(_20571)) * float2(cos(_13013), sin(_13013))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13065_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20570 = _20569;
                    }
                    else
                    {
                        _20570 = 0.0f;
                    }
                    _20574 = _20570;
                }
                float _20581;
                if (_6551)
                {
                    _20581 = _20553 - _6549;
                }
                else
                {
                    float _20577;
                    if (_6489)
                    {
                        float _20576;
                        _20576 = 2.0f;
                        float _13163;
                        for (int _20575 = 0; _20575 < 24; _20576 = _13163, _20575++)
                        {
                            float _13127 = float(_20575 & 7) * 0.785398185253143310546875f;
                            int _13129 = _20575 >> 3;
                            int _20578;
                            if (_13129 == 0)
                            {
                                _20578 = 16;
                            }
                            else
                            {
                                _20578 = (_13129 == 1) ? 48 : 96;
                            }
                            uint _13195_dummy_parameter;
                            _13163 = min(_20576, log(((r_depth_tp1.Load(int3(int2(floor(clamp(_19669 + ((cbFI_MvDepthLaneSizeRcp * float(_20578)) * float2(cos(_13127), sin(_13127))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13195_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20577 = _20576;
                    }
                    else
                    {
                        _20577 = 0.0f;
                    }
                    _20581 = _20577;
                }
                float _20582;
                if (_6486)
                {
                    uint _13227_dummy_parameter;
                    _20582 = 1.0f - r_depth_tm1.Load(int3(int2(floor(_19667 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13227_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20582 = 0.0f;
                }
                float _20583;
                if (_6489)
                {
                    uint _13247_dummy_parameter;
                    _20583 = 1.0f - r_depth_tp1.Load(int3(int2(floor(_19669 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13247_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20583 = 0.0f;
                }
                bool _6606;
                if (_6486)
                {
                    _6606 = _20582 > ((exp((_20574 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6606 = _6486;
                }
                float4 _20599;
                if (_6606)
                {
                    float4 _19379 = _20591;
                    _19379.x = 0.0f;
                    _20599 = _19379;
                }
                else
                {
                    _20599 = _20591;
                }
                bool _6618;
                if (_6489)
                {
                    _6618 = _20583 > ((exp((_20581 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6618 = _6489;
                }
                float4 _20601;
                if (_6618)
                {
                    float4 _19381 = _20599;
                    _19381.y = 0.0f;
                    _20601 = _19381;
                }
                else
                {
                    _20601 = _20599;
                }
                float4 _20664;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6551)
                {
                    bool _6638;
                    if (_6486)
                    {
                        _6638 = _20582 < ((exp((_20574 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6638 = _6486;
                    }
                    float4 _20603;
                    if (_6638)
                    {
                        float4 _19383 = _20601;
                        _19383.x = 0.0f;
                        _20603 = _19383;
                    }
                    else
                    {
                        _20603 = _20601;
                    }
                    bool _6650;
                    if (_6489)
                    {
                        _6650 = _20583 < ((exp((_20581 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6650 = _6489;
                    }
                    float4 _20665;
                    if (_6650)
                    {
                        float4 _19385 = _20603;
                        _19385.y = 0.0f;
                        _20665 = _19385;
                    }
                    else
                    {
                        _20665 = _20603;
                    }
                    _20664 = _20665;
                }
                else
                {
                    _20664 = _20601;
                }
                _21889 = float3(_20554, log(((r_depth_tm1.Load(int3(int2(floor(_19667 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12871_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tp1.Load(int3(int2(floor(_19669 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12903_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
                _20663 = _20664;
            }
            else
            {
                _21889 = float3(0.0f, 0.0f, 0.5f);
                _20663 = _20558;
            }
            bool _6661 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6410;
            bool _6667;
            if (_6661)
            {
                _6667 = _6464 || _6470;
            }
            else
            {
                _6667 = _6661;
            }
            float4 _20706;
            if (_6667)
            {
                float _20658;
                do
                {
                    uint4 _13427 = r_warped_motion_qdata_tp1.Load(int3(_19888, 0));
                    uint _13428 = _13427.x;
                    if (_13428 != 0u)
                    {
                        float _20657;
                        if (_13428 == 0u)
                        {
                            _20657 = -1.0f;
                        }
                        else
                        {
                            _20657 = float((_13428 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20658 = _20657;
                        break;
                    }
                    int _20640;
                    uint _20641;
                    _20641 = _13428;
                    _20640 = -1;
                    uint _20656;
                    for (; _20640 <= 1; _20641 = _20656, _20640++)
                    {
                        _20656 = _20641;
                        for (int _20654 = -1; _20654 <= 1; )
                        {
                            _20656 = max(_20656, r_warped_motion_qdata_tp1.Load(int3(clamp(_19888 + int2(_20654, _20640), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20654++;
                            continue;
                        }
                    }
                    if (_20641 != 0u)
                    {
                        float _20653;
                        if (_20641 == 0u)
                        {
                            _20653 = -1.0f;
                        }
                        else
                        {
                            _20653 = float((_20641 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20658 = _20653;
                        break;
                    }
                    uint _20643;
                    _20643 = 4294967295u;
                    uint _23379;
                    for (int _20642 = 0; _20642 < 8; _20643 = _23379, _20642++)
                    {
                        int _20646 = 0;
                        for (;;)
                        {
                            if (_20646 < 5)
                            {
                                int2 _13378 = _19888 + (_1243[_20642] * _1252[_20646].xx);
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
                                    _23379 = _20643;
                                    break;
                                }
                                uint4 _13467 = r_warped_motion_qdata_tp1.Load(int3(_13378, 0));
                                uint _13468 = _13467.x;
                                if (_13468 != 0u)
                                {
                                    _23379 = min(_20643, _13468);
                                    break;
                                }
                                _20646++;
                                continue;
                            }
                            else
                            {
                                _23379 = _20643;
                                break;
                            }
                        }
                    }
                    float _20645;
                    if (_20643 == 4294967295u)
                    {
                        _20645 = -1.0f;
                    }
                    else
                    {
                        float _20644;
                        if (_20643 == 0u)
                        {
                            _20644 = -1.0f;
                        }
                        else
                        {
                            _20644 = float((_20643 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20645 = _20644;
                    }
                    _20658 = _20645;
                    break;
                } while(false);
                float4 _20707;
                if (_20658 >= 0.0f)
                {
                    float _13489 = (exp((_20658 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6686;
                    if (_6464)
                    {
                        uint _13496_dummy_parameter;
                        _6686 = (1.0f - r_depth_tm1.Load(int3(int2(floor(_19670 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13496_dummy_parameter))))), 0)).x) > _13489;
                    }
                    else
                    {
                        _6686 = _6464;
                    }
                    float4 _20676;
                    if (_6686)
                    {
                        float4 _19387 = _20663;
                        _19387.z = 0.0f;
                        _20676 = _19387;
                    }
                    else
                    {
                        _20676 = _20663;
                    }
                    bool _6698;
                    if (_6470)
                    {
                        uint _13516_dummy_parameter;
                        _6698 = (1.0f - r_depth_tp1.Load(int3(int2(floor(_19671 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13516_dummy_parameter))))), 0)).x) > _13489;
                    }
                    else
                    {
                        _6698 = _6470;
                    }
                    float4 _20708;
                    if (_6698)
                    {
                        float4 _19389 = _20676;
                        _19389.w = 0.0f;
                        _20708 = _19389;
                    }
                    else
                    {
                        _20708 = _20676;
                    }
                    _20707 = _20708;
                }
                else
                {
                    _20707 = _20663;
                }
                _20706 = _20707;
            }
            else
            {
                _20706 = _20663;
            }
            bool _6706 = _6452 != _6458;
            bool _6713;
            if (_6706)
            {
                _6713 = _6452 ? _6398 : _6401;
            }
            else
            {
                _6713 = _6706;
            }
            bool _6720;
            if (_6713)
            {
                _6720 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6720 = _6713;
            }
            float4 _20809;
            if (_6720)
            {
                bool2 _6725 = _6452.xx;
                float2 _6726 = float2(_6725.x ? _19667.x : _19669.x, _6725.y ? _19667.y : _19669.y);
                float _20690;
                if (_6452)
                {
                    uint _13536_dummy_parameter;
                    _20690 = r_depth_tm1.Load(int3(int2(floor(_6726 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13536_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13552_dummy_parameter;
                    _20690 = r_depth_tp1.Load(int3(int2(floor(_6726 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13552_dummy_parameter))))), 0)).x;
                }
                float4x4 _20697;
                if (_6452)
                {
                    float4x4 _20686;
                    do
                    {
                        float4x4 _13566;
                        bool _20685;
                        do
                        {
                            _13566 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20685 = false;
                                break;
                            }
                            uint _13600 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13600 + 32u) * 4 + 0) != 1u)
                            {
                                _20685 = false;
                                break;
                            }
                            uint _20682;
                            _20682 = 0u;
                            for (; _20682 < 4u; _20682++)
                            {
                                for (uint _20683 = 0u; _20683 < 4u; )
                                {
                                    _13566[_20682][_20683] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13600 + 16u) + (_20682 * 4u)) + _20683) * 4 + 0));
                                    _20683++;
                                    continue;
                                }
                            }
                            _20685 = true;
                            break;
                        } while(false);
                        if (_20685)
                        {
                            _20686 = _13566;
                            break;
                        }
                        _20686 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20697 = _20686;
                }
                else
                {
                    float4x4 _20681;
                    do
                    {
                        float4x4 _13672;
                        bool _20680;
                        do
                        {
                            _13672 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20680 = false;
                                break;
                            }
                            uint _13706 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13706 + 32u) * 4 + 0) != 1u)
                            {
                                _20680 = false;
                                break;
                            }
                            uint _20677;
                            _20677 = 0u;
                            for (; _20677 < 4u; _20677++)
                            {
                                for (uint _20678 = 0u; _20678 < 4u; )
                                {
                                    _13672[_20677][_20678] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13706 + (_20677 * 4u)) + _20678) * 4 + 0));
                                    _20678++;
                                    continue;
                                }
                            }
                            _20680 = true;
                            break;
                        } while(false);
                        if (_20680)
                        {
                            _20681 = _13672;
                            break;
                        }
                        _20681 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20697 = _20681;
                }
                float2 _20698;
                do
                {
                    float _13783 = _6726.x;
                    float _13786 = 1.0f - _6726.y;
                    float4 _13797 = mul(float4((float2(_13783, _13786) * 2.0f) - 1.0f.xx, _20690, 1.0f), _20697);
                    float _13799 = _13797.w;
                    if (!(_13799 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20698 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13812 = ((_13797.xy / _13799.xx) + 1.0f.xx) * 0.5f;
                    _20698 = float2(_13812.x - _13783, _13786 - _13812.y);
                    break;
                } while(false);
                float2 _6756 = float2(cbFI_DisplaySize);
                float4 _20810;
                if (!(length(((_6726 + _20698) - float2(_6725.x ? _19669.x : _19667.x, _6725.y ? _19669.y : _19667.y)) * _6756) <= ((0.100000001490116119384765625f * length(_20698 * _6756)) + 8.0f)))
                {
                    float4 _20811;
                    if (_6452)
                    {
                        float4 _19399 = _20706;
                        _19399.x = 0.0f;
                        _20811 = _19399;
                    }
                    else
                    {
                        float4 _19401 = _20706;
                        _19401.y = 0.0f;
                        _20811 = _19401;
                    }
                    _20810 = _20811;
                }
                else
                {
                    _20810 = _20706;
                }
                _20809 = _20810;
            }
            else
            {
                _20809 = _20706;
            }
            float4 _6781 = _20420 * _20809;
            float _6783 = dot(_6781, 1.0f.xxxx);
            float4 _21151;
            bool _21457;
            if (_6783 > 0.0f)
            {
                _21457 = _20111;
                _21151 = _6781 / _6783.xxxx;
            }
            else
            {
                bool _6794 = any(bool4(_20809.x < 1.0f.xxxx.x, _20809.y < 1.0f.xxxx.y, _20809.z < 1.0f.xxxx.z, _20809.w < 1.0f.xxxx.w));
                if (_6794)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13834;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13834);
                    }
                }
                bool4 _23492 = _6794.xxxx;
                _21457 = _6794 ? true : _20111;
                _21151 = float4(_23492.x ? 0.0f.xxxx.x : _20420.x, _23492.y ? 0.0f.xxxx.y : _20420.y, _23492.z ? 0.0f.xxxx.z : _20420.z, _23492.w ? 0.0f.xxxx.w : _20420.w);
            }
            _21780 = _21889;
            _21456 = _21457;
            _21150 = _21151;
        }
        else
        {
            _21780 = float3(0.0f, 0.0f, 0.5f);
            _21456 = _20111;
            _21150 = _20420;
        }
        uint _6803 = (cbFI_pad0 >> 24u) & 31u;
        uint _6807 = (cbFI_pad0 >> 16u) & 255u;
        bool _6809 = _6803 != 0u;
        bool _6811 = _6807 == 12u;
        bool _6814 = _6807 == 13u;
        float4 _21171;
        if ((_6809 || _6811) || _6814)
        {
            float _20817;
            do
            {
                bool _13918 = all(bool2(_19670.x > 0.0f.xx.x, _19670.y > 0.0f.xx.y));
                bool _13924;
                if (_13918)
                {
                    _13924 = all(bool2(_19670.x < 1.0f.xx.x, _19670.y < 1.0f.xx.y));
                }
                else
                {
                    _13924 = _13918;
                }
                bool _13855 = !_13924;
                bool _13862;
                if (!_13855)
                {
                    bool _13929 = all(bool2(_19671.x > 0.0f.xx.x, _19671.y > 0.0f.xx.y));
                    bool _13935;
                    if (_13929)
                    {
                        _13935 = all(bool2(_19671.x < 1.0f.xx.x, _19671.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13935 = _13929;
                    }
                    _13862 = !_13935;
                }
                else
                {
                    _13862 = _13855;
                }
                if (_13862)
                {
                    _20817 = 0.0f;
                    break;
                }
                uint _13942_dummy_parameter;
                uint _13958_dummy_parameter;
                float4x4 _20816;
                do
                {
                    float4x4 _13972;
                    bool _20815;
                    do
                    {
                        _13972 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20815 = false;
                            break;
                        }
                        uint _14006 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14006 + 32u) * 4 + 0) != 1u)
                        {
                            _20815 = false;
                            break;
                        }
                        uint _20812;
                        _20812 = 0u;
                        for (; _20812 < 4u; _20812++)
                        {
                            for (uint _20813 = 0u; _20813 < 4u; )
                            {
                                _13972[_20812][_20813] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14006 + 16u) + (_20812 * 4u)) + _20813) * 4 + 0));
                                _20813++;
                                continue;
                            }
                        }
                        _20815 = true;
                        break;
                    } while(false);
                    if (_20815)
                    {
                        _20816 = _13972;
                        break;
                    }
                    _20816 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13883 = mul(float4((float2(_19670.x, 1.0f - _19670.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19670 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13942_dummy_parameter))))), 0)).x, 1.0f), _20816);
                float _13885 = _13883.w;
                if (abs(_13885) < 9.9999999747524270787835121154785e-07f)
                {
                    _20817 = 0.0f;
                    break;
                }
                float _13896 = abs(cbFI_DeviceToViewDepth.y / ((_13883.z / _13885) - cbFI_DeviceToViewDepth.x));
                float _13899 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19671 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13958_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20817 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13896 - _13899) / max(max(_13896, _13899), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14108 = all(bool2(_19671.x > 0.0f.xx.x, _19671.y > 0.0f.xx.y));
            bool _14114;
            if (_14108)
            {
                _14114 = all(bool2(_19671.x < 1.0f.xx.x, _19671.y < 1.0f.xx.y));
            }
            else
            {
                _14114 = _14108;
            }
            float _20818;
            if (_14114)
            {
                uint _14121_dummy_parameter;
                _20818 = length((_7934 + (r_motion_tp1.Load(int3(int2(floor(_19671 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14121_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20818 = 1000000.0f;
            }
            float _20833;
            if ((_6803 & 1u) != 0u)
            {
                _20833 = _20817;
            }
            else
            {
                _20833 = 1.0f;
            }
            float _20834;
            if ((_6803 & 2u) != 0u)
            {
                _20834 = _20833 * (1.0f - smoothstep(2.0f, 8.0f, _20818));
            }
            else
            {
                _20834 = _20833;
            }
            float _20835;
            if ((_6803 & 4u) != 0u)
            {
                _20835 = _20834 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8655 - _8663) - length(_8639 - _8647))));
            }
            else
            {
                _20835 = _20834;
            }
            float _21165;
            if ((_6803 & 8u) != 0u)
            {
                _21165 = lerp(1.0f, _20835, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8639 - _8647)));
            }
            else
            {
                _21165 = _20835;
            }
            bool _6889 = (_6803 & 16u) != 0u;
            bool _6898;
            if (_6889)
            {
                _6898 = length(_19665 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6898 = _6889;
            }
            float _23494 = _6898 ? 1.0f : _21165;
            bool _6904 = _6809 && _11036;
            bool _6909;
            if (_6904)
            {
                bool _14146 = all(bool2(_19667.x > 0.0f.xx.x, _19667.y > 0.0f.xx.y));
                bool _14152;
                if (_14146)
                {
                    _14152 = all(bool2(_19667.x < 1.0f.xx.x, _19667.y < 1.0f.xx.y));
                }
                else
                {
                    _14152 = _14146;
                }
                _6909 = _14152;
            }
            else
            {
                _6909 = _6904;
            }
            bool _6914;
            if (_6909)
            {
                bool _14157 = all(bool2(_19669.x > 0.0f.xx.x, _19669.y > 0.0f.xx.y));
                bool _14163;
                if (_14157)
                {
                    _14163 = all(bool2(_19669.x < 1.0f.xx.x, _19669.y < 1.0f.xx.y));
                }
                else
                {
                    _14163 = _14157;
                }
                _6914 = _14163;
            }
            else
            {
                _6914 = _6909;
            }
            float4 _21172;
            if (_6914)
            {
                float _6920 = _21150.x + _21150.y;
                float _6929 = (_21150.z + _21150.w) * (1.0f - _23494);
                float _21168;
                if (_6920 > 9.9999997473787516355514526367188e-06f)
                {
                    _21168 = _21150.x / _6920;
                }
                else
                {
                    _21168 = _5659;
                }
                _21172 = float4(_21150.x + (_6929 * _21168), _21150.y + (_6929 * (1.0f - _21168)), _21150.zw * _23494);
            }
            else
            {
                _21172 = _21150;
            }
            _21171 = _21172;
        }
        else
        {
            _21171 = _21150;
        }
        float3 _6990 = (((_8639 * _21171.x) + (_8647 * _21171.y)) + (_8655 * _21171.z)) + (_8663 * _21171.w);
        float3 _23127;
        if (_5675 && (_21186 > 0.0f))
        {
            uint _14170_dummy_parameter;
            float2 _14185 = r_motion_tp1.Load(int3(int2(floor(_5434 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14170_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21448;
            if (_7962)
            {
                float2 _14230 = clamp((((_19644 + (_14185 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14233 = tan(_14230.x);
                _21448 = (float2(_14233 / cbFI_DeviceToViewDepth.z, (tan(_14230.y) * sqrt(1.0f + (_14233 * _14233))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21448 = _19644 + (_14185 * cbFI_Timestep);
            }
            float2 _21449;
            if (_7962)
            {
                float2 _14309 = clamp((((_19644 + (_14185 * _5649)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14312 = tan(_14309.x);
                _21449 = (float2(_14312 / cbFI_DeviceToViewDepth.z, (tan(_14309.y) * sqrt(1.0f + (_14312 * _14312))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21449 = _19644 + (_14185 * _5649);
            }
            _23127 = lerp(_6990, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21448, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21449, 0.0f).xyz, cbFI_Timestep.xxx), _21186.xxx);
        }
        else
        {
            _23127 = _6990;
        }
        float3 _23126;
        if (_21456)
        {
            float3 _14354 = r_current_interpolation_source.Load(int3(_4935, 0)).xyz;
            float3 _23128;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11036)
            {
                uint _14361_dummy_parameter;
                float _21579;
                _21579 = r_depth_tm1.Load(int3(int2(floor(_19667 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14361_dummy_parameter))))), 0)).x;
                float _7071;
                for (int _21578 = 0; _21578 < 24; _21579 = _7071, _21578++)
                {
                    float _7043 = float(_21578 & 7) * 0.785398185253143310546875f;
                    int _7045 = _21578 >> 3;
                    int _23221;
                    if (_7045 == 0)
                    {
                        _23221 = 16;
                    }
                    else
                    {
                        _23221 = (_7045 == 1) ? 48 : 96;
                    }
                    uint _14381_dummy_parameter;
                    _7071 = max(_21579, r_depth_tm1.Load(int3(int2(floor(clamp(_19667 + ((cbFI_MvDepthLaneSizeRcp * float(_23221)) * float2(cos(_7043), sin(_7043))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14381_dummy_parameter))))), 0)).x);
                }
                float2 _21580;
                do
                {
                    float _14403 = 1.0f - _19667.y;
                    float4 _14414 = mul(float4((float2(_19667.x, _14403) * 2.0f) - 1.0f.xx, _21579, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14416 = _14414.w;
                    if (!(_14416 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21580 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14429 = ((_14414.xy / _14416.xx) + 1.0f.xx) * 0.5f;
                    _21580 = float2(_14429.x - _19667.x, _14403 - _14429.y);
                    break;
                } while(false);
                float2 _7082 = _19667 + _21580;
                bool _14447 = all(bool2(_7082.x > 0.0f.xx.x, _7082.y > 0.0f.xx.y));
                bool _14453;
                if (_14447)
                {
                    _14453 = all(bool2(_7082.x < 1.0f.xx.x, _7082.y < 1.0f.xx.y));
                }
                else
                {
                    _14453 = _14447;
                }
                float3 _23129;
                if (_14453)
                {
                    float _7088 = abs(cbFI_DeviceToViewDepth.y / (_21579 - cbFI_DeviceToViewDepth.x));
                    uint _14473_dummy_parameter;
                    int2 _14473 = int2(spvTextureSize(r_depth_m2, uint(0), _14473_dummy_parameter));
                    float _7092 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7082 * float2(_14473))), int2(0, 0), _14473 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _23134;
                    if (abs(_7092 - _7088) <= (0.20000000298023223876953125f * max(_7092, _7088)))
                    {
                        uint _14507_dummy_parameter;
                        int2 _14507 = int2(spvTextureSize(r_colour_m2, uint(0), _14507_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14530;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14530);
                        }
                        _23134 = r_colour_m2.Load(int3(clamp(int2(floor(_7082 * float2(_14507))), int2(0, 0), _14507 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14540;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14540);
                        }
                        _23134 = _14354;
                    }
                    _23129 = _23134;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14550;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14550);
                    }
                    _23129 = _14354;
                }
                _23128 = _23129;
            }
            else
            {
                _23128 = _14354;
            }
            _23126 = _23128;
        }
        else
        {
            _23126 = _23127;
        }
        bool _7117 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _23125;
        float _23201;
        if (_7117)
        {
            float2 _7121 = float2(cbFI_DisplaySize);
            float3 _21762;
            float _21763;
            do
            {
                bool _14862;
                float4x4 _21587;
                do
                {
                    float4x4 _14838;
                    bool _21586;
                    do
                    {
                        _14838 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14862 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14862)
                        {
                            _21586 = false;
                            break;
                        }
                        uint _14872 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14872 + 32u) * 4 + 0) != 1u)
                        {
                            _21586 = false;
                            break;
                        }
                        uint _21583;
                        _21583 = 0u;
                        for (; _21583 < 4u; _21583++)
                        {
                            for (uint _21584 = 0u; _21584 < 4u; )
                            {
                                _14838[_21583][_21584] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14872 + (_21583 * 4u)) + _21584) * 4 + 0));
                                _21584++;
                                continue;
                            }
                        }
                        _21586 = true;
                        break;
                    } while(false);
                    if (_21586)
                    {
                        _21587 = _14838;
                        break;
                    }
                    _21587 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float4x4 _14620 = spvInverse(_21587);
                bool _14622 = _6807 == 33u;
                if (_14622 || (_6807 == 34u))
                {
                    uint _14952_dummy_parameter;
                    float2 _14967 = r_motion_tp1.Load(int3(int2(floor(clamp(_5434, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14952_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
                    float2 _21754;
                    if (_14622)
                    {
                        uint _14979_dummy_parameter;
                        float2 _21753;
                        do
                        {
                            float _14998 = _5434.x;
                            float _15001 = 1.0f - _5434.y;
                            float4 _15012 = mul(float4((float2(_14998, _15001) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5434 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _14979_dummy_parameter))))), 0)).x, 1.0f), _21587);
                            float _15014 = _15012.w;
                            if (!(_15014 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21753 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15027 = ((_15012.xy / _15014.xx) + 1.0f.xx) * 0.5f;
                            _21753 = float2(_15027.x - _14998, _15001 - _15027.y);
                            break;
                        } while(false);
                        _21754 = _21753 - _14967;
                    }
                    else
                    {
                        float2 _14642 = _5434 + _14967;
                        bool _15045 = all(bool2(_14642.x > 0.0f.xx.x, _14642.y > 0.0f.xx.y));
                        bool _15051;
                        if (_15045)
                        {
                            _15051 = all(bool2(_14642.x < 1.0f.xx.x, _14642.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15051 = _15045;
                        }
                        float2 _21752;
                        if (_15051)
                        {
                            uint _15058_dummy_parameter;
                            float2 _21751;
                            do
                            {
                                float _15077 = _14642.x;
                                float _15080 = 1.0f - _14642.y;
                                float4 _15091 = mul(float4((float2(_15077, _15080) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14642 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _15058_dummy_parameter))))), 0)).x, 1.0f), _14620);
                                float _15093 = _15091.w;
                                if (!(_15093 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21751 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _15106 = ((_15091.xy / _15093.xx) + 1.0f.xx) * 0.5f;
                                _21751 = float2(_15106.x - _15077, _15080 - _15106.y);
                                break;
                            } while(false);
                            _21752 = _21751 + _14967;
                        }
                        else
                        {
                            _21752 = 0.0f.xx;
                        }
                        _21754 = _21752;
                    }
                    bool _21761;
                    do
                    {
                        bool _15185 = all(bool2(_5434.x > 0.0f.xx.x, _5434.y > 0.0f.xx.y));
                        bool _15191;
                        if (_15185)
                        {
                            _15191 = all(bool2(_5434.x < 1.0f.xx.x, _5434.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15191 = _15185;
                        }
                        if (!_15191)
                        {
                            _21761 = false;
                            break;
                        }
                        uint _15198_dummy_parameter;
                        float4x4 _21759;
                        do
                        {
                            float4x4 _15212;
                            bool _21758;
                            do
                            {
                                _15212 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14862)
                                {
                                    _21758 = false;
                                    break;
                                }
                                uint _15246 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_15246 + 32u) * 4 + 0) != 1u)
                                {
                                    _21758 = false;
                                    break;
                                }
                                uint _21755;
                                _21755 = 0u;
                                for (; _21755 < 4u; _21755++)
                                {
                                    for (uint _21756 = 0u; _21756 < 4u; )
                                    {
                                        _15212[_21755][_21756] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15246 + (_21755 * 4u)) + _21756) * 4 + 0));
                                        _21756++;
                                        continue;
                                    }
                                }
                                _21758 = true;
                                break;
                            } while(false);
                            if (_21758)
                            {
                                _21759 = _15212;
                                break;
                            }
                            _21759 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21760;
                        do
                        {
                            float _15323 = _5434.x;
                            float _15326 = 1.0f - _5434.y;
                            float4 _15337 = mul(float4((float2(_15323, _15326) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5434 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15198_dummy_parameter))))), 0)).x, 1.0f), _21759);
                            float _15339 = _15337.w;
                            if (!(_15339 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21760 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15352 = ((_15337.xy / _15339.xx) + 1.0f.xx) * 0.5f;
                            _21760 = float2(_15352.x - _15323, _15326 - _15352.y);
                            break;
                        } while(false);
                        float2 _15149 = abs(_21760);
                        if (any(bool2(_15149.x > 100000.0f.xx.x, _15149.y > 100000.0f.xx.y)))
                        {
                            _21761 = false;
                            break;
                        }
                        float _15157 = length(_21760 * _7121);
                        uint _15372_dummy_parameter;
                        bool _15171 = _15157 > ((8.0f * _7121.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _15178;
                        if (_15171)
                        {
                            _15178 = length((r_motion_tp1.Load(int3(int2(floor(_5434 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15372_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7121) < (0.20000000298023223876953125f * _15157);
                        }
                        else
                        {
                            _15178 = _15171;
                        }
                        _21761 = _15178;
                        break;
                    } while(false);
                    _21763 = 2.0f;
                    _21762 = float3(clamp(length(_21754 * float2(cbFI_RenderSize)) * 0.25f, 0.0f, 1.0f), float(_21761), 0.0f);
                    break;
                }
                float _15406;
                float _15409;
                float4 _15419;
                float2 _21588;
                do
                {
                    _15406 = _5434.x;
                    _15409 = 1.0f - _5434.y;
                    _15419 = float4((float2(_15406, _15409) * 2.0f) - 1.0f.xx, 0.99999988079071044921875f, 1.0f);
                    float4 _15420 = mul(_15419, _21587);
                    float _15422 = _15420.w;
                    if (!(_15422 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21588 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15435 = ((_15420.xy / _15422.xx) + 1.0f.xx) * 0.5f;
                    _21588 = float2(_15435.x - _15406, _15409 - _15435.y);
                    break;
                } while(false);
                float2 _21589;
                do
                {
                    float4 _15472 = mul(_15419, _14620);
                    float _15474 = _15472.w;
                    if (!(_15474 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21589 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15487 = ((_15472.xy / _15474.xx) + 1.0f.xx) * 0.5f;
                    _21589 = float2(_15487.x - _15406, _15409 - _15487.y);
                    break;
                } while(false);
                float2 _14677 = abs(_21588);
                bool2 _23495 = any(bool2(_14677.x > 4.0f.xx.x, _14677.y > 4.0f.xx.y)).xx;
                float2 _14683 = abs(_21589);
                bool2 _23497 = any(bool2(_14683.x > 4.0f.xx.x, _14683.y > 4.0f.xx.y)).xx;
                float2 _15501[3];
                _15501[0] = _5434;
                float2 _15621 = clamp(_5434, 0.0f.xx, 1.0f.xx);
                uint _15629_dummy_parameter;
                _15501[1] = _5434 - ((r_motion_tp1.Load(int3(int2(floor(_15621 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15629_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5659);
                _15501[2] = _5434 - (float2(_23495.x ? 0.0f.xx.x : _21588.x, _23495.y ? 0.0f.xx.y : _21588.y) * _5659);
                float _21595;
                float2 _21596;
                _21596 = _5434;
                _21595 = 1000000000.0f;
                float _23499;
                float2 _23501;
                float _23502;
                int _21594 = 0;
                float _21743 = -1.0f;
                for (; _21594 < 3; _21743 = _23499, _21596 = _23501, _21595 = _23502, _21594++)
                {
                    float2 _21733;
                    _21733 = _15501[_21594];
                    for (int _21732 = 0; _21732 < 30; )
                    {
                        uint _16143_dummy_parameter;
                        _21733 += (((_5434 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_21733, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16143_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5659)) - _21733) * 0.699999988079071044921875f);
                        _21732++;
                        continue;
                    }
                    float2 _16573 = clamp(_21733, 0.0f.xx, 1.0f.xx);
                    uint _16581_dummy_parameter;
                    bool _17011 = all(bool2(_21733.x > 0.0f.xx.x, _21733.y > 0.0f.xx.y));
                    bool _17017;
                    if (_17011)
                    {
                        _17017 = all(bool2(_21733.x < 1.0f.xx.x, _21733.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17017 = _17011;
                    }
                    float _21735;
                    if (_17017)
                    {
                        _21735 = length(((_21733 + ((r_motion_tp1.Load(int3(int2(floor(_16573 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16581_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5659)) - _5434) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21735 = 1000000000.0f;
                    }
                    uint _17028_dummy_parameter;
                    float _17068 = log(((r_depth_tp1.Load(int3(int2(floor(_16573 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17028_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15581 = _21735 < 0.3499999940395355224609375f;
                    bool _15583 = _21595 < 0.3499999940395355224609375f;
                    bool _15593;
                    if (_15581)
                    {
                        _15593 = (!_15583) || (_17068 > _21743);
                    }
                    else
                    {
                        _15593 = _15581;
                    }
                    bool _15606;
                    if (!_15593)
                    {
                        _15606 = ((!_15581) && (!_15583)) && (_21735 < _21595);
                    }
                    else
                    {
                        _15606 = _15593;
                    }
                    _23499 = _15606 ? _17068 : _21743;
                    bool2 _23500 = _15606.xx;
                    _23501 = float2(_23500.x ? _21733.x : _21596.x, _23500.y ? _21733.y : _21596.y);
                    _23502 = _15606 ? _21735 : _21595;
                }
                float2 _17070[3];
                _17070[0] = _5434;
                float2 _21615;
                do
                {
                    bool _21605;
                    do
                    {
                        bool _17317 = all(bool2(_15621.x > 0.0f.xx.x, _15621.y > 0.0f.xx.y));
                        bool _17323;
                        if (_17317)
                        {
                            _17323 = all(bool2(_15621.x < 1.0f.xx.x, _15621.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17323 = _17317;
                        }
                        if (!_17323)
                        {
                            _21605 = false;
                            break;
                        }
                        uint _17330_dummy_parameter;
                        float4x4 _21603;
                        do
                        {
                            float4x4 _17344;
                            bool _21602;
                            do
                            {
                                _17344 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14862)
                                {
                                    _21602 = false;
                                    break;
                                }
                                uint _17378 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17378 + 32u) * 4 + 0) != 1u)
                                {
                                    _21602 = false;
                                    break;
                                }
                                uint _21599;
                                _21599 = 0u;
                                for (; _21599 < 4u; _21599++)
                                {
                                    for (uint _21600 = 0u; _21600 < 4u; )
                                    {
                                        _17344[_21599][_21600] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17378 + (_21599 * 4u)) + _21600) * 4 + 0));
                                        _21600++;
                                        continue;
                                    }
                                }
                                _21602 = true;
                                break;
                            } while(false);
                            if (_21602)
                            {
                                _21603 = _17344;
                                break;
                            }
                            _21603 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21604;
                        do
                        {
                            float _17455 = _15621.x;
                            float _17458 = 1.0f - _15621.y;
                            float4 _17469 = mul(float4((float2(_17455, _17458) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15621 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17330_dummy_parameter))))), 0)).x, 1.0f), _21603);
                            float _17471 = _17469.w;
                            if (!(_17471 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21604 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17484 = ((_17469.xy / _17471.xx) + 1.0f.xx) * 0.5f;
                            _21604 = float2(_17484.x - _17455, _17458 - _17484.y);
                            break;
                        } while(false);
                        float2 _17281 = abs(_21604);
                        if (any(bool2(_17281.x > 100000.0f.xx.x, _17281.y > 100000.0f.xx.y)))
                        {
                            _21605 = false;
                            break;
                        }
                        float _17289 = length(_21604 * _7121);
                        uint _17504_dummy_parameter;
                        bool _17303 = _17289 > ((8.0f * _7121.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17310;
                        if (_17303)
                        {
                            _17310 = length((r_motion_tp1.Load(int3(int2(floor(_15621 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17504_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7121) < (0.20000000298023223876953125f * _17289);
                        }
                        else
                        {
                            _17310 = _17303;
                        }
                        _21605 = _17310;
                        break;
                    } while(false);
                    if (_21605)
                    {
                        uint _17535_dummy_parameter;
                        _21615 = -(r_motion_tp1.Load(int3(int2(floor(_15621 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17535_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17562_dummy_parameter;
                    float2 _21614;
                    do
                    {
                        float _17581 = _15621.x;
                        float _17584 = 1.0f - _15621.y;
                        float4 _17595 = mul(float4((float2(_17581, _17584) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15621 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17562_dummy_parameter))))), 0)).x, 1.0f), _14620);
                        float _17597 = _17595.w;
                        if (!(_17597 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21614 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17610 = ((_17595.xy / _17597.xx) + 1.0f.xx) * 0.5f;
                        _21614 = float2(_17610.x - _17581, _17584 - _17610.y);
                        break;
                    } while(false);
                    float2 _17248 = abs(_21614);
                    bool2 _17252 = any(bool2(_17248.x > 4.0f.xx.x, _17248.y > 4.0f.xx.y)).xx;
                    _21615 = float2(_17252.x ? 0.0f.xx.x : _21614.x, _17252.y ? 0.0f.xx.y : _21614.y);
                    break;
                } while(false);
                _17070[1] = _5434 - (_21615 * cbFI_Timestep);
                _17070[2] = _5434 - (float2(_23497.x ? 0.0f.xx.x : _21589.x, _23497.y ? 0.0f.xx.y : _21589.y) * cbFI_Timestep);
                float _21617;
                float2 _21618;
                _21618 = _5434;
                _21617 = 1000000000.0f;
                float _23503;
                float2 _23505;
                float _23506;
                float4x4 _17858;
                float4x4 _18296;
                int _21616 = 0;
                float _21670 = -1.0f;
                for (; _21616 < 3; _21670 = _23503, _21618 = _23505, _21617 = _23506, _21616++)
                {
                    float2 _21620;
                    _21620 = _17070[_21616];
                    float2 _17667;
                    for (int _21619 = 0; _21619 < 30; _21620 = _17667, _21619++)
                    {
                        float2 _21711;
                        do
                        {
                            float2 _17747 = clamp(_21620, 0.0f.xx, 1.0f.xx);
                            bool _21701;
                            do
                            {
                                bool _17831 = all(bool2(_17747.x > 0.0f.xx.x, _17747.y > 0.0f.xx.y));
                                bool _17837;
                                if (_17831)
                                {
                                    _17837 = all(bool2(_17747.x < 1.0f.xx.x, _17747.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17837 = _17831;
                                }
                                if (!_17837)
                                {
                                    _21701 = false;
                                    break;
                                }
                                uint _17844_dummy_parameter;
                                float4x4 _21699;
                                do
                                {
                                    bool _21698;
                                    do
                                    {
                                        _17858 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14862)
                                        {
                                            _21698 = false;
                                            break;
                                        }
                                        uint _17892 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17892 + 32u) * 4 + 0) != 1u)
                                        {
                                            _21698 = false;
                                            break;
                                        }
                                        uint _21695;
                                        _21695 = 0u;
                                        for (; _21695 < 4u; _21695++)
                                        {
                                            for (uint _21696 = 0u; _21696 < 4u; )
                                            {
                                                _17858[_21695][_21696] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17892 + (_21695 * 4u)) + _21696) * 4 + 0));
                                                _21696++;
                                                continue;
                                            }
                                        }
                                        _21698 = true;
                                        break;
                                    } while(false);
                                    if (_21698)
                                    {
                                        _21699 = _17858;
                                        break;
                                    }
                                    _21699 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _21700;
                                do
                                {
                                    float _17969 = _17747.x;
                                    float _17972 = 1.0f - _17747.y;
                                    float4 _17983 = mul(float4((float2(_17969, _17972) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17747 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17844_dummy_parameter))))), 0)).x, 1.0f), _21699);
                                    float _17985 = _17983.w;
                                    if (!(_17985 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _21700 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _17998 = ((_17983.xy / _17985.xx) + 1.0f.xx) * 0.5f;
                                    _21700 = float2(_17998.x - _17969, _17972 - _17998.y);
                                    break;
                                } while(false);
                                float2 _17795 = abs(_21700);
                                if (any(bool2(_17795.x > 100000.0f.xx.x, _17795.y > 100000.0f.xx.y)))
                                {
                                    _21701 = false;
                                    break;
                                }
                                float _17803 = length(_21700 * _7121);
                                uint _18018_dummy_parameter;
                                bool _17817 = _17803 > ((8.0f * _7121.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17824;
                                if (_17817)
                                {
                                    _17824 = length((r_motion_tp1.Load(int3(int2(floor(_17747 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18018_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7121) < (0.20000000298023223876953125f * _17803);
                                }
                                else
                                {
                                    _17824 = _17817;
                                }
                                _21701 = _17824;
                                break;
                            } while(false);
                            if (_21701)
                            {
                                uint _18049_dummy_parameter;
                                _21711 = -(r_motion_tp1.Load(int3(int2(floor(_17747 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18049_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _18076_dummy_parameter;
                            float2 _21710;
                            do
                            {
                                float _18095 = _17747.x;
                                float _18098 = 1.0f - _17747.y;
                                float4 _18109 = mul(float4((float2(_18095, _18098) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17747 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18076_dummy_parameter))))), 0)).x, 1.0f), _14620);
                                float _18111 = _18109.w;
                                if (!(_18111 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21710 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18124 = ((_18109.xy / _18111.xx) + 1.0f.xx) * 0.5f;
                                _21710 = float2(_18124.x - _18095, _18098 - _18124.y);
                                break;
                            } while(false);
                            float2 _17762 = abs(_21710);
                            bool2 _17766 = any(bool2(_17762.x > 4.0f.xx.x, _17762.y > 4.0f.xx.y)).xx;
                            _21711 = float2(_17766.x ? 0.0f.xx.x : _21710.x, _17766.y ? 0.0f.xx.y : _21710.y);
                            break;
                        } while(false);
                        _17667 = _21620 + (((_5434 - (_21711 * cbFI_Timestep)) - _21620) * 0.699999988079071044921875f);
                    }
                    float2 _18185;
                    float2 _21637;
                    do
                    {
                        _18185 = clamp(_21620, 0.0f.xx, 1.0f.xx);
                        bool _21627;
                        do
                        {
                            bool _18269 = all(bool2(_18185.x > 0.0f.xx.x, _18185.y > 0.0f.xx.y));
                            bool _18275;
                            if (_18269)
                            {
                                _18275 = all(bool2(_18185.x < 1.0f.xx.x, _18185.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18275 = _18269;
                            }
                            if (!_18275)
                            {
                                _21627 = false;
                                break;
                            }
                            uint _18282_dummy_parameter;
                            float4x4 _21625;
                            do
                            {
                                bool _21624;
                                do
                                {
                                    _18296 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14862)
                                    {
                                        _21624 = false;
                                        break;
                                    }
                                    uint _18330 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18330 + 32u) * 4 + 0) != 1u)
                                    {
                                        _21624 = false;
                                        break;
                                    }
                                    uint _21621;
                                    _21621 = 0u;
                                    for (; _21621 < 4u; _21621++)
                                    {
                                        for (uint _21622 = 0u; _21622 < 4u; )
                                        {
                                            _18296[_21621][_21622] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18330 + (_21621 * 4u)) + _21622) * 4 + 0));
                                            _21622++;
                                            continue;
                                        }
                                    }
                                    _21624 = true;
                                    break;
                                } while(false);
                                if (_21624)
                                {
                                    _21625 = _18296;
                                    break;
                                }
                                _21625 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _21626;
                            do
                            {
                                float _18410 = 1.0f - _18185.y;
                                float4 _18421 = mul(float4((float2(_18185.x, _18410) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18185 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18282_dummy_parameter))))), 0)).x, 1.0f), _21625);
                                float _18423 = _18421.w;
                                if (!(_18423 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21626 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18436 = ((_18421.xy / _18423.xx) + 1.0f.xx) * 0.5f;
                                _21626 = float2(_18436.x - _18185.x, _18410 - _18436.y);
                                break;
                            } while(false);
                            float2 _18233 = abs(_21626);
                            if (any(bool2(_18233.x > 100000.0f.xx.x, _18233.y > 100000.0f.xx.y)))
                            {
                                _21627 = false;
                                break;
                            }
                            float _18241 = length(_21626 * _7121);
                            uint _18456_dummy_parameter;
                            bool _18255 = _18241 > ((8.0f * _7121.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18262;
                            if (_18255)
                            {
                                _18262 = length((r_motion_tp1.Load(int3(int2(floor(_18185 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18456_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7121) < (0.20000000298023223876953125f * _18241);
                            }
                            else
                            {
                                _18262 = _18255;
                            }
                            _21627 = _18262;
                            break;
                        } while(false);
                        if (_21627)
                        {
                            uint _18487_dummy_parameter;
                            _21637 = -(r_motion_tp1.Load(int3(int2(floor(_18185 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18487_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18514_dummy_parameter;
                        float2 _21636;
                        do
                        {
                            float _18536 = 1.0f - _18185.y;
                            float4 _18547 = mul(float4((float2(_18185.x, _18536) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18185 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18514_dummy_parameter))))), 0)).x, 1.0f), _14620);
                            float _18549 = _18547.w;
                            if (!(_18549 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21636 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18562 = ((_18547.xy / _18549.xx) + 1.0f.xx) * 0.5f;
                            _21636 = float2(_18562.x - _18185.x, _18536 - _18562.y);
                            break;
                        } while(false);
                        float2 _18200 = abs(_21636);
                        bool2 _18204 = any(bool2(_18200.x > 4.0f.xx.x, _18200.y > 4.0f.xx.y)).xx;
                        _21637 = float2(_18204.x ? 0.0f.xx.x : _21636.x, _18204.y ? 0.0f.xx.y : _21636.y);
                        break;
                    } while(false);
                    bool _18580 = all(bool2(_21620.x > 0.0f.xx.x, _21620.y > 0.0f.xx.y));
                    bool _18586;
                    if (_18580)
                    {
                        _18586 = all(bool2(_21620.x < 1.0f.xx.x, _21620.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18586 = _18580;
                    }
                    float _21649;
                    if (_18586)
                    {
                        _21649 = length(((_21620 + (_21637 * cbFI_Timestep)) - _5434) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21649 = 1000000000.0f;
                    }
                    uint _18613_dummy_parameter;
                    float _18637 = log(((r_depth_tm1.Load(int3(int2(floor(_18185 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18613_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f;
                    bool _17150 = _21649 < 0.3499999940395355224609375f;
                    bool _17152 = _21617 < 0.3499999940395355224609375f;
                    bool _17162;
                    if (_17150)
                    {
                        _17162 = (!_17152) || (_18637 > _21670);
                    }
                    else
                    {
                        _17162 = _17150;
                    }
                    bool _17175;
                    if (!_17162)
                    {
                        _17175 = ((!_17150) && (!_17152)) && (_21649 < _21617);
                    }
                    else
                    {
                        _17175 = _17162;
                    }
                    _23503 = _17175 ? _18637 : _21670;
                    bool2 _23504 = _17175.xx;
                    _23505 = float2(_23504.x ? _21620.x : _21618.x, _23504.y ? _21620.y : _21618.y);
                    _23506 = _17175 ? _21649 : _21617;
                }
                float3 _18646 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21596, 0.0f).xyz;
                float3 _18654 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21618, 0.0f).xyz;
                uint _18661_dummy_parameter;
                uint _18692_dummy_parameter;
                float _14723 = exp((_21595 * (-2.0f)) * (_21595 * 2.0f));
                float _14730 = exp((_21617 * (-2.0f)) * (_21617 * 2.0f));
                float _14743 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21618, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18692_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21596, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18661_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14757 = ((_14723 * cbFI_Timestep) * ((1.0f - _14730) + ((_14730 * 2.0f) * _14743))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14767 = 1.0f - _14743;
                float _14774 = ((_14730 * _5659) * ((1.0f - _14723) + ((_14723 * 2.0f) * _14767))) + (9.9999997473787516355514526367188e-05f * _5659);
                float _14783 = (((_14723 * _14730) * 4.0f) * _14743) * _14767;
                float _14801 = (_14783 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18654 - _18646, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14783)) * max(_14723, _14730));
                if (_6807 == 30u)
                {
                    _21763 = _14801;
                    _21762 = _18646;
                    break;
                }
                if (_6807 == 31u)
                {
                    _21763 = _14801;
                    _21762 = _18654;
                    break;
                }
                if (_6807 == 32u)
                {
                    _21763 = _14801;
                    _21762 = float3(_14723, _14730, _14743);
                    break;
                }
                _21763 = _14801;
                _21762 = ((_18646 * _14757) + (_18654 * _14774)) / (_14757 + _14774).xxx;
                break;
            } while(false);
            _23201 = _21763;
            _23125 = _21762;
        }
        else
        {
            _23201 = 1.0f;
            _23125 = _23126;
        }
        uint _7137 = cbFI_pad0 & 255u;
        bool _22932;
        float3 _23124;
        if (_7137 != 0u)
        {
            float3 _7142 = r_present_backbuffer.Load(int3(_4935, 0)).xyz;
            float3 _7146 = r_current_interpolation_source.Load(int3(_4935, 0)).xyz;
            float3 _7150 = abs(_7142 - _7146);
            float3 _21772;
            if (_7137 == 2u)
            {
                _21772 = (abs(_7146) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21772 = 0.000244140625f.xxx;
            }
            bool _7166 = any(bool3(_7150.x > _21772.x, _7150.y > _21772.y, _7150.z > _21772.z));
            bool3 _23507 = _7166.xxx;
            _23124 = float3(_23507.x ? _7142.x : _23125.x, _23507.y ? _7142.y : _23125.y, _23507.z ? _7142.z : _23125.z);
            _22932 = _7166;
        }
        else
        {
            _23124 = _23125;
            _22932 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18730;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18730);
        }
        float3 _23106;
        if (_6807 == 1u)
        {
            _23106 = lerp(_8639, _8647, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _23107;
            if (_6807 == 2u)
            {
                _23107 = lerp(_8655, _8663, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _23108;
                if (_6807 == 3u)
                {
                    _23108 = float(_22932).xxx;
                }
                else
                {
                    float3 _23109;
                    if (_6807 == 4u)
                    {
                        _23109 = float3(((_19665 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _23110;
                        if (_6807 == 5u)
                        {
                            _23110 = float3(((_7934 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _23111;
                            if (_6807 == 6u)
                            {
                                _23111 = float3(_21171.xy, _21171.z + _21171.w);
                            }
                            else
                            {
                                float3 _23112;
                                if (_6807 == 7u)
                                {
                                    _23112 = r_current_interpolation_source.Load(int3(_4935, 0)).xyz;
                                }
                                else
                                {
                                    float3 _23113;
                                    if (_6807 == 8u)
                                    {
                                        _23113 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5434, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _23114;
                                        if (_6811)
                                        {
                                            uint _18752_dummy_parameter;
                                            uint _18784_dummy_parameter;
                                            _23114 = float3(log(((r_depth_tp1.Load(int3(int2(floor(_5434 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18752_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, log(((r_depth_tm1.Load(int3(int2(floor(_5434 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18784_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _23115;
                                            if (_6814)
                                            {
                                                _23115 = _8655;
                                            }
                                            else
                                            {
                                                float3 _23116;
                                                if (_6807 == 20u)
                                                {
                                                    _23116 = _8639;
                                                }
                                                else
                                                {
                                                    float3 _23117;
                                                    if (_6807 == 21u)
                                                    {
                                                        _23117 = _8647;
                                                    }
                                                    else
                                                    {
                                                        float3 _23118;
                                                        if (_6807 == 22u)
                                                        {
                                                            _23118 = _8663;
                                                        }
                                                        else
                                                        {
                                                            float3 _23119;
                                                            if (_6807 == 18u)
                                                            {
                                                                _23119 = _22380;
                                                            }
                                                            else
                                                            {
                                                                float3 _23120;
                                                                if (_6807 == 19u)
                                                                {
                                                                    _23120 = _22077;
                                                                }
                                                                else
                                                                {
                                                                    float3 _23121;
                                                                    if (_6807 == 23u)
                                                                    {
                                                                        _23121 = _21780;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _23122;
                                                                        if (_6807 == 24u)
                                                                        {
                                                                            uint _7310 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7315 = float(rw_nfru_diagnostics.Load<uint>((_7310 + 35u) * 4 + 0));
                                                                            float _21773;
                                                                            if (_7315 > 0.0f)
                                                                            {
                                                                                _21773 = float(rw_nfru_diagnostics.Load<uint>((_7310 + 34u) * 4 + 0)) / _7315;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21773 = 0.0f;
                                                                            }
                                                                            _23122 = float3(float(rw_nfru_diagnostics.Load<uint>((_7310 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7310 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21773);
                                                                        }
                                                                        else
                                                                        {
                                                                            _23122 = _23124;
                                                                        }
                                                                        _23121 = _23122;
                                                                    }
                                                                    _23120 = _23121;
                                                                }
                                                                _23119 = _23120;
                                                            }
                                                            _23118 = _23119;
                                                        }
                                                        _23117 = _23118;
                                                    }
                                                    _23116 = _23117;
                                                }
                                                _23115 = _23116;
                                            }
                                            _23114 = _23115;
                                        }
                                        _23113 = _23114;
                                    }
                                    _23112 = _23113;
                                }
                                _23111 = _23112;
                            }
                            _23110 = _23111;
                        }
                        _23109 = _23110;
                    }
                    _23108 = _23109;
                }
                _23107 = _23108;
            }
            _23106 = _23107;
        }
        float3 _23105;
        if ((_6807 >= 9u) && (_6807 <= 11u))
        {
            uint _7375 = 64u + uint((_19888.y * cbFI_MvDepthLaneSize.x) + _19888.x);
            uint _7379 = rw_nfru_diagnostics.Load<uint>(_7375 * 4 + 0) & 15u;
            float3 _23139;
            if (_6807 == 10u)
            {
                float3 _23104;
                if ((rw_nfru_diagnostics.Load<uint>(_7375 * 4 + 0) & 32u) != 0u)
                {
                    _23104 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _23103;
                    if ((rw_nfru_diagnostics.Load<uint>(_7375 * 4 + 0) & 16u) != 0u)
                    {
                        _23103 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7400 = ((rw_nfru_diagnostics.Load<uint>(_7375 * 4 + 0) & 64u) != 0u).xxx;
                        _23103 = float3(_7400.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7400.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7400.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _23104 = _23103;
                }
                _23139 = _23104;
            }
            else
            {
                float3 _23140;
                if (_6807 == 11u)
                {
                    uint _7413 = (rw_nfru_diagnostics.Load<uint>(_7375 * 4 + 0) >> 8u) & 15u;
                    uint _7416 = (rw_nfru_diagnostics.Load<uint>(_7375 * 4 + 0) >> 12u) & 15u;
                    float3 _23096;
                    if ((_7379 == 2u) || (_7379 == 3u))
                    {
                        _23096 = _4634[_7379];
                    }
                    else
                    {
                        bool _7428 = _7413 == 3u;
                        bool _7430 = _7416 == 3u;
                        float3 _23097;
                        if (_7428 && _7430)
                        {
                            _23097 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _23098;
                            if (_7428)
                            {
                                _23098 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _23099;
                                if (_7430)
                                {
                                    _23099 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _23100;
                                    if ((_7413 == 4u) || (_7416 == 4u))
                                    {
                                        _23100 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _23101;
                                        if ((_7413 == 1u) || (_7416 == 1u))
                                        {
                                            _23101 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23509 = (_7379 == 1u).xxx;
                                            _23101 = float3(_23509.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23509.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23509.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _23100 = _23101;
                                    }
                                    _23099 = _23100;
                                }
                                _23098 = _23099;
                            }
                            _23097 = _23098;
                        }
                        _23096 = _23097;
                    }
                    _23140 = _23096;
                }
                else
                {
                    _23140 = _4634[min(_7379, 7u)];
                }
                _23139 = _23140;
            }
            _23105 = _23139;
        }
        else
        {
            _23105 = _23106;
        }
        float4 _23143;
        if ((_6807 >= 14u) && (_6807 <= 16u))
        {
            float2 _23141;
            if (_6807 == 14u)
            {
                uint _7486_dummy_parameter;
                uint _7492_dummy_parameter;
                _23141 = r_flow_tm1.Load(int3(clamp(int2(floor(_5434 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7486_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7492_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _23142;
                if (_6807 == 16u)
                {
                    uint _18860 = r_warped_flow_qdata_tm1.Load(int3(_5450, 0)).x & 2147483647u;
                    uint _18892 = uint(max((int((_18860 >> 16u) & 15u) - 6), 0));
                    _23142 = ((float2(float((1 - (2 * int((_18860 >> 15u) & 1u))) * int(((_18860 >> uint(7)) & 127u) << _18892)), float((1 - (2 * int((_18860 >> 14u) & 1u))) * int((_18860 & 127u) << _18892))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _23142 = _7934 * float2(cbFI_DisplaySize);
                }
                _23141 = _23142;
            }
            uint2 _7525 = uint2(clamp(round(_23141 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7527 = _7525.x;
            uint _7534 = _7525.y;
            _23143 = float4(float(_7527 & 255u), float((_7527 >> 8u) | ((_7534 & 15u) << 4u)), float(_7534 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _23144;
            if (_6807 == 17u)
            {
                _23144 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5450, 0)).x != 0u), _5894, 0.0f, 1.0f);
            }
            else
            {
                _23144 = float4(_23105, 1.0f);
            }
            _23143 = _23144;
        }
        rw_output[_4935] = _23143.xyz;
        if (_7117)
        {
            uint _18937 = uint((_4935.y * cbFI_DisplaySize.x) + _4935.x) * 2u;
            rw_nfru_select.Store<uint>(_18937 * 4 + 0, spvPackHalf2x16(_23143.xy));
            rw_nfru_select.Store<uint>((_18937 + 1u) * 4 + 0, spvPackHalf2x16(float2(_23143.z, (_22932 || (_6807 != 0u)) ? 2.0f : _23201)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7592 = ((uint(_4935.y) * uint(cbFI_DisplaySize.x)) + uint(_4935.x)) * 6u;
            uint _18963 = spvPackHalf2x16(clamp(_8638.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7592 * 4 + 0, (((_18963 & 32767u) >> 4u) | ((((_18963 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8638.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _18998 = spvPackHalf2x16(clamp(_8646.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7592 + 1u) * 4 + 0, (((_18998 & 32767u) >> 4u) | ((((_18998 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8646.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19033 = spvPackHalf2x16(clamp(_8654.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7592 + 2u) * 4 + 0, (((_19033 & 32767u) >> 4u) | ((((_19033 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8654.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19068 = spvPackHalf2x16(clamp(_8662.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7592 + 3u) * 4 + 0, (((_19068 & 32767u) >> 4u) | ((((_19068 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8662.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19095 = r_current_interpolation_source.Load(int3(_4935, 0));
            uint _19109 = spvPackHalf2x16(clamp(_19095.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7592 + 4u) * 4 + 0, (((_19109 & 32767u) >> 4u) | ((((_19109 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19095.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _23220;
            if (_22932 || (_6807 != 0u))
            {
                _23220 = 4294967295u;
            }
            else
            {
                uint _19144 = spvPackHalf2x16(clamp(_23143.xy, 0.0f.xx, 65000.0f.xx));
                _23220 = (((_19144 & 32767u) >> 4u) | ((((_19144 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_23143.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7592 + 5u) * 4 + 0, _23220);
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
