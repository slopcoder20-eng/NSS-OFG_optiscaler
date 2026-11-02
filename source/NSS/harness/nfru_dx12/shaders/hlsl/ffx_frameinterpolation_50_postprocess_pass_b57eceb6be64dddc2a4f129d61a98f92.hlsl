static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);
static float _19717;

static const int2 _1251[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1260[5] = { 2, 4, 7, 11, 16 };
static const float3 _4652[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _4970 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_4970.x >= cbFI_DisplaySize.x, _4970.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_4970] = float4(r_present_backbuffer.Load(int3(_4970, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_4970] = float4(r_current_interpolation_source.Load(int3(_4970, 0)).xyz, 1.0f).xyz;
            break;
        }
        if ((cbFI_NfruT2Flags & 4194304u) != 0u)
        {
            do
            {
                int2 _7860 = cbFI_DisplaySize - int2(1, 1);
                int2 _7861 = clamp(_4970, int2(0, 0), _7860);
                uint _7871 = uint((_7861.y * cbFI_DisplaySize.x) + _7861.x) * 2u;
                uint _7874 = rw_nfru_select.Load<uint>(_7871 * 4 + 0);
                float2 _7875 = spvUnpackHalf2x16(_7874);
                uint _7879 = rw_nfru_select.Load<uint>((_7871 + 1u) * 4 + 0);
                float2 _7880 = spvUnpackHalf2x16(_7879);
                float _7881 = _7875.x;
                float _7883 = _7880.x;
                if (_7880.y > 1.5f)
                {
                    rw_output[_4970] = float4(_7881, _7875.y, _7883, 1.0f).xyz;
                    break;
                }
                int _23336;
                float _23337;
                float3 _23338;
                float _23339;
                float _23340;
                _23340 = 0.0f;
                _23339 = 0.0f;
                _23338 = 0.0f.xxx;
                _23337 = 0.0f;
                _23336 = -2;
                float3 _23343;
                float _23344;
                float _23345;
                float _23346;
                for (; _23336 <= 2; _23340 = _23346, _23339 = _23345, _23338 = _23343, _23337 = _23344, _23336++)
                {
                    _23346 = _23340;
                    _23345 = _23339;
                    _23344 = _23337;
                    _23343 = _23338;
                    for (int _23341 = -2; _23341 <= 2; )
                    {
                        float _7777 = float((_23341 * _23341) + (_23336 * _23336));
                        float _7782 = exp(_7777 * (-0.319999992847442626953125f));
                        int2 _7787 = int2(_23341, _23336);
                        int2 _7897 = clamp(_4970 + (_7787 * int2(2, 2)), int2(0, 0), _7860);
                        uint _7907 = uint((_7897.y * cbFI_DisplaySize.x) + _7897.x) * 2u;
                        float _7804 = exp(_7777 * (-0.5f));
                        int2 _7929 = clamp(_4970 + (_7787 * int2(6, 6)), int2(0, 0), _7860);
                        _23346 += _7804;
                        _23345 += (_7804 * min(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(((uint((_7929.y * cbFI_DisplaySize.x) + _7929.x) * 2u) + 1u) * 4 + 0)).y, 1.0f));
                        _23344 += _7782;
                        _23343 += (float4(spvUnpackHalf2x16(rw_nfru_select.Load<uint>(_7907 * 4 + 0)), spvUnpackHalf2x16(rw_nfru_select.Load<uint>((_7907 + 1u) * 4 + 0)).x, _19717).xyz * _7782);
                        _23341++;
                        continue;
                    }
                }
                float3 _7834 = _23338 / _23337.xxx;
                rw_output[_4970] = float4(_7834 + ((float4(_7881, _7875.y, _7883, _7880.y).xyz - _7834) * clamp(_23339 / _23340, 0.0f, 1.0f)), 1.0f).xyz;
                break;
            } while(false);
            break;
        }
        float2 _5482 = (float2(_4970) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        float2 _5484 = float2(cbFI_MvDepthLaneSize);
        int2 _5493 = int2(floor(_5482 * _5484));
        int2 _5498 = int2(floor(_5482 * float2(cbFI_FlowLaneSize)));
        float4 _8000 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_5482 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _8006 = r_warped_filled_flow_tm1.Load(int3(_5498, 0)).xy;
        float2 _8012 = r_warped_filled_motion_tp1.Load(int3(_5493, 0)).xy;
        bool _8034 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _19718;
        if (_8034)
        {
            float _8047 = ((2.0f * _5482.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _19718 = float2(atan(_8047) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _5482.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_8047 * _8047))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _19718 = _5482;
        }
        bool _5519 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _19739;
        bool _19881;
        int2 _19962;
        float3 _22454;
        if (_5519)
        {
            float _19720;
            float _19722;
            _19722 = 2.0f;
            _19720 = -1.0f;
            uint _5069[9];
            float _23347;
            float _23350;
            for (int _19719 = 0; _19719 < 9; _19722 = _23350, _19720 = _23347, _19719++)
            {
                _5069[_19719] = r_warped_motion_qdata_tp1.Load(int3(clamp(_5493 + int2((_19719 % 3) - 1, (_19719 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_5069[_19719] != 0u)
                {
                    float _23331;
                    if (_5069[_19719] == 0u)
                    {
                        _23331 = -1.0f;
                    }
                    else
                    {
                        _23331 = float((_5069[_19719] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _23350 = min(_19722, _23331);
                    _23347 = max(_19720, _23331);
                }
                else
                {
                    _23350 = _19722;
                    _23347 = _19720;
                }
            }
            float _5565 = float(_19720 >= 0.0f);
            float3 _19260 = 0.0f.xxx;
            _19260.y = _5565;
            float2 _19740;
            bool _19882;
            int2 _19963;
            float3 _22455;
            if ((_19720 - _19722) > 0.0199999995529651641845703125f)
            {
                float _19728;
                int2 _19729;
                float2 _19730;
                int2 _19732;
                float2 _19738;
                _19738 = _8012;
                _19732 = _5493;
                _19730 = _8012;
                _19729 = _5493;
                _19728 = -1.0f;
                float _23355;
                int2 _23359;
                float2 _23370;
                int2 _23381;
                float2 _23414;
                float _23539;
                int _19727 = 0;
                float _23312 = 1000000000.0f;
                for (; _19727 < 9; _23312 = _23539, _19738 = _23414, _19732 = _23381, _19730 = _23370, _19729 = _23359, _19728 = _23355, _19727++)
                {
                    if (_5069[_19727] == 0u)
                    {
                        _23539 = _23312;
                        _23414 = _19738;
                        _23381 = _19732;
                        _23370 = _19730;
                        _23359 = _19729;
                        _23355 = _19728;
                        continue;
                    }
                    int2 _5600 = clamp(_5493 + int2((_19727 % 3) - 1, (_19727 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _8122 = _5069[_19727] & 2147483647u;
                    uint _8154 = uint(max((int((_8122 >> 16u) & 15u) - 6), 0));
                    float2 _5606 = (float2(float((1 - (2 * int((_8122 >> 15u) & 1u))) * int(((_8122 >> uint(7)) & 127u) << _8154)), float((1 - (2 * int((_8122 >> 14u) & 1u))) * int((_8122 & 127u) << _8154))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _23298;
                    if (_5069[_19727] == 0u)
                    {
                        _23298 = -1.0f;
                    }
                    else
                    {
                        _23298 = float((_5069[_19727] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _5611 = _23298 - 0.100000001490116119384765625f;
                    float2 _23299;
                    if (_8034)
                    {
                        float2 _8231 = clamp((((_19718 + (_5606 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8234 = tan(_8231.x);
                        _23299 = (float2(_8234 / cbFI_DeviceToViewDepth.z, (tan(_8231.y) * sqrt(1.0f + (_8234 * _8234))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23299 = _19718 + (_5606 * cbFI_Timestep);
                    }
                    float _5618 = cbFI_Timestep - 1.0f;
                    float2 _23300;
                    if (_8034)
                    {
                        float2 _8302 = clamp((((_19718 + (_5606 * _5618)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _8305 = tan(_8302.x);
                        _23300 = (float2(_8305 / cbFI_DeviceToViewDepth.z, (tan(_8302.y) * sqrt(1.0f + (_8305 * _8305))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _23300 = _19718 + (_5606 * _5618);
                    }
                    bool _8338 = all(bool2(_23299.x > 0.0f.xx.x, _23299.y > 0.0f.xx.y));
                    bool _8344;
                    if (_8338)
                    {
                        _8344 = all(bool2(_23299.x < 1.0f.xx.x, _23299.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8344 = _8338;
                    }
                    float _23303;
                    if (_8344)
                    {
                        uint _8351_dummy_parameter;
                        _23303 = max((_5611 - (log((r_depth_tm1.Load(int3(int2(floor(_23299 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8351_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23303 = 0.0f;
                    }
                    bool _8381 = all(bool2(_23300.x > 0.0f.xx.x, _23300.y > 0.0f.xx.y));
                    bool _8387;
                    if (_8381)
                    {
                        _8387 = all(bool2(_23300.x < 1.0f.xx.x, _23300.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8387 = _8381;
                    }
                    float _23304;
                    if (_8387)
                    {
                        uint _8394_dummy_parameter;
                        _23304 = _23303 + max((_5611 - (log((r_depth_tp1.Load(int3(int2(floor(_23300 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8394_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _23304 = _23303;
                    }
                    float _23356;
                    int2 _23360;
                    float2 _23371;
                    int2 _23382;
                    float2 _23415;
                    float _23540;
                    if (_23304 == 0.0f)
                    {
                        bool _5653 = _5611 > _19728;
                        bool2 _23548 = _5653.xx;
                        _23540 = _23312;
                        _23415 = float2(_23548.x ? _5606.x : _19738.x, _23548.y ? _5606.y : _19738.y);
                        _23382 = int2(_23548.x ? _5600.x : _19732.x, _23548.y ? _5600.y : _19732.y);
                        _23371 = _19730;
                        _23360 = _19729;
                        _23356 = _5653 ? _5611 : _19728;
                    }
                    else
                    {
                        bool _5662 = _23304 < _23312;
                        bool2 _23544 = _5662.xx;
                        _23540 = _5662 ? _23304 : _23312;
                        _23415 = _19738;
                        _23382 = _19732;
                        _23371 = float2(_23544.x ? _5606.x : _19730.x, _23544.y ? _5606.y : _19730.y);
                        _23360 = int2(_23544.x ? _5600.x : _19729.x, _23544.y ? _5600.y : _19729.y);
                        _23356 = _19728;
                    }
                    _23539 = _23540;
                    _23414 = _23415;
                    _23381 = _23382;
                    _23370 = _23371;
                    _23359 = _23360;
                    _23355 = _23356;
                }
                bool _5674 = _19728 < 0.0f;
                bool2 _23554 = _5674.xx;
                int2 _23557 = int2(_23554.x ? _19729.x : _19732.x, _23554.y ? _19729.y : _19732.y);
                _22455 = float3(1.0f, _5565, float(any(bool2(_23557.x != _5493.x, _23557.y != _5493.y))));
                _19963 = _23557;
                _19882 = _5674 ? false : true;
                _19740 = float2(_23554.x ? _19730.x : _19738.x, _23554.y ? _19730.y : _19738.y);
            }
            else
            {
                _22455 = _19260;
                _19963 = _5493;
                _19882 = false;
                _19740 = _8012;
            }
            _22454 = _22455;
            _19962 = _19963;
            _19881 = _19882;
            _19739 = _19740;
        }
        else
        {
            _22454 = 0.0f.xxx;
            _19962 = _5493;
            _19881 = false;
            _19739 = _8012;
        }
        float2 _19741;
        if (_8034)
        {
            float2 _8459 = clamp((((_19718 + (_19739 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8462 = tan(_8459.x);
            _19741 = (float2(_8462 / cbFI_DeviceToViewDepth.z, (tan(_8459.y) * sqrt(1.0f + (_8462 * _8462))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19741 = _19718 + (_19739 * cbFI_Timestep);
        }
        float _5697 = cbFI_Timestep - 1.0f;
        float2 _19743;
        if (_8034)
        {
            float2 _8530 = clamp((((_19718 + (_19739 * _5697)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8533 = tan(_8530.x);
            _19743 = (float2(_8533 / cbFI_DeviceToViewDepth.z, (tan(_8530.y) * sqrt(1.0f + (_8533 * _8533))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19743 = _19718 + (_19739 * _5697);
        }
        float _5702 = -cbFI_Timestep;
        float2 _19744;
        if (_8034)
        {
            float2 _8601 = clamp((((_19718 + (_8006 * _5702)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8604 = tan(_8601.x);
            _19744 = (float2(_8604 / cbFI_DeviceToViewDepth.z, (tan(_8601.y) * sqrt(1.0f + (_8604 * _8604))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19744 = _19718 + (_8006 * _5702);
        }
        float _5707 = 1.0f - cbFI_Timestep;
        float2 _19745;
        if (_8034)
        {
            float2 _8672 = clamp((((_19718 + (_8006 * _5707)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _8675 = tan(_8672.x);
            _19745 = (float2(_8675 / cbFI_DeviceToViewDepth.z, (tan(_8672.y) * sqrt(1.0f + (_8675 * _8675))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _19745 = _19718 + (_8006 * _5707);
        }
        float4 _8710 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19741, 0.0f);
        float3 _8711 = _8710.xyz;
        float4 _8718 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19743, 0.0f);
        float3 _8719 = _8718.xyz;
        float4 _8726 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _19744, 0.0f);
        float3 _8727 = _8726.xyz;
        float4 _8734 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _19745, 0.0f);
        float3 _8735 = _8734.xyz;
        float4 _8749 = exp(_8000 - max(max(max(_8000.x, _8000.y), _8000.z), _8000.w).xxxx);
        float4 _8756 = _8749 / (dot(_8749, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _5723 = (cbFI_NfruT2Flags & 262144u) != 0u;
        float4 _19952;
        float _21260;
        if (_5723)
        {
            float2 _5729 = 0.5f.xx / _5484;
            float _5732 = _5729.x;
            float _5733 = -_5732;
            float _5735 = _5729.y;
            float _5736 = -_5735;
            float2 _5738 = _5482 + float2(_5733, _5736);
            float2 _5740 = float2(cbFI_DisplaySize);
            bool _19762;
            do
            {
                bool _8836 = all(bool2(_5738.x > 0.0f.xx.x, _5738.y > 0.0f.xx.y));
                bool _8842;
                if (_8836)
                {
                    _8842 = all(bool2(_5738.x < 1.0f.xx.x, _5738.y < 1.0f.xx.y));
                }
                else
                {
                    _8842 = _8836;
                }
                if (!_8842)
                {
                    _19762 = false;
                    break;
                }
                uint _8849_dummy_parameter;
                float4x4 _19760;
                do
                {
                    float4x4 _8863;
                    bool _19759;
                    do
                    {
                        _8863 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19759 = false;
                            break;
                        }
                        uint _8897 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_8897 + 32u) * 4 + 0) != 1u)
                        {
                            _19759 = false;
                            break;
                        }
                        uint _19756;
                        _19756 = 0u;
                        for (; _19756 < 4u; _19756++)
                        {
                            for (uint _19757 = 0u; _19757 < 4u; )
                            {
                                _8863[_19756][_19757] = asfloat(rw_nfru_diagnostics.Load<uint>(((_8897 + (_19756 * 4u)) + _19757) * 4 + 0));
                                _19757++;
                                continue;
                            }
                        }
                        _19759 = true;
                        break;
                    } while(false);
                    if (_19759)
                    {
                        _19760 = _8863;
                        break;
                    }
                    _19760 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19761;
                do
                {
                    float _8974 = _5738.x;
                    float _8977 = 1.0f - _5738.y;
                    float4 _8988 = mul(float4((float2(_8974, _8977) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5738 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8849_dummy_parameter))))), 0)).x, 1.0f), _19760);
                    float _8990 = _8988.w;
                    if (!(_8990 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19761 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9003 = ((_8988.xy / _8990.xx) + 1.0f.xx) * 0.5f;
                    _19761 = float2(_9003.x - _8974, _8977 - _9003.y);
                    break;
                } while(false);
                float2 _8800 = abs(_19761);
                if (any(bool2(_8800.x > 100000.0f.xx.x, _8800.y > 100000.0f.xx.y)))
                {
                    _19762 = false;
                    break;
                }
                float _8808 = length(_19761 * _5740);
                uint _9023_dummy_parameter;
                bool _8822 = _8808 > ((8.0f * _5740.x) / float(cbFI_MvDepthLaneSize.x));
                bool _8829;
                if (_8822)
                {
                    _8829 = length((r_motion_tp1.Load(int3(int2(floor(_5738 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9023_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5740) < (0.20000000298023223876953125f * _8808);
                }
                else
                {
                    _8829 = _8822;
                }
                _19762 = _8829;
                break;
            } while(false);
            float2 _5750 = _5482 + float2(_5732, _5736);
            bool _19769;
            do
            {
                bool _9109 = all(bool2(_5750.x > 0.0f.xx.x, _5750.y > 0.0f.xx.y));
                bool _9115;
                if (_9109)
                {
                    _9115 = all(bool2(_5750.x < 1.0f.xx.x, _5750.y < 1.0f.xx.y));
                }
                else
                {
                    _9115 = _9109;
                }
                if (!_9115)
                {
                    _19769 = false;
                    break;
                }
                uint _9122_dummy_parameter;
                float4x4 _19767;
                do
                {
                    float4x4 _9136;
                    bool _19766;
                    do
                    {
                        _9136 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19766 = false;
                            break;
                        }
                        uint _9170 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9170 + 32u) * 4 + 0) != 1u)
                        {
                            _19766 = false;
                            break;
                        }
                        uint _19763;
                        _19763 = 0u;
                        for (; _19763 < 4u; _19763++)
                        {
                            for (uint _19764 = 0u; _19764 < 4u; )
                            {
                                _9136[_19763][_19764] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9170 + (_19763 * 4u)) + _19764) * 4 + 0));
                                _19764++;
                                continue;
                            }
                        }
                        _19766 = true;
                        break;
                    } while(false);
                    if (_19766)
                    {
                        _19767 = _9136;
                        break;
                    }
                    _19767 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19768;
                do
                {
                    float _9247 = _5750.x;
                    float _9250 = 1.0f - _5750.y;
                    float4 _9261 = mul(float4((float2(_9247, _9250) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5750 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9122_dummy_parameter))))), 0)).x, 1.0f), _19767);
                    float _9263 = _9261.w;
                    if (!(_9263 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19768 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9276 = ((_9261.xy / _9263.xx) + 1.0f.xx) * 0.5f;
                    _19768 = float2(_9276.x - _9247, _9250 - _9276.y);
                    break;
                } while(false);
                float2 _9073 = abs(_19768);
                if (any(bool2(_9073.x > 100000.0f.xx.x, _9073.y > 100000.0f.xx.y)))
                {
                    _19769 = false;
                    break;
                }
                float _9081 = length(_19768 * _5740);
                uint _9296_dummy_parameter;
                bool _9095 = _9081 > ((8.0f * _5740.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9102;
                if (_9095)
                {
                    _9102 = length((r_motion_tp1.Load(int3(int2(floor(_5750 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9296_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5740) < (0.20000000298023223876953125f * _9081);
                }
                else
                {
                    _9102 = _9095;
                }
                _19769 = _9102;
                break;
            } while(false);
            float2 _5763 = _5482 + float2(_5733, _5735);
            bool _19776;
            do
            {
                bool _9382 = all(bool2(_5763.x > 0.0f.xx.x, _5763.y > 0.0f.xx.y));
                bool _9388;
                if (_9382)
                {
                    _9388 = all(bool2(_5763.x < 1.0f.xx.x, _5763.y < 1.0f.xx.y));
                }
                else
                {
                    _9388 = _9382;
                }
                if (!_9388)
                {
                    _19776 = false;
                    break;
                }
                uint _9395_dummy_parameter;
                float4x4 _19774;
                do
                {
                    float4x4 _9409;
                    bool _19773;
                    do
                    {
                        _9409 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19773 = false;
                            break;
                        }
                        uint _9443 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9443 + 32u) * 4 + 0) != 1u)
                        {
                            _19773 = false;
                            break;
                        }
                        uint _19770;
                        _19770 = 0u;
                        for (; _19770 < 4u; _19770++)
                        {
                            for (uint _19771 = 0u; _19771 < 4u; )
                            {
                                _9409[_19770][_19771] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9443 + (_19770 * 4u)) + _19771) * 4 + 0));
                                _19771++;
                                continue;
                            }
                        }
                        _19773 = true;
                        break;
                    } while(false);
                    if (_19773)
                    {
                        _19774 = _9409;
                        break;
                    }
                    _19774 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19775;
                do
                {
                    float _9520 = _5763.x;
                    float _9523 = 1.0f - _5763.y;
                    float4 _9534 = mul(float4((float2(_9520, _9523) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5763 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9395_dummy_parameter))))), 0)).x, 1.0f), _19774);
                    float _9536 = _9534.w;
                    if (!(_9536 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19775 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9549 = ((_9534.xy / _9536.xx) + 1.0f.xx) * 0.5f;
                    _19775 = float2(_9549.x - _9520, _9523 - _9549.y);
                    break;
                } while(false);
                float2 _9346 = abs(_19775);
                if (any(bool2(_9346.x > 100000.0f.xx.x, _9346.y > 100000.0f.xx.y)))
                {
                    _19776 = false;
                    break;
                }
                float _9354 = length(_19775 * _5740);
                uint _9569_dummy_parameter;
                bool _9368 = _9354 > ((8.0f * _5740.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9375;
                if (_9368)
                {
                    _9375 = length((r_motion_tp1.Load(int3(int2(floor(_5763 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9569_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5740) < (0.20000000298023223876953125f * _9354);
                }
                else
                {
                    _9375 = _9368;
                }
                _19776 = _9375;
                break;
            } while(false);
            float2 _5775 = _5482 + _5729;
            bool _19783;
            do
            {
                bool _9655 = all(bool2(_5775.x > 0.0f.xx.x, _5775.y > 0.0f.xx.y));
                bool _9661;
                if (_9655)
                {
                    _9661 = all(bool2(_5775.x < 1.0f.xx.x, _5775.y < 1.0f.xx.y));
                }
                else
                {
                    _9661 = _9655;
                }
                if (!_9661)
                {
                    _19783 = false;
                    break;
                }
                uint _9668_dummy_parameter;
                float4x4 _19781;
                do
                {
                    float4x4 _9682;
                    bool _19780;
                    do
                    {
                        _9682 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _19780 = false;
                            break;
                        }
                        uint _9716 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_9716 + 32u) * 4 + 0) != 1u)
                        {
                            _19780 = false;
                            break;
                        }
                        uint _19777;
                        _19777 = 0u;
                        for (; _19777 < 4u; _19777++)
                        {
                            for (uint _19778 = 0u; _19778 < 4u; )
                            {
                                _9682[_19777][_19778] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9716 + (_19777 * 4u)) + _19778) * 4 + 0));
                                _19778++;
                                continue;
                            }
                        }
                        _19780 = true;
                        break;
                    } while(false);
                    if (_19780)
                    {
                        _19781 = _9682;
                        break;
                    }
                    _19781 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float2 _19782;
                do
                {
                    float _9793 = _5775.x;
                    float _9796 = 1.0f - _5775.y;
                    float4 _9807 = mul(float4((float2(_9793, _9796) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5775 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9668_dummy_parameter))))), 0)).x, 1.0f), _19781);
                    float _9809 = _9807.w;
                    if (!(_9809 > 9.9999999747524270787835121154785e-07f))
                    {
                        _19782 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9822 = ((_9807.xy / _9809.xx) + 1.0f.xx) * 0.5f;
                    _19782 = float2(_9822.x - _9793, _9796 - _9822.y);
                    break;
                } while(false);
                float2 _9619 = abs(_19782);
                if (any(bool2(_9619.x > 100000.0f.xx.x, _9619.y > 100000.0f.xx.y)))
                {
                    _19783 = false;
                    break;
                }
                float _9627 = length(_19782 * _5740);
                uint _9842_dummy_parameter;
                bool _9641 = _9627 > ((8.0f * _5740.x) / float(cbFI_MvDepthLaneSize.x));
                bool _9648;
                if (_9641)
                {
                    _9648 = length((r_motion_tp1.Load(int3(int2(floor(_5775 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9842_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5740) < (0.20000000298023223876953125f * _9627);
                }
                else
                {
                    _9648 = _9641;
                }
                _19783 = _9648;
                break;
            } while(false);
            float _5781 = 0.25f * (((float(_19762) + float(_19769)) + float(_19776)) + float(_19783));
            float4 _19953;
            if (_5781 < 1.0f)
            {
                bool _19790;
                do
                {
                    bool _9928 = all(bool2(_19741.x > 0.0f.xx.x, _19741.y > 0.0f.xx.y));
                    bool _9934;
                    if (_9928)
                    {
                        _9934 = all(bool2(_19741.x < 1.0f.xx.x, _19741.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9934 = _9928;
                    }
                    if (!_9934)
                    {
                        _19790 = false;
                        break;
                    }
                    uint _9941_dummy_parameter;
                    float4x4 _19788;
                    do
                    {
                        float4x4 _9955;
                        bool _19787;
                        do
                        {
                            _9955 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19787 = false;
                                break;
                            }
                            uint _9989 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_9989 + 32u) * 4 + 0) != 1u)
                            {
                                _19787 = false;
                                break;
                            }
                            uint _19784;
                            _19784 = 0u;
                            for (; _19784 < 4u; _19784++)
                            {
                                for (uint _19785 = 0u; _19785 < 4u; )
                                {
                                    _9955[_19784][_19785] = asfloat(rw_nfru_diagnostics.Load<uint>(((_9989 + (_19784 * 4u)) + _19785) * 4 + 0));
                                    _19785++;
                                    continue;
                                }
                            }
                            _19787 = true;
                            break;
                        } while(false);
                        if (_19787)
                        {
                            _19788 = _9955;
                            break;
                        }
                        _19788 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19789;
                    do
                    {
                        float _10069 = 1.0f - _19741.y;
                        float4 _10080 = mul(float4((float2(_19741.x, _10069) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19741 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9941_dummy_parameter))))), 0)).x, 1.0f), _19788);
                        float _10082 = _10080.w;
                        if (!(_10082 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19789 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10095 = ((_10080.xy / _10082.xx) + 1.0f.xx) * 0.5f;
                        _19789 = float2(_10095.x - _19741.x, _10069 - _10095.y);
                        break;
                    } while(false);
                    float2 _9892 = abs(_19789);
                    if (any(bool2(_9892.x > 100000.0f.xx.x, _9892.y > 100000.0f.xx.y)))
                    {
                        _19790 = false;
                        break;
                    }
                    float _9900 = length(_19789 * _5740);
                    uint _10115_dummy_parameter;
                    bool _9914 = _9900 > ((8.0f * _5740.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _9921;
                    if (_9914)
                    {
                        _9921 = length((r_motion_tp1.Load(int3(int2(floor(_19741 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10115_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5740) < (0.20000000298023223876953125f * _9900);
                    }
                    else
                    {
                        _9921 = _9914;
                    }
                    _19790 = _9921;
                    break;
                } while(false);
                bool _19797;
                do
                {
                    bool _10201 = all(bool2(_19743.x > 0.0f.xx.x, _19743.y > 0.0f.xx.y));
                    bool _10207;
                    if (_10201)
                    {
                        _10207 = all(bool2(_19743.x < 1.0f.xx.x, _19743.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10207 = _10201;
                    }
                    if (!_10207)
                    {
                        _19797 = false;
                        break;
                    }
                    uint _10214_dummy_parameter;
                    float4x4 _19795;
                    do
                    {
                        float4x4 _10228;
                        bool _19794;
                        do
                        {
                            _10228 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19794 = false;
                                break;
                            }
                            uint _10262 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10262 + 32u) * 4 + 0) != 1u)
                            {
                                _19794 = false;
                                break;
                            }
                            uint _19791;
                            _19791 = 0u;
                            for (; _19791 < 4u; _19791++)
                            {
                                for (uint _19792 = 0u; _19792 < 4u; )
                                {
                                    _10228[_19791][_19792] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10262 + (_19791 * 4u)) + _19792) * 4 + 0));
                                    _19792++;
                                    continue;
                                }
                            }
                            _19794 = true;
                            break;
                        } while(false);
                        if (_19794)
                        {
                            _19795 = _10228;
                            break;
                        }
                        _19795 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19796;
                    do
                    {
                        float _10342 = 1.0f - _19743.y;
                        float4 _10353 = mul(float4((float2(_19743.x, _10342) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19743 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10214_dummy_parameter))))), 0)).x, 1.0f), _19795);
                        float _10355 = _10353.w;
                        if (!(_10355 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19796 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10368 = ((_10353.xy / _10355.xx) + 1.0f.xx) * 0.5f;
                        _19796 = float2(_10368.x - _19743.x, _10342 - _10368.y);
                        break;
                    } while(false);
                    float2 _10165 = abs(_19796);
                    if (any(bool2(_10165.x > 100000.0f.xx.x, _10165.y > 100000.0f.xx.y)))
                    {
                        _19797 = false;
                        break;
                    }
                    float _10173 = length(_19796 * _5740);
                    uint _10388_dummy_parameter;
                    bool _10187 = _10173 > ((8.0f * _5740.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10194;
                    if (_10187)
                    {
                        _10194 = length((r_motion_tp1.Load(int3(int2(floor(_19743 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10388_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5740) < (0.20000000298023223876953125f * _10173);
                    }
                    else
                    {
                        _10194 = _10187;
                    }
                    _19797 = _10194;
                    break;
                } while(false);
                bool _19804;
                do
                {
                    bool _10474 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                    bool _10480;
                    if (_10474)
                    {
                        _10480 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10480 = _10474;
                    }
                    if (!_10480)
                    {
                        _19804 = false;
                        break;
                    }
                    uint _10487_dummy_parameter;
                    float4x4 _19802;
                    do
                    {
                        float4x4 _10501;
                        bool _19801;
                        do
                        {
                            _10501 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19801 = false;
                                break;
                            }
                            uint _10535 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10535 + 32u) * 4 + 0) != 1u)
                            {
                                _19801 = false;
                                break;
                            }
                            uint _19798;
                            _19798 = 0u;
                            for (; _19798 < 4u; _19798++)
                            {
                                for (uint _19799 = 0u; _19799 < 4u; )
                                {
                                    _10501[_19798][_19799] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10535 + (_19798 * 4u)) + _19799) * 4 + 0));
                                    _19799++;
                                    continue;
                                }
                            }
                            _19801 = true;
                            break;
                        } while(false);
                        if (_19801)
                        {
                            _19802 = _10501;
                            break;
                        }
                        _19802 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19803;
                    do
                    {
                        float _10615 = 1.0f - _19744.y;
                        float4 _10626 = mul(float4((float2(_19744.x, _10615) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10487_dummy_parameter))))), 0)).x, 1.0f), _19802);
                        float _10628 = _10626.w;
                        if (!(_10628 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19803 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10641 = ((_10626.xy / _10628.xx) + 1.0f.xx) * 0.5f;
                        _19803 = float2(_10641.x - _19744.x, _10615 - _10641.y);
                        break;
                    } while(false);
                    float2 _10438 = abs(_19803);
                    if (any(bool2(_10438.x > 100000.0f.xx.x, _10438.y > 100000.0f.xx.y)))
                    {
                        _19804 = false;
                        break;
                    }
                    float _10446 = length(_19803 * _5740);
                    uint _10661_dummy_parameter;
                    bool _10460 = _10446 > ((8.0f * _5740.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10467;
                    if (_10460)
                    {
                        _10467 = length((r_motion_tp1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10661_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5740) < (0.20000000298023223876953125f * _10446);
                    }
                    else
                    {
                        _10467 = _10460;
                    }
                    _19804 = _10467;
                    break;
                } while(false);
                bool _19811;
                do
                {
                    bool _10747 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                    bool _10753;
                    if (_10747)
                    {
                        _10753 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _10753 = _10747;
                    }
                    if (!_10753)
                    {
                        _19811 = false;
                        break;
                    }
                    uint _10760_dummy_parameter;
                    float4x4 _19809;
                    do
                    {
                        float4x4 _10774;
                        bool _19808;
                        do
                        {
                            _10774 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _19808 = false;
                                break;
                            }
                            uint _10808 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_10808 + 32u) * 4 + 0) != 1u)
                            {
                                _19808 = false;
                                break;
                            }
                            uint _19805;
                            _19805 = 0u;
                            for (; _19805 < 4u; _19805++)
                            {
                                for (uint _19806 = 0u; _19806 < 4u; )
                                {
                                    _10774[_19805][_19806] = asfloat(rw_nfru_diagnostics.Load<uint>(((_10808 + (_19805 * 4u)) + _19806) * 4 + 0));
                                    _19806++;
                                    continue;
                                }
                            }
                            _19808 = true;
                            break;
                        } while(false);
                        if (_19808)
                        {
                            _19809 = _10774;
                            break;
                        }
                        _19809 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    float2 _19810;
                    do
                    {
                        float _10888 = 1.0f - _19745.y;
                        float4 _10899 = mul(float4((float2(_19745.x, _10888) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _10760_dummy_parameter))))), 0)).x, 1.0f), _19809);
                        float _10901 = _10899.w;
                        if (!(_10901 > 9.9999999747524270787835121154785e-07f))
                        {
                            _19810 = 1000000.0f.xx;
                            break;
                        }
                        float2 _10914 = ((_10899.xy / _10901.xx) + 1.0f.xx) * 0.5f;
                        _19810 = float2(_10914.x - _19745.x, _10888 - _10914.y);
                        break;
                    } while(false);
                    float2 _10711 = abs(_19810);
                    if (any(bool2(_10711.x > 100000.0f.xx.x, _10711.y > 100000.0f.xx.y)))
                    {
                        _19811 = false;
                        break;
                    }
                    float _10719 = length(_19810 * _5740);
                    uint _10934_dummy_parameter;
                    bool _10733 = _10719 > ((8.0f * _5740.x) / float(cbFI_MvDepthLaneSize.x));
                    bool _10740;
                    if (_10733)
                    {
                        _10740 = length((r_motion_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _10934_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5740) < (0.20000000298023223876953125f * _10719);
                    }
                    else
                    {
                        _10740 = _10733;
                    }
                    _19811 = _10740;
                    break;
                } while(false);
                float4 _5808 = _8756 * float4(_19790 ? 0.0f : 1.0f, _19797 ? 0.0f : 1.0f, _19804 ? 0.0f : 1.0f, _19811 ? 0.0f : 1.0f);
                float _5810 = dot(_5808, 1.0f.xxxx);
                float4 _19954;
                if (_5810 > 0.001000000047497451305389404296875f)
                {
                    _19954 = _5808 / _5810.xxxx;
                }
                else
                {
                    _19954 = _8756;
                }
                _19953 = _19954;
            }
            else
            {
                _19953 = _8756;
            }
            _21260 = _5781;
            _19952 = _19953;
        }
        else
        {
            _21260 = 0.0f;
            _19952 = _8756;
        }
        bool _5827 = _5519 && (!_19881);
        bool _5836;
        if (_5827)
        {
            _5836 = (_19952.z + _19952.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _5836 = _5827;
        }
        bool _5847;
        if (_5836)
        {
            _5847 = length((_19744 - _19741) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _5847 = _5836;
        }
        bool _20041;
        if (_5847)
        {
            uint4 _10963 = r_warped_motion_qdata_tp1.Load(int3(_19962, 0));
            uint _10964 = _10963.x;
            bool _20044;
            if (_10964 != 0u)
            {
                float _20030;
                if (_10964 == 0u)
                {
                    _20030 = -1.0f;
                }
                else
                {
                    _20030 = float((_10964 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _5857 = _20030 - 0.12000000476837158203125f;
                bool _10983 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                bool _10989;
                if (_10983)
                {
                    _10989 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                }
                else
                {
                    _10989 = _10983;
                }
                bool _5867;
                if (_10989)
                {
                    uint _10996_dummy_parameter;
                    _5867 = (log((r_depth_tm1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _10996_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5857;
                }
                else
                {
                    _5867 = _10989;
                }
                bool _5881;
                if (!_5867)
                {
                    bool _11026 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                    bool _11032;
                    if (_11026)
                    {
                        _11032 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11032 = _11026;
                    }
                    bool _5879;
                    if (_11032)
                    {
                        uint _11039_dummy_parameter;
                        _5879 = (log((r_depth_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11039_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _5857;
                    }
                    else
                    {
                        _5879 = _11032;
                    }
                    _5881 = _5879;
                }
                else
                {
                    _5881 = _5867;
                }
                _20044 = _5881;
            }
            else
            {
                _20044 = false;
            }
            _20041 = _20044;
        }
        else
        {
            _20041 = false;
        }
        bool _5886 = _19881 || _20041;
        bool _5891;
        if (_5886)
        {
            bool _11069 = all(bool2(_19741.x > 0.0f.xx.x, _19741.y > 0.0f.xx.y));
            bool _11075;
            if (_11069)
            {
                _11075 = all(bool2(_19741.x < 1.0f.xx.x, _19741.y < 1.0f.xx.y));
            }
            else
            {
                _11075 = _11069;
            }
            _5891 = _11075;
        }
        else
        {
            _5891 = _5886;
        }
        bool _5896;
        if (_5891)
        {
            bool _11080 = all(bool2(_19743.x > 0.0f.xx.x, _19743.y > 0.0f.xx.y));
            bool _11086;
            if (_11080)
            {
                _11086 = all(bool2(_19743.x < 1.0f.xx.x, _19743.y < 1.0f.xx.y));
            }
            else
            {
                _11086 = _11080;
            }
            _5896 = _11086;
        }
        else
        {
            _5896 = _5891;
        }
        float4 _20164;
        if (_5896)
        {
            float _5902 = _19952.x + _19952.y;
            float _5907 = _19952.z + _19952.w;
            float _20059;
            if (_5902 > 0.001000000047497451305389404296875f)
            {
                _20059 = _19952.x / _5902;
            }
            else
            {
                _20059 = _5707;
            }
            _20164 = float4(_19952.x + (_5907 * _20059), _19952.y + (_5907 * (1.0f - _20059)), 0.0f, 0.0f);
        }
        else
        {
            _20164 = _19952;
        }
        bool _11114 = (cbFI_pad0 & 1024u) != 0u;
        bool _11090 = !_11114;
        bool _11091 = !_11090;
        bool _11108;
        if (_11091)
        {
            _11108 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_19962.y * cbFI_MvDepthLaneSize.x) + _19962.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _11108 = _11090;
        }
        bool _11140;
        if (_11091)
        {
            _11140 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_5498.y * cbFI_FlowLaneSize.x) + _5498.x)) * 4 + 0) != 0u;
        }
        else
        {
            _11140 = _11090;
        }
        float _5942 = float(_11140);
        bool _20185;
        float4 _20224;
        float3 _22151;
        if (_11114)
        {
            bool _5952;
            if (_11108)
            {
                _5952 = all(bool2(_19741.x > 0.0f.xx.x, _19741.y > 0.0f.xx.y));
            }
            else
            {
                _5952 = _11108;
            }
            bool _5958;
            if (_5952)
            {
                _5958 = all(bool2(_19741.x < 1.0f.xx.x, _19741.y < 1.0f.xx.y));
            }
            else
            {
                _5958 = _5952;
            }
            bool _5965;
            if (_11108)
            {
                _5965 = all(bool2(_19743.x > 0.0f.xx.x, _19743.y > 0.0f.xx.y));
            }
            else
            {
                _5965 = _11108;
            }
            bool _5971;
            if (_5965)
            {
                _5971 = all(bool2(_19743.x < 1.0f.xx.x, _19743.y < 1.0f.xx.y));
            }
            else
            {
                _5971 = _5965;
            }
            bool _5978;
            if (_11140)
            {
                _5978 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
            }
            else
            {
                _5978 = _11140;
            }
            bool _5984;
            if (_5978)
            {
                _5984 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
            }
            else
            {
                _5984 = _5978;
            }
            bool _5991;
            if (_11140)
            {
                _5991 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
            }
            else
            {
                _5991 = _11140;
            }
            bool _5997;
            if (_5991)
            {
                _5997 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
            }
            else
            {
                _5997 = _5991;
            }
            bool _5999 = !_11108;
            if (_5999)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11182;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _11182);
                }
            }
            bool _6004 = !_11140;
            if (_6004)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11192;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _11192);
                }
            }
            if (_11108 && _6004)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11202;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _11202);
                }
            }
            if (_5999 && _11140)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _11212;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _11212);
                }
            }
            float _6023 = float(_5958);
            float _6025 = float(_5971);
            bool _6028 = _5984 && _5997;
            float _20093;
            if (_6028)
            {
                _20093 = 1.0f;
            }
            else
            {
                _20093 = (_5984 || _5997) ? 0.5f : 0.0f;
            }
            bool _20108;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_5958)) && (!_5971))
            {
                bool _6058;
                if (_6028)
                {
                    float _20101;
                    do
                    {
                        bool _11296 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                        bool _11302;
                        if (_11296)
                        {
                            _11302 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _11302 = _11296;
                        }
                        bool _11233 = !_11302;
                        bool _11240;
                        if (!_11233)
                        {
                            bool _11307 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                            bool _11313;
                            if (_11307)
                            {
                                _11313 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _11313 = _11307;
                            }
                            _11240 = !_11313;
                        }
                        else
                        {
                            _11240 = _11233;
                        }
                        if (_11240)
                        {
                            _20101 = 0.0f;
                            break;
                        }
                        uint _11320_dummy_parameter;
                        uint _11336_dummy_parameter;
                        float4x4 _20100;
                        do
                        {
                            float4x4 _11350;
                            bool _20099;
                            do
                            {
                                _11350 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if ((cbFI_NfruT2Flags & 524288u) == 0u)
                                {
                                    _20099 = false;
                                    break;
                                }
                                uint _11384 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_11384 + 32u) * 4 + 0) != 1u)
                                {
                                    _20099 = false;
                                    break;
                                }
                                uint _20096;
                                _20096 = 0u;
                                for (; _20096 < 4u; _20096++)
                                {
                                    for (uint _20097 = 0u; _20097 < 4u; )
                                    {
                                        _11350[_20096][_20097] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11384 + 16u) + (_20096 * 4u)) + _20097) * 4 + 0));
                                        _20097++;
                                        continue;
                                    }
                                }
                                _20099 = true;
                                break;
                            } while(false);
                            if (_20099)
                            {
                                _20100 = _11350;
                                break;
                            }
                            _20100 = cbFI_MotionTM1ToTP1;
                            break;
                        } while(false);
                        float4 _11261 = mul(float4((float2(_19744.x, 1.0f - _19744.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11320_dummy_parameter))))), 0)).x, 1.0f), _20100);
                        float _11263 = _11261.w;
                        if (abs(_11263) < 9.9999999747524270787835121154785e-07f)
                        {
                            _20101 = 0.0f;
                            break;
                        }
                        float _11274 = abs(cbFI_DeviceToViewDepth.y / ((_11261.z / _11263) - cbFI_DeviceToViewDepth.x));
                        float _11277 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11336_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _20101 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_11274 - _11277) / max(max(_11274, _11277), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _6058 = _20101 >= 0.5f;
                }
                else
                {
                    _6058 = _6028;
                }
                bool _6066;
                if (_6058)
                {
                    _6066 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _6066 = _6058;
                }
                bool _20109;
                if (_6066)
                {
                    uint _11488_dummy_parameter;
                    float4x4 _20106;
                    do
                    {
                        float4x4 _11502;
                        bool _20105;
                        do
                        {
                            _11502 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20105 = false;
                                break;
                            }
                            uint _11536 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_11536 + 32u) * 4 + 0) != 1u)
                            {
                                _20105 = false;
                                break;
                            }
                            uint _20102;
                            _20102 = 0u;
                            for (; _20102 < 4u; _20102++)
                            {
                                for (uint _20103 = 0u; _20103 < 4u; )
                                {
                                    _11502[_20102][_20103] = asfloat(rw_nfru_diagnostics.Load<uint>((((_11536 + 16u) + (_20102 * 4u)) + _20103) * 4 + 0));
                                    _20103++;
                                    continue;
                                }
                            }
                            _20105 = true;
                            break;
                        } while(false);
                        if (_20105)
                        {
                            _20106 = _11502;
                            break;
                        }
                        _20106 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float2 _20107;
                    do
                    {
                        float _11616 = 1.0f - _19744.y;
                        float4 _11627 = mul(float4((float2(_19744.x, _11616) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11488_dummy_parameter))))), 0)).x, 1.0f), _20106);
                        float _11629 = _11627.w;
                        if (!(_11629 > 9.9999999747524270787835121154785e-07f))
                        {
                            _20107 = 1000000.0f.xx;
                            break;
                        }
                        float2 _11642 = ((_11627.xy / _11629.xx) + 1.0f.xx) * 0.5f;
                        _20107 = float2(_11642.x - _19744.x, _11616 - _11642.y);
                        break;
                    } while(false);
                    float2 _6079 = float2(cbFI_DisplaySize);
                    _20109 = length(((_19744 + _20107) - _19745) * _6079) <= ((0.100000001490116119384765625f * length(_20107 * _6079)) + 8.0f);
                }
                else
                {
                    _20109 = _6058;
                }
                _20108 = _20109;
            }
            else
            {
                _20108 = true;
            }
            bool _6093 = !_20108;
            bool _23558 = _6093 ? false : _5997;
            bool _23559 = _6093 ? false : _5984;
            bool _20186;
            float4 _20225;
            if (!(((_5958 && _5971) && _23559) && _23558))
            {
                float4 _6115 = _20164 * float4(_6023, _6025, float(_23559), float(_23558));
                float _6117 = dot(_6115, 1.0f.xxxx);
                bool _6120 = !(_6117 > 0.0f);
                float4 _20226;
                if (!_6120)
                {
                    _20226 = _6115 / _6117.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _11664;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _11664);
                    }
                    _20226 = 0.0f.xxxx;
                }
                _20225 = _20226;
                _20186 = _6120;
            }
            else
            {
                _20225 = _20164;
                _20186 = false;
            }
            _22151 = float3(_6023, _6025, _20093);
            _20224 = _20225;
            _20185 = _20186;
        }
        else
        {
            _22151 = float3(float(_11108), _5942, 0.0f);
            _20224 = _20164;
            _20185 = false;
        }
        bool _6138 = !_20185;
        float4 _20317;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _6138)
        {
            float _6145 = _20224.x + _20224.y;
            float4 _20318;
            if (_6145 > 0.001000000047497451305389404296875f)
            {
                _20318 = float4(_20224.x / _6145, _20224.y / _6145, 0.0f, 0.0f);
            }
            else
            {
                _20318 = float4(_5707, cbFI_Timestep, 0.0f, 0.0f);
            }
            _20317 = _20318;
        }
        else
        {
            _20317 = _20224;
        }
        float4 _20494;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _6138) && _11108)
        {
            float _20291;
            do
            {
                uint4 _11804 = r_warped_motion_qdata_tp1.Load(int3(_19962, 0));
                uint _11805 = _11804.x;
                if (_11805 != 0u)
                {
                    float _20290;
                    if (_11805 == 0u)
                    {
                        _20290 = -1.0f;
                    }
                    else
                    {
                        _20290 = float((_11805 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20291 = _20290;
                    break;
                }
                int _20273;
                uint _20274;
                _20274 = _11805;
                _20273 = -1;
                uint _20289;
                for (; _20273 <= 1; _20274 = _20289, _20273++)
                {
                    _20289 = _20274;
                    for (int _20287 = -1; _20287 <= 1; )
                    {
                        _20289 = max(_20289, r_warped_motion_qdata_tp1.Load(int3(clamp(_19962 + int2(_20287, _20273), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _20287++;
                        continue;
                    }
                }
                if (_20274 != 0u)
                {
                    float _20286;
                    if (_20274 == 0u)
                    {
                        _20286 = -1.0f;
                    }
                    else
                    {
                        _20286 = float((_20274 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20291 = _20286;
                    break;
                }
                uint _20276;
                _20276 = 4294967295u;
                uint _23451;
                for (int _20275 = 0; _20275 < 8; _20276 = _23451, _20275++)
                {
                    int _20279 = 0;
                    for (;;)
                    {
                        if (_20279 < 5)
                        {
                            int2 _11755 = _19962 + (_1251[_20275] * _1260[_20279].xx);
                            bool _11758 = any(bool2(_11755.x < int2(0, 0).x, _11755.y < int2(0, 0).y));
                            bool _11766;
                            if (!_11758)
                            {
                                _11766 = any(bool2(_11755.x >= cbFI_MvDepthLaneSize.x, _11755.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _11766 = _11758;
                            }
                            if (_11766)
                            {
                                _23451 = _20276;
                                break;
                            }
                            uint4 _11844 = r_warped_motion_qdata_tp1.Load(int3(_11755, 0));
                            uint _11845 = _11844.x;
                            if (_11845 != 0u)
                            {
                                _23451 = min(_20276, _11845);
                                break;
                            }
                            _20279++;
                            continue;
                        }
                        else
                        {
                            _23451 = _20276;
                            break;
                        }
                    }
                }
                float _20278;
                if (_20276 == 4294967295u)
                {
                    _20278 = -1.0f;
                }
                else
                {
                    float _20277;
                    if (_20276 == 0u)
                    {
                        _20277 = -1.0f;
                    }
                    else
                    {
                        _20277 = float((_20276 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _20278 = _20277;
                }
                _20291 = _20278;
                break;
            } while(false);
            float _6181 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _6184 = r_warped_motion_qdata_tp1.Load(int3(_19962, 0)).x == 0u;
            bool _6190;
            if (_6184)
            {
                bool _11870 = all(bool2(_19741.x > 0.0f.xx.x, _19741.y > 0.0f.xx.y));
                bool _11876;
                if (_11870)
                {
                    _11876 = all(bool2(_19741.x < 1.0f.xx.x, _19741.y < 1.0f.xx.y));
                }
                else
                {
                    _11876 = _11870;
                }
                _6190 = _11876;
            }
            else
            {
                _6190 = _6184;
            }
            bool _6195;
            if (_6190)
            {
                bool _11881 = all(bool2(_19743.x > 0.0f.xx.x, _19743.y > 0.0f.xx.y));
                bool _11887;
                if (_11881)
                {
                    _11887 = all(bool2(_19743.x < 1.0f.xx.x, _19743.y < 1.0f.xx.y));
                }
                else
                {
                    _11887 = _11881;
                }
                _6195 = _11887;
            }
            else
            {
                _6195 = _6190;
            }
            bool _20303;
            float4 _20312;
            if (_6195)
            {
                uint _11894_dummy_parameter;
                float _11918 = log((r_depth_tm1.Load(int3(int2(floor(_19741 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _11894_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _11926_dummy_parameter;
                float _11950 = log((r_depth_tp1.Load(int3(int2(floor(_19743 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _11926_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _6206 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6213;
                if (_6206)
                {
                    _6213 = _11950 > (_11918 + 0.07999999821186065673828125f);
                }
                else
                {
                    _6213 = _6206;
                }
                bool _20308;
                float4 _20330;
                if (_6213)
                {
                    _20330 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _20308 = true;
                }
                else
                {
                    bool _6219 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _6226;
                    if (_6219)
                    {
                        _6226 = _11918 > (_11950 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _6226 = _6219;
                    }
                    bool4 _23560 = _6226.xxxx;
                    _20330 = float4(_23560.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20317.x, _23560.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20317.y, _23560.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20317.z, _23560.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20317.w);
                    _20308 = _6226 ? true : false;
                }
                _20312 = _20330;
                _20303 = _20308;
            }
            else
            {
                _20312 = _20317;
                _20303 = false;
            }
            float4 _20385;
            if (_20303)
            {
                _20385 = 1.0f.xxxx;
            }
            else
            {
                bool _6237 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6243;
                if (_6237)
                {
                    _6243 = _20312.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6243 = _6237;
                }
                bool _6248;
                if (_6243)
                {
                    bool _11956 = all(bool2(_19743.x > 0.0f.xx.x, _19743.y > 0.0f.xx.y));
                    bool _11962;
                    if (_11956)
                    {
                        _11962 = all(bool2(_19743.x < 1.0f.xx.x, _19743.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _11962 = _11956;
                    }
                    _6248 = _11962;
                }
                else
                {
                    _6248 = _6243;
                }
                float4 _20386;
                if (_6248)
                {
                    float _20339;
                    if (_20291 >= 0.0f)
                    {
                        _20339 = _20291 - _6181;
                    }
                    else
                    {
                        float _20335;
                        _20335 = 2.0f;
                        float _12019;
                        for (int _20334 = 0; _20334 < 24; _20335 = _12019, _20334++)
                        {
                            float _11983 = float(_20334 & 7) * 0.785398185253143310546875f;
                            int _11985 = _20334 >> 3;
                            int _20336;
                            if (_11985 == 0)
                            {
                                _20336 = 16;
                            }
                            else
                            {
                                _20336 = (_11985 == 1) ? 48 : 96;
                            }
                            uint _12051_dummy_parameter;
                            _12019 = min(_20335, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19743 + ((cbFI_MvDepthLaneSizeRcp * float(_20336)) * float2(cos(_11983), sin(_11983))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12051_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20339 = _20335;
                    }
                    uint _12083_dummy_parameter;
                    float4 _20387;
                    if (r_depth_tp1.Load(int3(int2(floor(_19743 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12083_dummy_parameter))))), 0)).x > ((exp((_20339 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _20387 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _20387 = 1.0f.xxxx;
                    }
                    _20386 = _20387;
                }
                else
                {
                    _20386 = 1.0f.xxxx;
                }
                _20385 = _20386;
            }
            bool _6276 = _20291 >= 0.0f;
            bool _6277 = (!_20303) && _6276;
            bool _6284;
            if (_6277)
            {
                _6284 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _6284 = _6277;
            }
            bool _6290;
            if (_6284)
            {
                _6290 = _20312.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _6290 = _6284;
            }
            bool _6295;
            if (_6290)
            {
                bool _12107 = all(bool2(_19741.x > 0.0f.xx.x, _19741.y > 0.0f.xx.y));
                bool _12113;
                if (_12107)
                {
                    _12113 = all(bool2(_19741.x < 1.0f.xx.x, _19741.y < 1.0f.xx.y));
                }
                else
                {
                    _12113 = _12107;
                }
                _6295 = _12113;
            }
            else
            {
                _6295 = _6290;
            }
            float4 _20410;
            if (_6295)
            {
                float _20379;
                if (_6276)
                {
                    _20379 = _20291 - _6181;
                }
                else
                {
                    float _20375;
                    _20375 = 2.0f;
                    float _12170;
                    for (int _20374 = 0; _20374 < 24; _20375 = _12170, _20374++)
                    {
                        float _12134 = float(_20374 & 7) * 0.785398185253143310546875f;
                        int _12136 = _20374 >> 3;
                        int _20376;
                        if (_12136 == 0)
                        {
                            _20376 = 16;
                        }
                        else
                        {
                            _20376 = (_12136 == 1) ? 48 : 96;
                        }
                        uint _12186_dummy_parameter;
                        _12170 = min(_20375, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19741 + ((cbFI_MvDepthLaneSizeRcp * float(_20376)) * float2(cos(_12134), sin(_12134))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12186_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _20379 = _20375;
                }
                uint _12234_dummy_parameter;
                float4 _20411;
                if (r_depth_tm1.Load(int3(int2(floor(_19741 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12234_dummy_parameter))))), 0)).x > ((exp((_20379 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _19412 = _20385;
                    _19412.x = 0.0f;
                    _20411 = _19412;
                }
                else
                {
                    _20411 = _20385;
                }
                _20410 = _20411;
            }
            else
            {
                _20410 = _20385;
            }
            float4 _20423;
            if (_6277)
            {
                float _12260 = (exp(((_20291 - _6181) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _6333 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _6339;
                if (_6333)
                {
                    _6339 = _20312.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6339 = _6333;
                }
                bool _6344;
                if (_6339)
                {
                    bool _12265 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                    bool _12271;
                    if (_12265)
                    {
                        _12271 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12271 = _12265;
                    }
                    _6344 = _12271;
                }
                else
                {
                    _6344 = _6339;
                }
                bool _6352;
                if (_6344)
                {
                    uint _12278_dummy_parameter;
                    _6352 = r_depth_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12278_dummy_parameter))))), 0)).x > _12260;
                }
                else
                {
                    _6352 = _6344;
                }
                float4 _20421;
                if (_6352)
                {
                    float4 _19415 = _20410;
                    _19415.w = 0.0f;
                    _20421 = _19415;
                }
                else
                {
                    _20421 = _20410;
                }
                bool _6359 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _6365;
                if (_6359)
                {
                    _6365 = _20312.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _6365 = _6359;
                }
                bool _6370;
                if (_6365)
                {
                    bool _12295 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                    bool _12301;
                    if (_12295)
                    {
                        _12301 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12301 = _12295;
                    }
                    _6370 = _12301;
                }
                else
                {
                    _6370 = _6365;
                }
                bool _6378;
                if (_6370)
                {
                    uint _12308_dummy_parameter;
                    _6378 = r_depth_tm1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12308_dummy_parameter))))), 0)).x > _12260;
                }
                else
                {
                    _6378 = _6370;
                }
                float4 _20424;
                if (_6378)
                {
                    float4 _19418 = _20421;
                    _19418.z = 0.0f;
                    _20424 = _19418;
                }
                else
                {
                    _20424 = _20421;
                }
                _20423 = _20424;
            }
            else
            {
                _20423 = _20410;
            }
            float4 _20495;
            if (any(bool4(_20423.x < 1.0f.xxxx.x, _20423.y < 1.0f.xxxx.y, _20423.z < 1.0f.xxxx.z, _20423.w < 1.0f.xxxx.w)))
            {
                float4 _6389 = _20312 * _20423;
                float _6391 = dot(_6389, 1.0f.xxxx);
                float4 _20496;
                if (_6391 > 0.0f)
                {
                    _20496 = _6389 / _6391.xxxx;
                }
                else
                {
                    bool _6402 = _20423.y == 0.0f;
                    bool _6408;
                    if (_6402)
                    {
                        _6408 = _20423.x > 0.0f;
                    }
                    else
                    {
                        _6408 = _6402;
                    }
                    bool _6413;
                    if (_6408)
                    {
                        bool _12325 = all(bool2(_19741.x > 0.0f.xx.x, _19741.y > 0.0f.xx.y));
                        bool _12331;
                        if (_12325)
                        {
                            _12331 = all(bool2(_19741.x < 1.0f.xx.x, _19741.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12331 = _12325;
                        }
                        _6413 = _12331;
                    }
                    else
                    {
                        _6413 = _6408;
                    }
                    float4 _20497;
                    if (_6413)
                    {
                        _20497 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _6418 = _20423.x == 0.0f;
                        bool _6424;
                        if (_6418)
                        {
                            _6424 = _20423.y > 0.0f;
                        }
                        else
                        {
                            _6424 = _6418;
                        }
                        bool _6429;
                        if (_6424)
                        {
                            bool _12336 = all(bool2(_19743.x > 0.0f.xx.x, _19743.y > 0.0f.xx.y));
                            bool _12342;
                            if (_12336)
                            {
                                _12342 = all(bool2(_19743.x < 1.0f.xx.x, _19743.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _12342 = _12336;
                            }
                            _6429 = _12342;
                        }
                        else
                        {
                            _6429 = _6424;
                        }
                        bool4 _23563 = _6429.xxxx;
                        _20497 = float4(_23563.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _20312.x, _23563.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _20312.y, _23563.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _20312.z, _23563.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _20312.w);
                    }
                    _20496 = _20497;
                }
                _20495 = _20496;
            }
            else
            {
                _20495 = _20312;
            }
            _20494 = _20495;
        }
        else
        {
            _20494 = _20317;
        }
        float4 _21224;
        bool _21530;
        float3 _21854;
        if (((cbFI_pad0 & 32768u) != 0u) && _6138)
        {
            bool _6446 = _20494.x > 0.00999999977648258209228515625f;
            bool _6449 = _20494.y > 0.00999999977648258209228515625f;
            bool _6458 = (_20494.z + _20494.w) > 0.0199999995529651641845703125f;
            bool _6464;
            if (_6458)
            {
                bool _12347 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                bool _12353;
                if (_12347)
                {
                    _12353 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                }
                else
                {
                    _12353 = _12347;
                }
                _6464 = _12353;
            }
            else
            {
                _6464 = _6458;
            }
            bool _6469;
            if (_6464)
            {
                bool _12358 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                bool _12364;
                if (_12358)
                {
                    _12364 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                }
                else
                {
                    _12364 = _12358;
                }
                _6469 = _12364;
            }
            else
            {
                _6469 = _6464;
            }
            bool _6476;
            if (_6469)
            {
                float _20510;
                do
                {
                    bool _12447 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                    bool _12453;
                    if (_12447)
                    {
                        _12453 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _12453 = _12447;
                    }
                    bool _12384 = !_12453;
                    bool _12391;
                    if (!_12384)
                    {
                        bool _12458 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                        bool _12464;
                        if (_12458)
                        {
                            _12464 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _12464 = _12458;
                        }
                        _12391 = !_12464;
                    }
                    else
                    {
                        _12391 = _12384;
                    }
                    if (_12391)
                    {
                        _20510 = 0.0f;
                        break;
                    }
                    uint _12471_dummy_parameter;
                    uint _12487_dummy_parameter;
                    float4x4 _20509;
                    do
                    {
                        float4x4 _12501;
                        bool _20508;
                        do
                        {
                            _12501 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20508 = false;
                                break;
                            }
                            uint _12535 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_12535 + 32u) * 4 + 0) != 1u)
                            {
                                _20508 = false;
                                break;
                            }
                            uint _20505;
                            _20505 = 0u;
                            for (; _20505 < 4u; _20505++)
                            {
                                for (uint _20506 = 0u; _20506 < 4u; )
                                {
                                    _12501[_20505][_20506] = asfloat(rw_nfru_diagnostics.Load<uint>((((_12535 + 16u) + (_20505 * 4u)) + _20506) * 4 + 0));
                                    _20506++;
                                    continue;
                                }
                            }
                            _20508 = true;
                            break;
                        } while(false);
                        if (_20508)
                        {
                            _20509 = _12501;
                            break;
                        }
                        _20509 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    float4 _12412 = mul(float4((float2(_19744.x, 1.0f - _19744.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12471_dummy_parameter))))), 0)).x, 1.0f), _20509);
                    float _12414 = _12412.w;
                    if (abs(_12414) < 9.9999999747524270787835121154785e-07f)
                    {
                        _20510 = 0.0f;
                        break;
                    }
                    float _12425 = abs(cbFI_DeviceToViewDepth.y / ((_12412.z / _12414) - cbFI_DeviceToViewDepth.x));
                    float _12428 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12487_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _20510 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_12425 - _12428) / max(max(_12425, _12428), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _6476 = _20510 < 0.5f;
            }
            else
            {
                _6476 = _6469;
            }
            float4 _20529;
            if (_6476)
            {
                uint _12639_dummy_parameter;
                uint _12670_dummy_parameter;
                float4 _20530;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12639_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12670_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _20530 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _20530 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _20529 = _20530;
            }
            else
            {
                _20529 = 1.0f.xxxx;
            }
            bool _6500;
            if (_11108)
            {
                bool _12699 = all(bool2(_19741.x > 0.0f.xx.x, _19741.y > 0.0f.xx.y));
                bool _12705;
                if (_12699)
                {
                    _12705 = all(bool2(_19741.x < 1.0f.xx.x, _19741.y < 1.0f.xx.y));
                }
                else
                {
                    _12705 = _12699;
                }
                _6500 = _12705;
            }
            else
            {
                _6500 = _11108;
            }
            bool _6506;
            if (_11108)
            {
                bool _12710 = all(bool2(_19743.x > 0.0f.xx.x, _19743.y > 0.0f.xx.y));
                bool _12716;
                if (_12710)
                {
                    _12716 = all(bool2(_19743.x < 1.0f.xx.x, _19743.y < 1.0f.xx.y));
                }
                else
                {
                    _12716 = _12710;
                }
                _6506 = _12716;
            }
            else
            {
                _6506 = _11108;
            }
            bool _6512;
            if (_11140)
            {
                bool _12721 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                bool _12727;
                if (_12721)
                {
                    _12727 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                }
                else
                {
                    _12727 = _12721;
                }
                _6512 = _12727;
            }
            else
            {
                _6512 = _11140;
            }
            bool _6518;
            if (_11140)
            {
                bool _12732 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                bool _12738;
                if (_12732)
                {
                    _12738 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                }
                else
                {
                    _12738 = _12732;
                }
                _6518 = _12738;
            }
            else
            {
                _6518 = _11140;
            }
            bool _6521 = _6512 != _6518;
            bool _6527;
            if (_6521)
            {
                _6527 = _6500 || _6506;
            }
            else
            {
                _6527 = _6521;
            }
            float4 _20632;
            if (_6527)
            {
                float4 _19445 = _20529;
                _19445.z = 0.0f;
                _19445.w = 0.0f;
                _20632 = _19445;
            }
            else
            {
                _20632 = _20529;
            }
            bool _6534 = _6500 && _6446;
            bool _6537 = _6506 && _6449;
            float4 _20737;
            float3 _21963;
            if (_6534 || _6537)
            {
                float _20627;
                do
                {
                    uint4 _12877 = r_warped_motion_qdata_tp1.Load(int3(_19962, 0));
                    uint _12878 = _12877.x;
                    if (_12878 != 0u)
                    {
                        float _20626;
                        if (_12878 == 0u)
                        {
                            _20626 = -1.0f;
                        }
                        else
                        {
                            _20626 = float((_12878 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20627 = _20626;
                        break;
                    }
                    int _20609;
                    uint _20610;
                    _20610 = _12878;
                    _20609 = -1;
                    uint _20625;
                    for (; _20609 <= 1; _20610 = _20625, _20609++)
                    {
                        _20625 = _20610;
                        for (int _20623 = -1; _20623 <= 1; )
                        {
                            _20625 = max(_20625, r_warped_motion_qdata_tp1.Load(int3(clamp(_19962 + int2(_20623, _20609), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20623++;
                            continue;
                        }
                    }
                    if (_20610 != 0u)
                    {
                        float _20622;
                        if (_20610 == 0u)
                        {
                            _20622 = -1.0f;
                        }
                        else
                        {
                            _20622 = float((_20610 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20627 = _20622;
                        break;
                    }
                    uint _20612;
                    _20612 = 4294967295u;
                    uint _23452;
                    for (int _20611 = 0; _20611 < 8; _20612 = _23452, _20611++)
                    {
                        int _20615 = 0;
                        for (;;)
                        {
                            if (_20615 < 5)
                            {
                                int2 _12828 = _19962 + (_1251[_20611] * _1260[_20615].xx);
                                bool _12831 = any(bool2(_12828.x < int2(0, 0).x, _12828.y < int2(0, 0).y));
                                bool _12839;
                                if (!_12831)
                                {
                                    _12839 = any(bool2(_12828.x >= cbFI_MvDepthLaneSize.x, _12828.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _12839 = _12831;
                                }
                                if (_12839)
                                {
                                    _23452 = _20612;
                                    break;
                                }
                                uint4 _12917 = r_warped_motion_qdata_tp1.Load(int3(_12828, 0));
                                uint _12918 = _12917.x;
                                if (_12918 != 0u)
                                {
                                    _23452 = min(_20612, _12918);
                                    break;
                                }
                                _20615++;
                                continue;
                            }
                            else
                            {
                                _23452 = _20612;
                                break;
                            }
                        }
                    }
                    float _20614;
                    if (_20612 == 4294967295u)
                    {
                        _20614 = -1.0f;
                    }
                    else
                    {
                        float _20613;
                        if (_20612 == 0u)
                        {
                            _20613 = -1.0f;
                        }
                        else
                        {
                            _20613 = float((_20612 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20614 = _20613;
                    }
                    _20627 = _20614;
                    break;
                } while(false);
                bool _6545 = _20627 < 0.0f;
                float _20628;
                if (_6545)
                {
                    _20628 = 0.0f;
                }
                else
                {
                    _20628 = _20627 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _12939_dummy_parameter;
                uint _12971_dummy_parameter;
                float4 _20665;
                if ((_6545 && _6534) && _6537)
                {
                    uint _13003_dummy_parameter;
                    float _13027 = log((r_depth_tm1.Load(int3(int2(floor(_19741 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13003_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _13035_dummy_parameter;
                    float _13059 = log((r_depth_tp1.Load(int3(int2(floor(_19743 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13035_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _20666;
                    if (_13027 > (_13059 + 0.07999999821186065673828125f))
                    {
                        float4 _19449 = _20632;
                        _19449.x = 0.0f;
                        _20666 = _19449;
                    }
                    else
                    {
                        float4 _20667;
                        if (_13059 > (_13027 + 0.07999999821186065673828125f))
                        {
                            float4 _19451 = _20632;
                            _19451.y = 0.0f;
                            _20667 = _19451;
                        }
                        else
                        {
                            _20667 = _20632;
                        }
                        _20666 = _20667;
                    }
                    _20665 = _20666;
                }
                else
                {
                    _20665 = _20632;
                }
                float _6597 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _6599 = _20627 >= 0.0f;
                float _20648;
                if (_6599)
                {
                    _20648 = _20627 - _6597;
                }
                else
                {
                    float _20644;
                    if (_6534)
                    {
                        float _20643;
                        _20643 = 2.0f;
                        float _13117;
                        for (int _20642 = 0; _20642 < 24; _20643 = _13117, _20642++)
                        {
                            float _13081 = float(_20642 & 7) * 0.785398185253143310546875f;
                            int _13083 = _20642 >> 3;
                            int _20645;
                            if (_13083 == 0)
                            {
                                _20645 = 16;
                            }
                            else
                            {
                                _20645 = (_13083 == 1) ? 48 : 96;
                            }
                            uint _13133_dummy_parameter;
                            _13117 = min(_20643, log((r_depth_tm1.Load(int3(int2(floor(clamp(_19741 + ((cbFI_MvDepthLaneSizeRcp * float(_20645)) * float2(cos(_13081), sin(_13081))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13133_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20644 = _20643;
                    }
                    else
                    {
                        _20644 = 0.0f;
                    }
                    _20648 = _20644;
                }
                float _20655;
                if (_6599)
                {
                    _20655 = _20627 - _6597;
                }
                else
                {
                    float _20651;
                    if (_6537)
                    {
                        float _20650;
                        _20650 = 2.0f;
                        float _13231;
                        for (int _20649 = 0; _20649 < 24; _20650 = _13231, _20649++)
                        {
                            float _13195 = float(_20649 & 7) * 0.785398185253143310546875f;
                            int _13197 = _20649 >> 3;
                            int _20652;
                            if (_13197 == 0)
                            {
                                _20652 = 16;
                            }
                            else
                            {
                                _20652 = (_13197 == 1) ? 48 : 96;
                            }
                            uint _13263_dummy_parameter;
                            _13231 = min(_20650, log((r_depth_tp1.Load(int3(int2(floor(clamp(_19743 + ((cbFI_MvDepthLaneSizeRcp * float(_20652)) * float2(cos(_13195), sin(_13195))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13263_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _20651 = _20650;
                    }
                    else
                    {
                        _20651 = 0.0f;
                    }
                    _20655 = _20651;
                }
                float _20656;
                if (_6534)
                {
                    uint _13295_dummy_parameter;
                    _20656 = r_depth_tm1.Load(int3(int2(floor(_19741 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13295_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20656 = 0.0f;
                }
                float _20657;
                if (_6537)
                {
                    uint _13314_dummy_parameter;
                    _20657 = r_depth_tp1.Load(int3(int2(floor(_19743 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13314_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _20657 = 0.0f;
                }
                bool _6654;
                if (_6534)
                {
                    _6654 = _20656 > ((exp((_20648 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6654 = _6534;
                }
                float4 _20673;
                if (_6654)
                {
                    float4 _19453 = _20665;
                    _19453.x = 0.0f;
                    _20673 = _19453;
                }
                else
                {
                    _20673 = _20665;
                }
                bool _6666;
                if (_6537)
                {
                    _6666 = _20657 > ((exp((_20655 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _6666 = _6537;
                }
                float4 _20675;
                if (_6666)
                {
                    float4 _19455 = _20673;
                    _19455.y = 0.0f;
                    _20675 = _19455;
                }
                else
                {
                    _20675 = _20673;
                }
                float4 _20738;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _6599)
                {
                    bool _6686;
                    if (_6534)
                    {
                        _6686 = _20656 < ((exp((_20648 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6686 = _6534;
                    }
                    float4 _20677;
                    if (_6686)
                    {
                        float4 _19457 = _20675;
                        _19457.x = 0.0f;
                        _20677 = _19457;
                    }
                    else
                    {
                        _20677 = _20675;
                    }
                    bool _6698;
                    if (_6537)
                    {
                        _6698 = _20657 < ((exp((_20655 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _6698 = _6537;
                    }
                    float4 _20739;
                    if (_6698)
                    {
                        float4 _19459 = _20677;
                        _19459.y = 0.0f;
                        _20739 = _19459;
                    }
                    else
                    {
                        _20739 = _20677;
                    }
                    _20738 = _20739;
                }
                else
                {
                    _20738 = _20675;
                }
                _21963 = float3(_20628, log((r_depth_tm1.Load(int3(int2(floor(_19741 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _12939_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_19743 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _12971_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _20737 = _20738;
            }
            else
            {
                _21963 = float3(0.0f, 0.0f, 0.5f);
                _20737 = _20632;
            }
            bool _6709 = ((cbFI_NfruT2Flags & 16u) != 0u) && _6458;
            bool _6715;
            if (_6709)
            {
                _6715 = _6512 || _6518;
            }
            else
            {
                _6715 = _6709;
            }
            float4 _20780;
            if (_6715)
            {
                float _20732;
                do
                {
                    uint4 _13493 = r_warped_motion_qdata_tp1.Load(int3(_19962, 0));
                    uint _13494 = _13493.x;
                    if (_13494 != 0u)
                    {
                        float _20731;
                        if (_13494 == 0u)
                        {
                            _20731 = -1.0f;
                        }
                        else
                        {
                            _20731 = float((_13494 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20732 = _20731;
                        break;
                    }
                    int _20714;
                    uint _20715;
                    _20715 = _13494;
                    _20714 = -1;
                    uint _20730;
                    for (; _20714 <= 1; _20715 = _20730, _20714++)
                    {
                        _20730 = _20715;
                        for (int _20728 = -1; _20728 <= 1; )
                        {
                            _20730 = max(_20730, r_warped_motion_qdata_tp1.Load(int3(clamp(_19962 + int2(_20728, _20714), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _20728++;
                            continue;
                        }
                    }
                    if (_20715 != 0u)
                    {
                        float _20727;
                        if (_20715 == 0u)
                        {
                            _20727 = -1.0f;
                        }
                        else
                        {
                            _20727 = float((_20715 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20732 = _20727;
                        break;
                    }
                    uint _20717;
                    _20717 = 4294967295u;
                    uint _23453;
                    for (int _20716 = 0; _20716 < 8; _20717 = _23453, _20716++)
                    {
                        int _20720 = 0;
                        for (;;)
                        {
                            if (_20720 < 5)
                            {
                                int2 _13444 = _19962 + (_1251[_20716] * _1260[_20720].xx);
                                bool _13447 = any(bool2(_13444.x < int2(0, 0).x, _13444.y < int2(0, 0).y));
                                bool _13455;
                                if (!_13447)
                                {
                                    _13455 = any(bool2(_13444.x >= cbFI_MvDepthLaneSize.x, _13444.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _13455 = _13447;
                                }
                                if (_13455)
                                {
                                    _23453 = _20717;
                                    break;
                                }
                                uint4 _13533 = r_warped_motion_qdata_tp1.Load(int3(_13444, 0));
                                uint _13534 = _13533.x;
                                if (_13534 != 0u)
                                {
                                    _23453 = min(_20717, _13534);
                                    break;
                                }
                                _20720++;
                                continue;
                            }
                            else
                            {
                                _23453 = _20717;
                                break;
                            }
                        }
                    }
                    float _20719;
                    if (_20717 == 4294967295u)
                    {
                        _20719 = -1.0f;
                    }
                    else
                    {
                        float _20718;
                        if (_20717 == 0u)
                        {
                            _20718 = -1.0f;
                        }
                        else
                        {
                            _20718 = float((_20717 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _20719 = _20718;
                    }
                    _20732 = _20719;
                    break;
                } while(false);
                float4 _20781;
                if (_20732 >= 0.0f)
                {
                    float _13555 = (exp((_20732 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _6734;
                    if (_6512)
                    {
                        uint _13562_dummy_parameter;
                        _6734 = r_depth_tm1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13562_dummy_parameter))))), 0)).x > _13555;
                    }
                    else
                    {
                        _6734 = _6512;
                    }
                    float4 _20750;
                    if (_6734)
                    {
                        float4 _19461 = _20737;
                        _19461.z = 0.0f;
                        _20750 = _19461;
                    }
                    else
                    {
                        _20750 = _20737;
                    }
                    bool _6746;
                    if (_6518)
                    {
                        uint _13581_dummy_parameter;
                        _6746 = r_depth_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13581_dummy_parameter))))), 0)).x > _13555;
                    }
                    else
                    {
                        _6746 = _6518;
                    }
                    float4 _20782;
                    if (_6746)
                    {
                        float4 _19463 = _20750;
                        _19463.w = 0.0f;
                        _20782 = _19463;
                    }
                    else
                    {
                        _20782 = _20750;
                    }
                    _20781 = _20782;
                }
                else
                {
                    _20781 = _20737;
                }
                _20780 = _20781;
            }
            else
            {
                _20780 = _20737;
            }
            bool _6754 = _6500 != _6506;
            bool _6761;
            if (_6754)
            {
                _6761 = _6500 ? _6446 : _6449;
            }
            else
            {
                _6761 = _6754;
            }
            bool _6768;
            if (_6761)
            {
                _6768 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _6768 = _6761;
            }
            float4 _20883;
            if (_6768)
            {
                bool2 _6773 = _6500.xx;
                float2 _6774 = float2(_6773.x ? _19741.x : _19743.x, _6773.y ? _19741.y : _19743.y);
                float _20764;
                if (_6500)
                {
                    uint _13600_dummy_parameter;
                    _20764 = r_depth_tm1.Load(int3(int2(floor(_6774 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _13600_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _13616_dummy_parameter;
                    _20764 = r_depth_tp1.Load(int3(int2(floor(_6774 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _13616_dummy_parameter))))), 0)).x;
                }
                float4x4 _20771;
                if (_6500)
                {
                    float4x4 _20760;
                    do
                    {
                        float4x4 _13630;
                        bool _20759;
                        do
                        {
                            _13630 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20759 = false;
                                break;
                            }
                            uint _13664 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13664 + 32u) * 4 + 0) != 1u)
                            {
                                _20759 = false;
                                break;
                            }
                            uint _20756;
                            _20756 = 0u;
                            for (; _20756 < 4u; _20756++)
                            {
                                for (uint _20757 = 0u; _20757 < 4u; )
                                {
                                    _13630[_20756][_20757] = asfloat(rw_nfru_diagnostics.Load<uint>((((_13664 + 16u) + (_20756 * 4u)) + _20757) * 4 + 0));
                                    _20757++;
                                    continue;
                                }
                            }
                            _20759 = true;
                            break;
                        } while(false);
                        if (_20759)
                        {
                            _20760 = _13630;
                            break;
                        }
                        _20760 = cbFI_MotionTM1ToTP1;
                        break;
                    } while(false);
                    _20771 = _20760;
                }
                else
                {
                    float4x4 _20755;
                    do
                    {
                        float4x4 _13736;
                        bool _20754;
                        do
                        {
                            _13736 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                            if ((cbFI_NfruT2Flags & 524288u) == 0u)
                            {
                                _20754 = false;
                                break;
                            }
                            uint _13770 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                            if (rw_nfru_diagnostics.Load<uint>((_13770 + 32u) * 4 + 0) != 1u)
                            {
                                _20754 = false;
                                break;
                            }
                            uint _20751;
                            _20751 = 0u;
                            for (; _20751 < 4u; _20751++)
                            {
                                for (uint _20752 = 0u; _20752 < 4u; )
                                {
                                    _13736[_20751][_20752] = asfloat(rw_nfru_diagnostics.Load<uint>(((_13770 + (_20751 * 4u)) + _20752) * 4 + 0));
                                    _20752++;
                                    continue;
                                }
                            }
                            _20754 = true;
                            break;
                        } while(false);
                        if (_20754)
                        {
                            _20755 = _13736;
                            break;
                        }
                        _20755 = cbFI_MotionTP1ToTM1;
                        break;
                    } while(false);
                    _20771 = _20755;
                }
                float2 _20772;
                do
                {
                    float _13847 = _6774.x;
                    float _13850 = 1.0f - _6774.y;
                    float4 _13861 = mul(float4((float2(_13847, _13850) * 2.0f) - 1.0f.xx, _20764, 1.0f), _20771);
                    float _13863 = _13861.w;
                    if (!(_13863 > 9.9999999747524270787835121154785e-07f))
                    {
                        _20772 = 1000000.0f.xx;
                        break;
                    }
                    float2 _13876 = ((_13861.xy / _13863.xx) + 1.0f.xx) * 0.5f;
                    _20772 = float2(_13876.x - _13847, _13850 - _13876.y);
                    break;
                } while(false);
                float2 _6804 = float2(cbFI_DisplaySize);
                float4 _20884;
                if (!(length(((_6774 + _20772) - float2(_6773.x ? _19743.x : _19741.x, _6773.y ? _19743.y : _19741.y)) * _6804) <= ((0.100000001490116119384765625f * length(_20772 * _6804)) + 8.0f)))
                {
                    float4 _20885;
                    if (_6500)
                    {
                        float4 _19473 = _20780;
                        _19473.x = 0.0f;
                        _20885 = _19473;
                    }
                    else
                    {
                        float4 _19475 = _20780;
                        _19475.y = 0.0f;
                        _20885 = _19475;
                    }
                    _20884 = _20885;
                }
                else
                {
                    _20884 = _20780;
                }
                _20883 = _20884;
            }
            else
            {
                _20883 = _20780;
            }
            float4 _6829 = _20494 * _20883;
            float _6831 = dot(_6829, 1.0f.xxxx);
            float4 _21225;
            bool _21531;
            if (_6831 > 0.0f)
            {
                _21531 = _20185;
                _21225 = _6829 / _6831.xxxx;
            }
            else
            {
                bool _6842 = any(bool4(_20883.x < 1.0f.xxxx.x, _20883.y < 1.0f.xxxx.y, _20883.z < 1.0f.xxxx.z, _20883.w < 1.0f.xxxx.w));
                if (_6842)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _13898;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _13898);
                    }
                }
                bool4 _23566 = _6842.xxxx;
                _21531 = _6842 ? true : _20185;
                _21225 = float4(_23566.x ? 0.0f.xxxx.x : _20494.x, _23566.y ? 0.0f.xxxx.y : _20494.y, _23566.z ? 0.0f.xxxx.z : _20494.z, _23566.w ? 0.0f.xxxx.w : _20494.w);
            }
            _21854 = _21963;
            _21530 = _21531;
            _21224 = _21225;
        }
        else
        {
            _21854 = float3(0.0f, 0.0f, 0.5f);
            _21530 = _20185;
            _21224 = _20494;
        }
        uint _6851 = (cbFI_pad0 >> 24u) & 31u;
        uint _6855 = (cbFI_pad0 >> 16u) & 255u;
        bool _6857 = _6851 != 0u;
        bool _6859 = _6855 == 12u;
        bool _6862 = _6855 == 13u;
        float4 _21245;
        if ((_6857 || _6859) || _6862)
        {
            float _20891;
            do
            {
                bool _13982 = all(bool2(_19744.x > 0.0f.xx.x, _19744.y > 0.0f.xx.y));
                bool _13988;
                if (_13982)
                {
                    _13988 = all(bool2(_19744.x < 1.0f.xx.x, _19744.y < 1.0f.xx.y));
                }
                else
                {
                    _13988 = _13982;
                }
                bool _13919 = !_13988;
                bool _13926;
                if (!_13919)
                {
                    bool _13993 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
                    bool _13999;
                    if (_13993)
                    {
                        _13999 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _13999 = _13993;
                    }
                    _13926 = !_13999;
                }
                else
                {
                    _13926 = _13919;
                }
                if (_13926)
                {
                    _20891 = 0.0f;
                    break;
                }
                uint _14006_dummy_parameter;
                uint _14022_dummy_parameter;
                float4x4 _20890;
                do
                {
                    float4x4 _14036;
                    bool _20889;
                    do
                    {
                        _14036 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        if ((cbFI_NfruT2Flags & 524288u) == 0u)
                        {
                            _20889 = false;
                            break;
                        }
                        uint _14070 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14070 + 32u) * 4 + 0) != 1u)
                        {
                            _20889 = false;
                            break;
                        }
                        uint _20886;
                        _20886 = 0u;
                        for (; _20886 < 4u; _20886++)
                        {
                            for (uint _20887 = 0u; _20887 < 4u; )
                            {
                                _14036[_20886][_20887] = asfloat(rw_nfru_diagnostics.Load<uint>((((_14070 + 16u) + (_20886 * 4u)) + _20887) * 4 + 0));
                                _20887++;
                                continue;
                            }
                        }
                        _20889 = true;
                        break;
                    } while(false);
                    if (_20889)
                    {
                        _20890 = _14036;
                        break;
                    }
                    _20890 = cbFI_MotionTM1ToTP1;
                    break;
                } while(false);
                float4 _13947 = mul(float4((float2(_19744.x, 1.0f - _19744.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_19744 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14006_dummy_parameter))))), 0)).x, 1.0f), _20890);
                float _13949 = _13947.w;
                if (abs(_13949) < 9.9999999747524270787835121154785e-07f)
                {
                    _20891 = 0.0f;
                    break;
                }
                float _13960 = abs(cbFI_DeviceToViewDepth.y / ((_13947.z / _13949) - cbFI_DeviceToViewDepth.x));
                float _13963 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _14022_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _20891 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_13960 - _13963) / max(max(_13960, _13963), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _14172 = all(bool2(_19745.x > 0.0f.xx.x, _19745.y > 0.0f.xx.y));
            bool _14178;
            if (_14172)
            {
                _14178 = all(bool2(_19745.x < 1.0f.xx.x, _19745.y < 1.0f.xx.y));
            }
            else
            {
                _14178 = _14172;
            }
            float _20892;
            if (_14178)
            {
                uint _14185_dummy_parameter;
                _20892 = length((_8006 + (r_motion_tp1.Load(int3(int2(floor(_19745 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14185_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _20892 = 1000000.0f;
            }
            float _20907;
            if ((_6851 & 1u) != 0u)
            {
                _20907 = _20891;
            }
            else
            {
                _20907 = 1.0f;
            }
            float _20908;
            if ((_6851 & 2u) != 0u)
            {
                _20908 = _20907 * (1.0f - smoothstep(2.0f, 8.0f, _20892));
            }
            else
            {
                _20908 = _20907;
            }
            float _20909;
            if ((_6851 & 4u) != 0u)
            {
                _20909 = _20908 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_8727 - _8735) - length(_8711 - _8719))));
            }
            else
            {
                _20909 = _20908;
            }
            float _21239;
            if ((_6851 & 8u) != 0u)
            {
                _21239 = lerp(1.0f, _20909, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_8711 - _8719)));
            }
            else
            {
                _21239 = _20909;
            }
            bool _6937 = (_6851 & 16u) != 0u;
            bool _6946;
            if (_6937)
            {
                _6946 = length(_19739 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _6946 = _6937;
            }
            float _23568 = _6946 ? 1.0f : _21239;
            bool _6952 = _6857 && _11108;
            bool _6957;
            if (_6952)
            {
                bool _14210 = all(bool2(_19741.x > 0.0f.xx.x, _19741.y > 0.0f.xx.y));
                bool _14216;
                if (_14210)
                {
                    _14216 = all(bool2(_19741.x < 1.0f.xx.x, _19741.y < 1.0f.xx.y));
                }
                else
                {
                    _14216 = _14210;
                }
                _6957 = _14216;
            }
            else
            {
                _6957 = _6952;
            }
            bool _6962;
            if (_6957)
            {
                bool _14221 = all(bool2(_19743.x > 0.0f.xx.x, _19743.y > 0.0f.xx.y));
                bool _14227;
                if (_14221)
                {
                    _14227 = all(bool2(_19743.x < 1.0f.xx.x, _19743.y < 1.0f.xx.y));
                }
                else
                {
                    _14227 = _14221;
                }
                _6962 = _14227;
            }
            else
            {
                _6962 = _6957;
            }
            float4 _21246;
            if (_6962)
            {
                float _6968 = _21224.x + _21224.y;
                float _6977 = (_21224.z + _21224.w) * (1.0f - _23568);
                float _21242;
                if (_6968 > 9.9999997473787516355514526367188e-06f)
                {
                    _21242 = _21224.x / _6968;
                }
                else
                {
                    _21242 = _5707;
                }
                _21246 = float4(_21224.x + (_6977 * _21242), _21224.y + (_6977 * (1.0f - _21242)), _21224.zw * _23568);
            }
            else
            {
                _21246 = _21224;
            }
            _21245 = _21246;
        }
        else
        {
            _21245 = _21224;
        }
        float3 _7038 = (((_8711 * _21245.x) + (_8719 * _21245.y)) + (_8727 * _21245.z)) + (_8735 * _21245.w);
        float3 _23201;
        if (_5723 && (_21260 > 0.0f))
        {
            uint _14234_dummy_parameter;
            float2 _14249 = r_motion_tp1.Load(int3(int2(floor(_5482 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _14234_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
            float2 _21522;
            if (_8034)
            {
                float2 _14294 = clamp((((_19718 + (_14249 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14297 = tan(_14294.x);
                _21522 = (float2(_14297 / cbFI_DeviceToViewDepth.z, (tan(_14294.y) * sqrt(1.0f + (_14297 * _14297))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21522 = _19718 + (_14249 * cbFI_Timestep);
            }
            float2 _21523;
            if (_8034)
            {
                float2 _14373 = clamp((((_19718 + (_14249 * _5697)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _14376 = tan(_14373.x);
                _21523 = (float2(_14376 / cbFI_DeviceToViewDepth.z, (tan(_14373.y) * sqrt(1.0f + (_14376 * _14376))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _21523 = _19718 + (_14249 * _5697);
            }
            _23201 = lerp(_7038, lerp(r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21522, 0.0f).xyz, r_current_interpolation_source.SampleLevel(s_LinearClamp, _21523, 0.0f).xyz, cbFI_Timestep.xxx), _21260.xxx);
        }
        else
        {
            _23201 = _7038;
        }
        float3 _23200;
        if (_21530)
        {
            float3 _14418 = r_current_interpolation_source.Load(int3(_4970, 0)).xyz;
            float3 _23202;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _11108)
            {
                uint _14425_dummy_parameter;
                float _21653;
                _21653 = r_depth_tm1.Load(int3(int2(floor(_19741 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14425_dummy_parameter))))), 0)).x;
                float _7119;
                for (int _21652 = 0; _21652 < 24; _21653 = _7119, _21652++)
                {
                    float _7091 = float(_21652 & 7) * 0.785398185253143310546875f;
                    int _7093 = _21652 >> 3;
                    int _23295;
                    if (_7093 == 0)
                    {
                        _23295 = 16;
                    }
                    else
                    {
                        _23295 = (_7093 == 1) ? 48 : 96;
                    }
                    uint _14445_dummy_parameter;
                    _7119 = min(_21653, r_depth_tm1.Load(int3(int2(floor(clamp(_19741 + ((cbFI_MvDepthLaneSizeRcp * float(_23295)) * float2(cos(_7091), sin(_7091))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _14445_dummy_parameter))))), 0)).x);
                }
                float2 _21654;
                do
                {
                    float _14467 = 1.0f - _19741.y;
                    float4 _14478 = mul(float4((float2(_19741.x, _14467) * 2.0f) - 1.0f.xx, _21653, 1.0f), cbFI_MotionTM1ToTM2);
                    float _14480 = _14478.w;
                    if (!(_14480 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21654 = 1000000.0f.xx;
                        break;
                    }
                    float2 _14493 = ((_14478.xy / _14480.xx) + 1.0f.xx) * 0.5f;
                    _21654 = float2(_14493.x - _19741.x, _14467 - _14493.y);
                    break;
                } while(false);
                float2 _7130 = _19741 + _21654;
                bool _14511 = all(bool2(_7130.x > 0.0f.xx.x, _7130.y > 0.0f.xx.y));
                bool _14517;
                if (_14511)
                {
                    _14517 = all(bool2(_7130.x < 1.0f.xx.x, _7130.y < 1.0f.xx.y));
                }
                else
                {
                    _14517 = _14511;
                }
                float3 _23203;
                if (_14517)
                {
                    float _7136 = abs(cbFI_DeviceToViewDepth.y / (_21653 - cbFI_DeviceToViewDepth.x));
                    uint _14537_dummy_parameter;
                    int2 _14537 = int2(spvTextureSize(r_depth_m2, uint(0), _14537_dummy_parameter));
                    float _7140 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_7130 * float2(_14537))), int2(0, 0), _14537 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _23208;
                    if (abs(_7140 - _7136) <= (0.20000000298023223876953125f * max(_7140, _7136)))
                    {
                        uint _14571_dummy_parameter;
                        int2 _14571 = int2(spvTextureSize(r_colour_m2, uint(0), _14571_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14594;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _14594);
                        }
                        _23208 = r_colour_m2.Load(int3(clamp(int2(floor(_7130 * float2(_14571))), int2(0, 0), _14571 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _14604;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14604);
                        }
                        _23208 = _14418;
                    }
                    _23203 = _23208;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _14614;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _14614);
                    }
                    _23203 = _14418;
                }
                _23202 = _23203;
            }
            else
            {
                _23202 = _14418;
            }
            _23200 = _23202;
        }
        else
        {
            _23200 = _23201;
        }
        bool _7165 = (cbFI_NfruT2Flags & 2097152u) != 0u;
        float3 _23199;
        float _23275;
        if (_7165)
        {
            float2 _7169 = float2(cbFI_DisplaySize);
            float3 _21836;
            float _21837;
            do
            {
                bool _14926;
                float4x4 _21661;
                do
                {
                    float4x4 _14902;
                    bool _21660;
                    do
                    {
                        _14902 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                        _14926 = (cbFI_NfruT2Flags & 524288u) == 0u;
                        if (_14926)
                        {
                            _21660 = false;
                            break;
                        }
                        uint _14936 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                        if (rw_nfru_diagnostics.Load<uint>((_14936 + 32u) * 4 + 0) != 1u)
                        {
                            _21660 = false;
                            break;
                        }
                        uint _21657;
                        _21657 = 0u;
                        for (; _21657 < 4u; _21657++)
                        {
                            for (uint _21658 = 0u; _21658 < 4u; )
                            {
                                _14902[_21657][_21658] = asfloat(rw_nfru_diagnostics.Load<uint>(((_14936 + (_21657 * 4u)) + _21658) * 4 + 0));
                                _21658++;
                                continue;
                            }
                        }
                        _21660 = true;
                        break;
                    } while(false);
                    if (_21660)
                    {
                        _21661 = _14902;
                        break;
                    }
                    _21661 = cbFI_MotionTP1ToTM1;
                    break;
                } while(false);
                float4x4 _14684 = spvInverse(_21661);
                bool _14686 = _6855 == 33u;
                if (_14686 || (_6855 == 34u))
                {
                    uint _15016_dummy_parameter;
                    float2 _15031 = r_motion_tp1.Load(int3(int2(floor(clamp(_5482, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15016_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
                    float2 _21828;
                    if (_14686)
                    {
                        uint _15043_dummy_parameter;
                        float2 _21827;
                        do
                        {
                            float _15062 = _5482.x;
                            float _15065 = 1.0f - _5482.y;
                            float4 _15076 = mul(float4((float2(_15062, _15065) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5482 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15043_dummy_parameter))))), 0)).x, 1.0f), _21661);
                            float _15078 = _15076.w;
                            if (!(_15078 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21827 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15091 = ((_15076.xy / _15078.xx) + 1.0f.xx) * 0.5f;
                            _21827 = float2(_15091.x - _15062, _15065 - _15091.y);
                            break;
                        } while(false);
                        _21828 = _21827 - _15031;
                    }
                    else
                    {
                        float2 _14706 = _5482 + _15031;
                        bool _15109 = all(bool2(_14706.x > 0.0f.xx.x, _14706.y > 0.0f.xx.y));
                        bool _15115;
                        if (_15109)
                        {
                            _15115 = all(bool2(_14706.x < 1.0f.xx.x, _14706.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15115 = _15109;
                        }
                        float2 _21826;
                        if (_15115)
                        {
                            uint _15122_dummy_parameter;
                            float2 _21825;
                            do
                            {
                                float _15141 = _14706.x;
                                float _15144 = 1.0f - _14706.y;
                                float4 _15155 = mul(float4((float2(_15141, _15144) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_14706 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _15122_dummy_parameter))))), 0)).x, 1.0f), _14684);
                                float _15157 = _15155.w;
                                if (!(_15157 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21825 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _15170 = ((_15155.xy / _15157.xx) + 1.0f.xx) * 0.5f;
                                _21825 = float2(_15170.x - _15141, _15144 - _15170.y);
                                break;
                            } while(false);
                            _21826 = _21825 + _15031;
                        }
                        else
                        {
                            _21826 = 0.0f.xx;
                        }
                        _21828 = _21826;
                    }
                    bool _21835;
                    do
                    {
                        bool _15249 = all(bool2(_5482.x > 0.0f.xx.x, _5482.y > 0.0f.xx.y));
                        bool _15255;
                        if (_15249)
                        {
                            _15255 = all(bool2(_5482.x < 1.0f.xx.x, _5482.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _15255 = _15249;
                        }
                        if (!_15255)
                        {
                            _21835 = false;
                            break;
                        }
                        uint _15262_dummy_parameter;
                        float4x4 _21833;
                        do
                        {
                            float4x4 _15276;
                            bool _21832;
                            do
                            {
                                _15276 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14926)
                                {
                                    _21832 = false;
                                    break;
                                }
                                uint _15310 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_15310 + 32u) * 4 + 0) != 1u)
                                {
                                    _21832 = false;
                                    break;
                                }
                                uint _21829;
                                _21829 = 0u;
                                for (; _21829 < 4u; _21829++)
                                {
                                    for (uint _21830 = 0u; _21830 < 4u; )
                                    {
                                        _15276[_21829][_21830] = asfloat(rw_nfru_diagnostics.Load<uint>(((_15310 + (_21829 * 4u)) + _21830) * 4 + 0));
                                        _21830++;
                                        continue;
                                    }
                                }
                                _21832 = true;
                                break;
                            } while(false);
                            if (_21832)
                            {
                                _21833 = _15276;
                                break;
                            }
                            _21833 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21834;
                        do
                        {
                            float _15387 = _5482.x;
                            float _15390 = 1.0f - _5482.y;
                            float4 _15401 = mul(float4((float2(_15387, _15390) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_5482 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _15262_dummy_parameter))))), 0)).x, 1.0f), _21833);
                            float _15403 = _15401.w;
                            if (!(_15403 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21834 = 1000000.0f.xx;
                                break;
                            }
                            float2 _15416 = ((_15401.xy / _15403.xx) + 1.0f.xx) * 0.5f;
                            _21834 = float2(_15416.x - _15387, _15390 - _15416.y);
                            break;
                        } while(false);
                        float2 _15213 = abs(_21834);
                        if (any(bool2(_15213.x > 100000.0f.xx.x, _15213.y > 100000.0f.xx.y)))
                        {
                            _21835 = false;
                            break;
                        }
                        float _15221 = length(_21834 * _7169);
                        uint _15436_dummy_parameter;
                        bool _15235 = _15221 > ((8.0f * _7169.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _15242;
                        if (_15235)
                        {
                            _15242 = length((r_motion_tp1.Load(int3(int2(floor(_5482 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15436_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7169) < (0.20000000298023223876953125f * _15221);
                        }
                        else
                        {
                            _15242 = _15235;
                        }
                        _21835 = _15242;
                        break;
                    } while(false);
                    _21837 = 2.0f;
                    _21836 = float3(clamp(length(_21828 * float2(cbFI_RenderSize)) * 0.25f, 0.0f, 1.0f), float(_21835), 0.0f);
                    break;
                }
                float _15470;
                float _15473;
                float4 _15483;
                float2 _21662;
                do
                {
                    _15470 = _5482.x;
                    _15473 = 1.0f - _5482.y;
                    _15483 = float4((float2(_15470, _15473) * 2.0f) - 1.0f.xx, 1.0000000116860974230803549289703e-07f, 1.0f);
                    float4 _15484 = mul(_15483, _21661);
                    float _15486 = _15484.w;
                    if (!(_15486 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21662 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15499 = ((_15484.xy / _15486.xx) + 1.0f.xx) * 0.5f;
                    _21662 = float2(_15499.x - _15470, _15473 - _15499.y);
                    break;
                } while(false);
                float2 _21663;
                do
                {
                    float4 _15536 = mul(_15483, _14684);
                    float _15538 = _15536.w;
                    if (!(_15538 > 9.9999999747524270787835121154785e-07f))
                    {
                        _21663 = 1000000.0f.xx;
                        break;
                    }
                    float2 _15551 = ((_15536.xy / _15538.xx) + 1.0f.xx) * 0.5f;
                    _21663 = float2(_15551.x - _15470, _15473 - _15551.y);
                    break;
                } while(false);
                float2 _14741 = abs(_21662);
                bool2 _23569 = any(bool2(_14741.x > 4.0f.xx.x, _14741.y > 4.0f.xx.y)).xx;
                float2 _14747 = abs(_21663);
                bool2 _23571 = any(bool2(_14747.x > 4.0f.xx.x, _14747.y > 4.0f.xx.y)).xx;
                float2 _15565[3];
                _15565[0] = _5482;
                float2 _15685 = clamp(_5482, 0.0f.xx, 1.0f.xx);
                uint _15693_dummy_parameter;
                _15565[1] = _5482 - ((r_motion_tp1.Load(int3(int2(floor(_15685 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _15693_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5707);
                _15565[2] = _5482 - (float2(_23569.x ? 0.0f.xx.x : _21662.x, _23569.y ? 0.0f.xx.y : _21662.y) * _5707);
                float _21669;
                float2 _21670;
                _21670 = _5482;
                _21669 = 1000000000.0f;
                float _23573;
                float2 _23575;
                float _23576;
                int _21668 = 0;
                float _21817 = -1.0f;
                for (; _21668 < 3; _21817 = _23573, _21670 = _23575, _21669 = _23576, _21668++)
                {
                    float2 _21807;
                    _21807 = _15565[_21668];
                    for (int _21806 = 0; _21806 < 30; )
                    {
                        uint _16207_dummy_parameter;
                        _21807 += (((_5482 - ((r_motion_tp1.Load(int3(int2(floor(clamp(_21807, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16207_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5707)) - _21807) * 0.699999988079071044921875f);
                        _21806++;
                        continue;
                    }
                    float2 _16637 = clamp(_21807, 0.0f.xx, 1.0f.xx);
                    uint _16645_dummy_parameter;
                    bool _17075 = all(bool2(_21807.x > 0.0f.xx.x, _21807.y > 0.0f.xx.y));
                    bool _17081;
                    if (_17075)
                    {
                        _17081 = all(bool2(_21807.x < 1.0f.xx.x, _21807.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _17081 = _17075;
                    }
                    float _21809;
                    if (_17081)
                    {
                        _21809 = length(((_21807 + ((r_motion_tp1.Load(int3(int2(floor(_16637 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _16645_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _5707)) - _5482) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21809 = 1000000000.0f;
                    }
                    uint _17092_dummy_parameter;
                    float _17132 = log((r_depth_tp1.Load(int3(int2(floor(_16637 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17092_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _15645 = _21809 < 0.3499999940395355224609375f;
                    bool _15647 = _21669 < 0.3499999940395355224609375f;
                    bool _15657;
                    if (_15645)
                    {
                        _15657 = (!_15647) || (_17132 > _21817);
                    }
                    else
                    {
                        _15657 = _15645;
                    }
                    bool _15670;
                    if (!_15657)
                    {
                        _15670 = ((!_15645) && (!_15647)) && (_21809 < _21669);
                    }
                    else
                    {
                        _15670 = _15657;
                    }
                    _23573 = _15670 ? _17132 : _21817;
                    bool2 _23574 = _15670.xx;
                    _23575 = float2(_23574.x ? _21807.x : _21670.x, _23574.y ? _21807.y : _21670.y);
                    _23576 = _15670 ? _21809 : _21669;
                }
                float2 _17134[3];
                _17134[0] = _5482;
                float2 _21689;
                do
                {
                    bool _21679;
                    do
                    {
                        bool _17381 = all(bool2(_15685.x > 0.0f.xx.x, _15685.y > 0.0f.xx.y));
                        bool _17387;
                        if (_17381)
                        {
                            _17387 = all(bool2(_15685.x < 1.0f.xx.x, _15685.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _17387 = _17381;
                        }
                        if (!_17387)
                        {
                            _21679 = false;
                            break;
                        }
                        uint _17394_dummy_parameter;
                        float4x4 _21677;
                        do
                        {
                            float4x4 _17408;
                            bool _21676;
                            do
                            {
                                _17408 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                if (_14926)
                                {
                                    _21676 = false;
                                    break;
                                }
                                uint _17442 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                if (rw_nfru_diagnostics.Load<uint>((_17442 + 32u) * 4 + 0) != 1u)
                                {
                                    _21676 = false;
                                    break;
                                }
                                uint _21673;
                                _21673 = 0u;
                                for (; _21673 < 4u; _21673++)
                                {
                                    for (uint _21674 = 0u; _21674 < 4u; )
                                    {
                                        _17408[_21673][_21674] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17442 + (_21673 * 4u)) + _21674) * 4 + 0));
                                        _21674++;
                                        continue;
                                    }
                                }
                                _21676 = true;
                                break;
                            } while(false);
                            if (_21676)
                            {
                                _21677 = _17408;
                                break;
                            }
                            _21677 = cbFI_MotionTP1ToTM1;
                            break;
                        } while(false);
                        float2 _21678;
                        do
                        {
                            float _17519 = _15685.x;
                            float _17522 = 1.0f - _15685.y;
                            float4 _17533 = mul(float4((float2(_17519, _17522) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_15685 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17394_dummy_parameter))))), 0)).x, 1.0f), _21677);
                            float _17535 = _17533.w;
                            if (!(_17535 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21678 = 1000000.0f.xx;
                                break;
                            }
                            float2 _17548 = ((_17533.xy / _17535.xx) + 1.0f.xx) * 0.5f;
                            _21678 = float2(_17548.x - _17519, _17522 - _17548.y);
                            break;
                        } while(false);
                        float2 _17345 = abs(_21678);
                        if (any(bool2(_17345.x > 100000.0f.xx.x, _17345.y > 100000.0f.xx.y)))
                        {
                            _21679 = false;
                            break;
                        }
                        float _17353 = length(_21678 * _7169);
                        uint _17568_dummy_parameter;
                        bool _17367 = _17353 > ((8.0f * _7169.x) / float(cbFI_MvDepthLaneSize.x));
                        bool _17374;
                        if (_17367)
                        {
                            _17374 = length((r_motion_tp1.Load(int3(int2(floor(_15685 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17568_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7169) < (0.20000000298023223876953125f * _17353);
                        }
                        else
                        {
                            _17374 = _17367;
                        }
                        _21679 = _17374;
                        break;
                    } while(false);
                    if (_21679)
                    {
                        uint _17599_dummy_parameter;
                        _21689 = -(r_motion_tp1.Load(int3(int2(floor(_15685 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _17599_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                        break;
                    }
                    uint _17626_dummy_parameter;
                    float2 _21688;
                    do
                    {
                        float _17645 = _15685.x;
                        float _17648 = 1.0f - _15685.y;
                        float4 _17659 = mul(float4((float2(_17645, _17648) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_15685 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _17626_dummy_parameter))))), 0)).x, 1.0f), _14684);
                        float _17661 = _17659.w;
                        if (!(_17661 > 9.9999999747524270787835121154785e-07f))
                        {
                            _21688 = 1000000.0f.xx;
                            break;
                        }
                        float2 _17674 = ((_17659.xy / _17661.xx) + 1.0f.xx) * 0.5f;
                        _21688 = float2(_17674.x - _17645, _17648 - _17674.y);
                        break;
                    } while(false);
                    float2 _17312 = abs(_21688);
                    bool2 _17316 = any(bool2(_17312.x > 4.0f.xx.x, _17312.y > 4.0f.xx.y)).xx;
                    _21689 = float2(_17316.x ? 0.0f.xx.x : _21688.x, _17316.y ? 0.0f.xx.y : _21688.y);
                    break;
                } while(false);
                _17134[1] = _5482 - (_21689 * cbFI_Timestep);
                _17134[2] = _5482 - (float2(_23571.x ? 0.0f.xx.x : _21663.x, _23571.y ? 0.0f.xx.y : _21663.y) * cbFI_Timestep);
                float _21691;
                float2 _21692;
                _21692 = _5482;
                _21691 = 1000000000.0f;
                float _23577;
                float2 _23579;
                float _23580;
                float4x4 _17922;
                float4x4 _18360;
                int _21690 = 0;
                float _21744 = -1.0f;
                for (; _21690 < 3; _21744 = _23577, _21692 = _23579, _21691 = _23580, _21690++)
                {
                    float2 _21694;
                    _21694 = _17134[_21690];
                    float2 _17731;
                    for (int _21693 = 0; _21693 < 30; _21694 = _17731, _21693++)
                    {
                        float2 _21785;
                        do
                        {
                            float2 _17811 = clamp(_21694, 0.0f.xx, 1.0f.xx);
                            bool _21775;
                            do
                            {
                                bool _17895 = all(bool2(_17811.x > 0.0f.xx.x, _17811.y > 0.0f.xx.y));
                                bool _17901;
                                if (_17895)
                                {
                                    _17901 = all(bool2(_17811.x < 1.0f.xx.x, _17811.y < 1.0f.xx.y));
                                }
                                else
                                {
                                    _17901 = _17895;
                                }
                                if (!_17901)
                                {
                                    _21775 = false;
                                    break;
                                }
                                uint _17908_dummy_parameter;
                                float4x4 _21773;
                                do
                                {
                                    bool _21772;
                                    do
                                    {
                                        _17922 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                        if (_14926)
                                        {
                                            _21772 = false;
                                            break;
                                        }
                                        uint _17956 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                        if (rw_nfru_diagnostics.Load<uint>((_17956 + 32u) * 4 + 0) != 1u)
                                        {
                                            _21772 = false;
                                            break;
                                        }
                                        uint _21769;
                                        _21769 = 0u;
                                        for (; _21769 < 4u; _21769++)
                                        {
                                            for (uint _21770 = 0u; _21770 < 4u; )
                                            {
                                                _17922[_21769][_21770] = asfloat(rw_nfru_diagnostics.Load<uint>(((_17956 + (_21769 * 4u)) + _21770) * 4 + 0));
                                                _21770++;
                                                continue;
                                            }
                                        }
                                        _21772 = true;
                                        break;
                                    } while(false);
                                    if (_21772)
                                    {
                                        _21773 = _17922;
                                        break;
                                    }
                                    _21773 = cbFI_MotionTP1ToTM1;
                                    break;
                                } while(false);
                                float2 _21774;
                                do
                                {
                                    float _18033 = _17811.x;
                                    float _18036 = 1.0f - _17811.y;
                                    float4 _18047 = mul(float4((float2(_18033, _18036) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_17811 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _17908_dummy_parameter))))), 0)).x, 1.0f), _21773);
                                    float _18049 = _18047.w;
                                    if (!(_18049 > 9.9999999747524270787835121154785e-07f))
                                    {
                                        _21774 = 1000000.0f.xx;
                                        break;
                                    }
                                    float2 _18062 = ((_18047.xy / _18049.xx) + 1.0f.xx) * 0.5f;
                                    _21774 = float2(_18062.x - _18033, _18036 - _18062.y);
                                    break;
                                } while(false);
                                float2 _17859 = abs(_21774);
                                if (any(bool2(_17859.x > 100000.0f.xx.x, _17859.y > 100000.0f.xx.y)))
                                {
                                    _21775 = false;
                                    break;
                                }
                                float _17867 = length(_21774 * _7169);
                                uint _18082_dummy_parameter;
                                bool _17881 = _17867 > ((8.0f * _7169.x) / float(cbFI_MvDepthLaneSize.x));
                                bool _17888;
                                if (_17881)
                                {
                                    _17888 = length((r_motion_tp1.Load(int3(int2(floor(_17811 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18082_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7169) < (0.20000000298023223876953125f * _17867);
                                }
                                else
                                {
                                    _17888 = _17881;
                                }
                                _21775 = _17888;
                                break;
                            } while(false);
                            if (_21775)
                            {
                                uint _18113_dummy_parameter;
                                _21785 = -(r_motion_tp1.Load(int3(int2(floor(_17811 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18113_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                                break;
                            }
                            uint _18140_dummy_parameter;
                            float2 _21784;
                            do
                            {
                                float _18159 = _17811.x;
                                float _18162 = 1.0f - _17811.y;
                                float4 _18173 = mul(float4((float2(_18159, _18162) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_17811 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18140_dummy_parameter))))), 0)).x, 1.0f), _14684);
                                float _18175 = _18173.w;
                                if (!(_18175 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21784 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18188 = ((_18173.xy / _18175.xx) + 1.0f.xx) * 0.5f;
                                _21784 = float2(_18188.x - _18159, _18162 - _18188.y);
                                break;
                            } while(false);
                            float2 _17826 = abs(_21784);
                            bool2 _17830 = any(bool2(_17826.x > 4.0f.xx.x, _17826.y > 4.0f.xx.y)).xx;
                            _21785 = float2(_17830.x ? 0.0f.xx.x : _21784.x, _17830.y ? 0.0f.xx.y : _21784.y);
                            break;
                        } while(false);
                        _17731 = _21694 + (((_5482 - (_21785 * cbFI_Timestep)) - _21694) * 0.699999988079071044921875f);
                    }
                    float2 _18249;
                    float2 _21711;
                    do
                    {
                        _18249 = clamp(_21694, 0.0f.xx, 1.0f.xx);
                        bool _21701;
                        do
                        {
                            bool _18333 = all(bool2(_18249.x > 0.0f.xx.x, _18249.y > 0.0f.xx.y));
                            bool _18339;
                            if (_18333)
                            {
                                _18339 = all(bool2(_18249.x < 1.0f.xx.x, _18249.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _18339 = _18333;
                            }
                            if (!_18339)
                            {
                                _21701 = false;
                                break;
                            }
                            uint _18346_dummy_parameter;
                            float4x4 _21699;
                            do
                            {
                                bool _21698;
                                do
                                {
                                    _18360 = float4x4(float4(1.0f, 0.0f, 0.0f, 0.0f), float4(0.0f, 1.0f, 0.0f, 0.0f), float4(0.0f, 0.0f, 1.0f, 0.0f), float4(0.0f, 0.0f, 0.0f, 1.0f));
                                    if (_14926)
                                    {
                                        _21698 = false;
                                        break;
                                    }
                                    uint _18394 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                    if (rw_nfru_diagnostics.Load<uint>((_18394 + 32u) * 4 + 0) != 1u)
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
                                            _18360[_21695][_21696] = asfloat(rw_nfru_diagnostics.Load<uint>(((_18394 + (_21695 * 4u)) + _21696) * 4 + 0));
                                            _21696++;
                                            continue;
                                        }
                                    }
                                    _21698 = true;
                                    break;
                                } while(false);
                                if (_21698)
                                {
                                    _21699 = _18360;
                                    break;
                                }
                                _21699 = cbFI_MotionTP1ToTM1;
                                break;
                            } while(false);
                            float2 _21700;
                            do
                            {
                                float _18474 = 1.0f - _18249.y;
                                float4 _18485 = mul(float4((float2(_18249.x, _18474) * 2.0f) - 1.0f.xx, r_depth_tp1.Load(int3(int2(floor(_18249 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18346_dummy_parameter))))), 0)).x, 1.0f), _21699);
                                float _18487 = _18485.w;
                                if (!(_18487 > 9.9999999747524270787835121154785e-07f))
                                {
                                    _21700 = 1000000.0f.xx;
                                    break;
                                }
                                float2 _18500 = ((_18485.xy / _18487.xx) + 1.0f.xx) * 0.5f;
                                _21700 = float2(_18500.x - _18249.x, _18474 - _18500.y);
                                break;
                            } while(false);
                            float2 _18297 = abs(_21700);
                            if (any(bool2(_18297.x > 100000.0f.xx.x, _18297.y > 100000.0f.xx.y)))
                            {
                                _21701 = false;
                                break;
                            }
                            float _18305 = length(_21700 * _7169);
                            uint _18520_dummy_parameter;
                            bool _18319 = _18305 > ((8.0f * _7169.x) / float(cbFI_MvDepthLaneSize.x));
                            bool _18326;
                            if (_18319)
                            {
                                _18326 = length((r_motion_tp1.Load(int3(int2(floor(_18249 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18520_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _7169) < (0.20000000298023223876953125f * _18305);
                            }
                            else
                            {
                                _18326 = _18319;
                            }
                            _21701 = _18326;
                            break;
                        } while(false);
                        if (_21701)
                        {
                            uint _18551_dummy_parameter;
                            _21711 = -(r_motion_tp1.Load(int3(int2(floor(_18249 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _18551_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale);
                            break;
                        }
                        uint _18578_dummy_parameter;
                        float2 _21710;
                        do
                        {
                            float _18600 = 1.0f - _18249.y;
                            float4 _18611 = mul(float4((float2(_18249.x, _18600) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_18249 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18578_dummy_parameter))))), 0)).x, 1.0f), _14684);
                            float _18613 = _18611.w;
                            if (!(_18613 > 9.9999999747524270787835121154785e-07f))
                            {
                                _21710 = 1000000.0f.xx;
                                break;
                            }
                            float2 _18626 = ((_18611.xy / _18613.xx) + 1.0f.xx) * 0.5f;
                            _21710 = float2(_18626.x - _18249.x, _18600 - _18626.y);
                            break;
                        } while(false);
                        float2 _18264 = abs(_21710);
                        bool2 _18268 = any(bool2(_18264.x > 4.0f.xx.x, _18264.y > 4.0f.xx.y)).xx;
                        _21711 = float2(_18268.x ? 0.0f.xx.x : _21710.x, _18268.y ? 0.0f.xx.y : _21710.y);
                        break;
                    } while(false);
                    bool _18644 = all(bool2(_21694.x > 0.0f.xx.x, _21694.y > 0.0f.xx.y));
                    bool _18650;
                    if (_18644)
                    {
                        _18650 = all(bool2(_21694.x < 1.0f.xx.x, _21694.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _18650 = _18644;
                    }
                    float _21723;
                    if (_18650)
                    {
                        _21723 = length(((_21694 + (_21711 * cbFI_Timestep)) - _5482) * float2(cbFI_RenderSize));
                    }
                    else
                    {
                        _21723 = 1000000000.0f;
                    }
                    uint _18677_dummy_parameter;
                    float _18701 = log((r_depth_tm1.Load(int3(int2(floor(_18249 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18677_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    bool _17214 = _21723 < 0.3499999940395355224609375f;
                    bool _17216 = _21691 < 0.3499999940395355224609375f;
                    bool _17226;
                    if (_17214)
                    {
                        _17226 = (!_17216) || (_18701 > _21744);
                    }
                    else
                    {
                        _17226 = _17214;
                    }
                    bool _17239;
                    if (!_17226)
                    {
                        _17239 = ((!_17214) && (!_17216)) && (_21723 < _21691);
                    }
                    else
                    {
                        _17239 = _17226;
                    }
                    _23577 = _17239 ? _18701 : _21744;
                    bool2 _23578 = _17239.xx;
                    _23579 = float2(_23578.x ? _21694.x : _21692.x, _23578.y ? _21694.y : _21692.y);
                    _23580 = _17239 ? _21723 : _21691;
                }
                float3 _18710 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _21670, 0.0f).xyz;
                float3 _18718 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _21692, 0.0f).xyz;
                uint _18725_dummy_parameter;
                uint _18756_dummy_parameter;
                float _14787 = exp((_21669 * (-2.0f)) * (_21669 * 2.0f));
                float _14794 = exp((_21691 * (-2.0f)) * (_21691 * 2.0f));
                float _14807 = 1.0f / (1.0f + exp(-clamp((log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(clamp(_21692, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18756_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f)) - log(max(abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(clamp(_21670, 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18725_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)), 9.9999999747524270787835121154785e-07f))) * 6.666666507720947265625f, -60.0f, 60.0f)));
                float _14821 = ((_14787 * cbFI_Timestep) * ((1.0f - _14794) + ((_14794 * 2.0f) * _14807))) + (9.9999997473787516355514526367188e-05f * cbFI_Timestep);
                float _14831 = 1.0f - _14807;
                float _14838 = ((_14794 * _5707) * ((1.0f - _14787) + ((_14787 * 2.0f) * _14831))) + (9.9999997473787516355514526367188e-05f * _5707);
                float _14847 = (((_14787 * _14794) * 4.0f) * _14807) * _14831;
                float _14865 = (_14847 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, abs(dot(_18718 - _18710, float3(0.2989999949932098388671875f, 0.58700001239776611328125f, 0.114000000059604644775390625f)))))) + ((0.3499999940395355224609375f * (1.0f - _14847)) * max(_14787, _14794));
                if (_6855 == 30u)
                {
                    _21837 = _14865;
                    _21836 = _18710;
                    break;
                }
                if (_6855 == 31u)
                {
                    _21837 = _14865;
                    _21836 = _18718;
                    break;
                }
                if (_6855 == 32u)
                {
                    _21837 = _14865;
                    _21836 = float3(_14787, _14794, _14807);
                    break;
                }
                _21837 = _14865;
                _21836 = ((_18710 * _14821) + (_18718 * _14838)) / (_14821 + _14838).xxx;
                break;
            } while(false);
            _23275 = _21837;
            _23199 = _21836;
        }
        else
        {
            _23275 = 1.0f;
            _23199 = _23200;
        }
        uint _7185 = cbFI_pad0 & 255u;
        bool _23006;
        float3 _23198;
        if (_7185 != 0u)
        {
            float3 _7190 = r_present_backbuffer.Load(int3(_4970, 0)).xyz;
            float3 _7194 = r_current_interpolation_source.Load(int3(_4970, 0)).xyz;
            float3 _7198 = abs(_7190 - _7194);
            float3 _21846;
            if (_7185 == 2u)
            {
                _21846 = (abs(_7194) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _21846 = 0.000244140625f.xxx;
            }
            bool _7214 = any(bool3(_7198.x > _21846.x, _7198.y > _21846.y, _7198.z > _21846.z));
            bool3 _23581 = _7214.xxx;
            _23198 = float3(_23581.x ? _7190.x : _23199.x, _23581.y ? _7190.y : _23199.y, _23581.z ? _7190.z : _23199.z);
            _23006 = _7214;
        }
        else
        {
            _23198 = _23199;
            _23006 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _18794;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _18794);
        }
        float3 _23180;
        if (_6855 == 1u)
        {
            _23180 = lerp(_8711, _8719, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _23181;
            if (_6855 == 2u)
            {
                _23181 = lerp(_8727, _8735, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _23182;
                if (_6855 == 3u)
                {
                    _23182 = float(_23006).xxx;
                }
                else
                {
                    float3 _23183;
                    if (_6855 == 4u)
                    {
                        _23183 = float3(((_19739 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _23184;
                        if (_6855 == 5u)
                        {
                            _23184 = float3(((_8006 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _23185;
                            if (_6855 == 6u)
                            {
                                _23185 = float3(_21245.xy, _21245.z + _21245.w);
                            }
                            else
                            {
                                float3 _23186;
                                if (_6855 == 7u)
                                {
                                    _23186 = r_current_interpolation_source.Load(int3(_4970, 0)).xyz;
                                }
                                else
                                {
                                    float3 _23187;
                                    if (_6855 == 8u)
                                    {
                                        _23187 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _5482, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _23188;
                                        if (_6859)
                                        {
                                            uint _18816_dummy_parameter;
                                            uint _18848_dummy_parameter;
                                            _23188 = float3(log((r_depth_tp1.Load(int3(int2(floor(_5482 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _18816_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_5482 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _18848_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _23189;
                                            if (_6862)
                                            {
                                                _23189 = _8727;
                                            }
                                            else
                                            {
                                                float3 _23190;
                                                if (_6855 == 20u)
                                                {
                                                    _23190 = _8711;
                                                }
                                                else
                                                {
                                                    float3 _23191;
                                                    if (_6855 == 21u)
                                                    {
                                                        _23191 = _8719;
                                                    }
                                                    else
                                                    {
                                                        float3 _23192;
                                                        if (_6855 == 22u)
                                                        {
                                                            _23192 = _8735;
                                                        }
                                                        else
                                                        {
                                                            float3 _23193;
                                                            if (_6855 == 18u)
                                                            {
                                                                _23193 = _22454;
                                                            }
                                                            else
                                                            {
                                                                float3 _23194;
                                                                if (_6855 == 19u)
                                                                {
                                                                    _23194 = _22151;
                                                                }
                                                                else
                                                                {
                                                                    float3 _23195;
                                                                    if (_6855 == 23u)
                                                                    {
                                                                        _23195 = _21854;
                                                                    }
                                                                    else
                                                                    {
                                                                        float3 _23196;
                                                                        if (_6855 == 24u)
                                                                        {
                                                                            uint _7358 = (64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint(cbFI_FlowLaneSize.x * cbFI_FlowLaneSize.y);
                                                                            float _7363 = float(rw_nfru_diagnostics.Load<uint>((_7358 + 35u) * 4 + 0));
                                                                            float _21847;
                                                                            if (_7363 > 0.0f)
                                                                            {
                                                                                _21847 = float(rw_nfru_diagnostics.Load<uint>((_7358 + 34u) * 4 + 0)) / _7363;
                                                                            }
                                                                            else
                                                                            {
                                                                                _21847 = 0.0f;
                                                                            }
                                                                            _23196 = float3(float(rw_nfru_diagnostics.Load<uint>((_7358 + 32u) * 4 + 0) == 1u), clamp(asfloat(rw_nfru_diagnostics.Load<uint>((_7358 + 33u) * 4 + 0)) * 0.5f, 0.0f, 1.0f), _21847);
                                                                        }
                                                                        else
                                                                        {
                                                                            _23196 = _23198;
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
                                            _23188 = _23189;
                                        }
                                        _23187 = _23188;
                                    }
                                    _23186 = _23187;
                                }
                                _23185 = _23186;
                            }
                            _23184 = _23185;
                        }
                        _23183 = _23184;
                    }
                    _23182 = _23183;
                }
                _23181 = _23182;
            }
            _23180 = _23181;
        }
        float3 _23179;
        if ((_6855 >= 9u) && (_6855 <= 11u))
        {
            uint _7423 = 64u + uint((_19962.y * cbFI_MvDepthLaneSize.x) + _19962.x);
            uint _7427 = rw_nfru_diagnostics.Load<uint>(_7423 * 4 + 0) & 15u;
            float3 _23213;
            if (_6855 == 10u)
            {
                float3 _23178;
                if ((rw_nfru_diagnostics.Load<uint>(_7423 * 4 + 0) & 32u) != 0u)
                {
                    _23178 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _23177;
                    if ((rw_nfru_diagnostics.Load<uint>(_7423 * 4 + 0) & 16u) != 0u)
                    {
                        _23177 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _7448 = ((rw_nfru_diagnostics.Load<uint>(_7423 * 4 + 0) & 64u) != 0u).xxx;
                        _23177 = float3(_7448.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _7448.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _7448.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _23178 = _23177;
                }
                _23213 = _23178;
            }
            else
            {
                float3 _23214;
                if (_6855 == 11u)
                {
                    uint _7461 = (rw_nfru_diagnostics.Load<uint>(_7423 * 4 + 0) >> 8u) & 15u;
                    uint _7464 = (rw_nfru_diagnostics.Load<uint>(_7423 * 4 + 0) >> 12u) & 15u;
                    float3 _23170;
                    if ((_7427 == 2u) || (_7427 == 3u))
                    {
                        _23170 = _4652[_7427];
                    }
                    else
                    {
                        bool _7476 = _7461 == 3u;
                        bool _7478 = _7464 == 3u;
                        float3 _23171;
                        if (_7476 && _7478)
                        {
                            _23171 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _23172;
                            if (_7476)
                            {
                                _23172 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _23173;
                                if (_7478)
                                {
                                    _23173 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _23174;
                                    if ((_7461 == 4u) || (_7464 == 4u))
                                    {
                                        _23174 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _23175;
                                        if ((_7461 == 1u) || (_7464 == 1u))
                                        {
                                            _23175 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _23583 = (_7427 == 1u).xxx;
                                            _23175 = float3(_23583.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _23583.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _23583.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _23174 = _23175;
                                    }
                                    _23173 = _23174;
                                }
                                _23172 = _23173;
                            }
                            _23171 = _23172;
                        }
                        _23170 = _23171;
                    }
                    _23214 = _23170;
                }
                else
                {
                    _23214 = _4652[min(_7427, 7u)];
                }
                _23213 = _23214;
            }
            _23179 = _23213;
        }
        else
        {
            _23179 = _23180;
        }
        float4 _23217;
        if ((_6855 >= 14u) && (_6855 <= 16u))
        {
            float2 _23215;
            if (_6855 == 14u)
            {
                uint _7534_dummy_parameter;
                uint _7540_dummy_parameter;
                _23215 = r_flow_tm1.Load(int3(clamp(int2(floor(_5482 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _7534_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _7540_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _23216;
                if (_6855 == 16u)
                {
                    uint _18924 = r_warped_flow_qdata_tm1.Load(int3(_5498, 0)).x & 2147483647u;
                    uint _18956 = uint(max((int((_18924 >> 16u) & 15u) - 6), 0));
                    _23216 = ((float2(float((1 - (2 * int((_18924 >> 15u) & 1u))) * int(((_18924 >> uint(7)) & 127u) << _18956)), float((1 - (2 * int((_18924 >> 14u) & 1u))) * int((_18924 & 127u) << _18956))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _23216 = _8006 * float2(cbFI_DisplaySize);
                }
                _23215 = _23216;
            }
            uint2 _7573 = uint2(clamp(round(_23215 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _7575 = _7573.x;
            uint _7582 = _7573.y;
            _23217 = float4(float(_7575 & 255u), float((_7575 >> 8u) | ((_7582 & 15u) << 4u)), float(_7582 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _23218;
            if (_6855 == 17u)
            {
                _23218 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_5498, 0)).x != 0u), _5942, 0.0f, 1.0f);
            }
            else
            {
                _23218 = float4(_23179, 1.0f);
            }
            _23217 = _23218;
        }
        rw_output[_4970] = _23217.xyz;
        if (_7165)
        {
            uint _19001 = uint((_4970.y * cbFI_DisplaySize.x) + _4970.x) * 2u;
            rw_nfru_select.Store<uint>(_19001 * 4 + 0, spvPackHalf2x16(_23217.xy));
            rw_nfru_select.Store<uint>((_19001 + 1u) * 4 + 0, spvPackHalf2x16(float2(_23217.z, (_23006 || (_6855 != 0u)) ? 2.0f : _23275)));
        }
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _7640 = ((uint(_4970.y) * uint(cbFI_DisplaySize.x)) + uint(_4970.x)) * 6u;
            uint _19027 = spvPackHalf2x16(clamp(_8710.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_7640 * 4 + 0, (((_19027 & 32767u) >> 4u) | ((((_19027 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8710.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19062 = spvPackHalf2x16(clamp(_8718.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7640 + 1u) * 4 + 0, (((_19062 & 32767u) >> 4u) | ((((_19062 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8718.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19097 = spvPackHalf2x16(clamp(_8726.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7640 + 2u) * 4 + 0, (((_19097 & 32767u) >> 4u) | ((((_19097 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8726.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _19132 = spvPackHalf2x16(clamp(_8734.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7640 + 3u) * 4 + 0, (((_19132 & 32767u) >> 4u) | ((((_19132 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_8734.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _19159 = r_current_interpolation_source.Load(int3(_4970, 0));
            uint _19173 = spvPackHalf2x16(clamp(_19159.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_7640 + 4u) * 4 + 0, (((_19173 & 32767u) >> 4u) | ((((_19173 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_19159.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _23294;
            if (_23006 || (_6855 != 0u))
            {
                _23294 = 4294967295u;
            }
            else
            {
                uint _19208 = spvPackHalf2x16(clamp(_23217.xy, 0.0f.xx, 65000.0f.xx));
                _23294 = (((_19208 & 32767u) >> 4u) | ((((_19208 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_23217.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_7640 + 5u) * 4 + 0, _23294);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_4970] = float4(r_current_interpolation_source.Load(int3(_4970, 0)).xyz, 1.0f).xyz;
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
