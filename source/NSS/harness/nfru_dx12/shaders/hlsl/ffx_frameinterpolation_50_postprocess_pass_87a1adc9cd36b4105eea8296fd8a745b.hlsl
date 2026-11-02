static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1085[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1094[5] = { 2, 4, 7, 11, 16 };
static const float3 _3447[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3734 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3734.x >= cbFI_DisplaySize.x, _3734.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3734] = float4(r_present_backbuffer.Load(int3(_3734, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4140 = (float2(_3734) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4151 = int2(floor(_4140 * float2(cbFI_MvDepthLaneSize)));
        int2 _4156 = int2(floor(_4140 * float2(cbFI_FlowLaneSize)));
        float4 _6189 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4140 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6195 = r_warped_filled_flow_tm1.Load(int3(_4156, 0)).xy;
        float2 _6201 = r_warped_filled_motion_tp1.Load(int3(_4151, 0)).xy;
        bool _6223 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10438;
        if (_6223)
        {
            float _6236 = ((2.0f * _4140.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10438 = float2(atan(_6236) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4140.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6236 * _6236))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10438 = _4140;
        }
        bool _4177 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10459;
        bool _10480;
        int2 _10491;
        float3 _12031;
        if (_4177)
        {
            float _10440;
            float _10442;
            _10442 = 2.0f;
            _10440 = -1.0f;
            uint _3796[9];
            float _12485;
            float _12488;
            for (int _10439 = 0; _10439 < 9; _10442 = _12488, _10440 = _12485, _10439++)
            {
                _3796[_10439] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4151 + int2((_10439 % 3) - 1, (_10439 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3796[_10439] != 0u)
                {
                    float _12480;
                    if (_3796[_10439] == 0u)
                    {
                        _12480 = -1.0f;
                    }
                    else
                    {
                        _12480 = float((_3796[_10439] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12488 = min(_10442, _12480);
                    _12485 = max(_10440, _12480);
                }
                else
                {
                    _12488 = _10442;
                    _12485 = _10440;
                }
            }
            float _4223 = float(_10440 >= 0.0f);
            float3 _10229 = 0.0f.xxx;
            _10229.y = _4223;
            float2 _10460;
            bool _10481;
            int2 _10492;
            float3 _12032;
            if ((_10440 - _10442) > 0.0199999995529651641845703125f)
            {
                float _10448;
                int2 _10449;
                float2 _10450;
                int2 _10452;
                float2 _10458;
                _10458 = _6201;
                _10452 = _4151;
                _10450 = _6201;
                _10449 = _4151;
                _10448 = -1.0f;
                float _12493;
                int2 _12497;
                float2 _12508;
                int2 _12519;
                float2 _12552;
                float _12599;
                int _10447 = 0;
                float _12461 = 1000000000.0f;
                for (; _10447 < 9; _12461 = _12599, _10458 = _12552, _10452 = _12519, _10450 = _12508, _10449 = _12497, _10448 = _12493, _10447++)
                {
                    if (_3796[_10447] == 0u)
                    {
                        _12599 = _12461;
                        _12552 = _10458;
                        _12519 = _10452;
                        _12508 = _10450;
                        _12497 = _10449;
                        _12493 = _10448;
                        continue;
                    }
                    int2 _4258 = clamp(_4151 + int2((_10447 % 3) - 1, (_10447 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6311 = _3796[_10447] & 2147483647u;
                    uint _6343 = uint(max((int((_6311 >> 16u) & 15u) - 6), 0));
                    float2 _4264 = (float2(float((1 - (2 * int((_6311 >> 15u) & 1u))) * int(((_6311 >> uint(7)) & 127u) << _6343)), float((1 - (2 * int((_6311 >> 14u) & 1u))) * int((_6311 & 127u) << _6343))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12447;
                    if (_3796[_10447] == 0u)
                    {
                        _12447 = -1.0f;
                    }
                    else
                    {
                        _12447 = float((_3796[_10447] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4269 = _12447 - 0.100000001490116119384765625f;
                    float2 _12448;
                    if (_6223)
                    {
                        float2 _6420 = clamp((((_10438 + (_4264 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6423 = tan(_6420.x);
                        _12448 = (float2(_6423 / cbFI_DeviceToViewDepth.z, (tan(_6420.y) * sqrt(1.0f + (_6423 * _6423))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12448 = _10438 + (_4264 * cbFI_Timestep);
                    }
                    float _4276 = cbFI_Timestep - 1.0f;
                    float2 _12449;
                    if (_6223)
                    {
                        float2 _6491 = clamp((((_10438 + (_4264 * _4276)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6494 = tan(_6491.x);
                        _12449 = (float2(_6494 / cbFI_DeviceToViewDepth.z, (tan(_6491.y) * sqrt(1.0f + (_6494 * _6494))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12449 = _10438 + (_4264 * _4276);
                    }
                    bool _6527 = all(bool2(_12448.x > 0.0f.xx.x, _12448.y > 0.0f.xx.y));
                    bool _6533;
                    if (_6527)
                    {
                        _6533 = all(bool2(_12448.x < 1.0f.xx.x, _12448.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6533 = _6527;
                    }
                    float _12452;
                    if (_6533)
                    {
                        uint _6540_dummy_parameter;
                        _12452 = max((_4269 - (log((r_depth_tm1.Load(int3(int2(floor(_12448 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6540_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12452 = 0.0f;
                    }
                    bool _6570 = all(bool2(_12449.x > 0.0f.xx.x, _12449.y > 0.0f.xx.y));
                    bool _6576;
                    if (_6570)
                    {
                        _6576 = all(bool2(_12449.x < 1.0f.xx.x, _12449.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6576 = _6570;
                    }
                    float _12453;
                    if (_6576)
                    {
                        uint _6583_dummy_parameter;
                        _12453 = _12452 + max((_4269 - (log((r_depth_tp1.Load(int3(int2(floor(_12449 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6583_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12453 = _12452;
                    }
                    float _12494;
                    int2 _12498;
                    float2 _12509;
                    int2 _12520;
                    float2 _12553;
                    float _12600;
                    if (_12453 == 0.0f)
                    {
                        bool _4311 = _4269 > _10448;
                        bool2 _12608 = _4311.xx;
                        _12600 = _12461;
                        _12553 = float2(_12608.x ? _4264.x : _10458.x, _12608.y ? _4264.y : _10458.y);
                        _12520 = int2(_12608.x ? _4258.x : _10452.x, _12608.y ? _4258.y : _10452.y);
                        _12509 = _10450;
                        _12498 = _10449;
                        _12494 = _4311 ? _4269 : _10448;
                    }
                    else
                    {
                        bool _4320 = _12453 < _12461;
                        bool2 _12604 = _4320.xx;
                        _12600 = _4320 ? _12453 : _12461;
                        _12553 = _10458;
                        _12520 = _10452;
                        _12509 = float2(_12604.x ? _4264.x : _10450.x, _12604.y ? _4264.y : _10450.y);
                        _12498 = int2(_12604.x ? _4258.x : _10449.x, _12604.y ? _4258.y : _10449.y);
                        _12494 = _10448;
                    }
                    _12599 = _12600;
                    _12552 = _12553;
                    _12519 = _12520;
                    _12508 = _12509;
                    _12497 = _12498;
                    _12493 = _12494;
                }
                bool _4332 = _10448 < 0.0f;
                bool2 _12614 = _4332.xx;
                int2 _12617 = int2(_12614.x ? _10449.x : _10452.x, _12614.y ? _10449.y : _10452.y);
                _12032 = float3(1.0f, _4223, float(any(bool2(_12617.x != _4151.x, _12617.y != _4151.y))));
                _10492 = _12617;
                _10481 = _4332 ? false : true;
                _10460 = float2(_12614.x ? _10450.x : _10458.x, _12614.y ? _10450.y : _10458.y);
            }
            else
            {
                _12032 = _10229;
                _10492 = _4151;
                _10481 = false;
                _10460 = _6201;
            }
            _12031 = _12032;
            _10491 = _10492;
            _10480 = _10481;
            _10459 = _10460;
        }
        else
        {
            _12031 = 0.0f.xxx;
            _10491 = _4151;
            _10480 = false;
            _10459 = _6201;
        }
        float2 _10461;
        if (_6223)
        {
            float2 _6648 = clamp((((_10438 + (_10459 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6651 = tan(_6648.x);
            _10461 = (float2(_6651 / cbFI_DeviceToViewDepth.z, (tan(_6648.y) * sqrt(1.0f + (_6651 * _6651))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10461 = _10438 + (_10459 * cbFI_Timestep);
        }
        float _4355 = cbFI_Timestep - 1.0f;
        float2 _10463;
        if (_6223)
        {
            float2 _6719 = clamp((((_10438 + (_10459 * _4355)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6722 = tan(_6719.x);
            _10463 = (float2(_6722 / cbFI_DeviceToViewDepth.z, (tan(_6719.y) * sqrt(1.0f + (_6722 * _6722))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10463 = _10438 + (_10459 * _4355);
        }
        float _4360 = -cbFI_Timestep;
        float2 _10464;
        if (_6223)
        {
            float2 _6790 = clamp((((_10438 + (_6195 * _4360)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6793 = tan(_6790.x);
            _10464 = (float2(_6793 / cbFI_DeviceToViewDepth.z, (tan(_6790.y) * sqrt(1.0f + (_6793 * _6793))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10464 = _10438 + (_6195 * _4360);
        }
        float _4365 = 1.0f - cbFI_Timestep;
        float2 _10465;
        if (_6223)
        {
            float2 _6861 = clamp((((_10438 + (_6195 * _4365)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6864 = tan(_6861.x);
            _10465 = (float2(_6864 / cbFI_DeviceToViewDepth.z, (tan(_6861.y) * sqrt(1.0f + (_6864 * _6864))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10465 = _10438 + (_6195 * _4365);
        }
        float4 _6899 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10461, 0.0f);
        float3 _6900 = _6899.xyz;
        float4 _6907 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10463, 0.0f);
        float3 _6908 = _6907.xyz;
        float4 _6915 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10464, 0.0f);
        float3 _6916 = _6915.xyz;
        float4 _6923 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10465, 0.0f);
        float3 _6924 = _6923.xyz;
        float4 _6938 = exp(_6189 - max(max(max(_6189.x, _6189.y), _6189.z), _6189.w).xxxx);
        float4 _6945 = _6938 / (dot(_6938, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4384 = _4177 && (!_10480);
        bool _4393;
        if (_4384)
        {
            _4393 = (_6945.z + _6945.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4393 = _4384;
        }
        bool _4404;
        if (_4393)
        {
            _4404 = length((_10464 - _10461) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4404 = _4393;
        }
        bool _10504;
        if (_4404)
        {
            uint4 _6964 = r_warped_motion_qdata_tp1.Load(int3(_10491, 0));
            uint _6965 = _6964.x;
            bool _10507;
            if (_6965 != 0u)
            {
                float _10493;
                if (_6965 == 0u)
                {
                    _10493 = -1.0f;
                }
                else
                {
                    _10493 = float((_6965 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4414 = _10493 - 0.12000000476837158203125f;
                bool _6984 = all(bool2(_10464.x > 0.0f.xx.x, _10464.y > 0.0f.xx.y));
                bool _6990;
                if (_6984)
                {
                    _6990 = all(bool2(_10464.x < 1.0f.xx.x, _10464.y < 1.0f.xx.y));
                }
                else
                {
                    _6990 = _6984;
                }
                bool _4424;
                if (_6990)
                {
                    uint _6997_dummy_parameter;
                    _4424 = (log((r_depth_tm1.Load(int3(int2(floor(_10464 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6997_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4414;
                }
                else
                {
                    _4424 = _6990;
                }
                bool _4438;
                if (!_4424)
                {
                    bool _7027 = all(bool2(_10465.x > 0.0f.xx.x, _10465.y > 0.0f.xx.y));
                    bool _7033;
                    if (_7027)
                    {
                        _7033 = all(bool2(_10465.x < 1.0f.xx.x, _10465.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7033 = _7027;
                    }
                    bool _4436;
                    if (_7033)
                    {
                        uint _7040_dummy_parameter;
                        _4436 = (log((r_depth_tp1.Load(int3(int2(floor(_10465 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7040_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4414;
                    }
                    else
                    {
                        _4436 = _7033;
                    }
                    _4438 = _4436;
                }
                else
                {
                    _4438 = _4424;
                }
                _10507 = _4438;
            }
            else
            {
                _10507 = false;
            }
            _10504 = _10507;
        }
        else
        {
            _10504 = false;
        }
        bool _4443 = _10480 || _10504;
        bool _4448;
        if (_4443)
        {
            bool _7070 = all(bool2(_10461.x > 0.0f.xx.x, _10461.y > 0.0f.xx.y));
            bool _7076;
            if (_7070)
            {
                _7076 = all(bool2(_10461.x < 1.0f.xx.x, _10461.y < 1.0f.xx.y));
            }
            else
            {
                _7076 = _7070;
            }
            _4448 = _7076;
        }
        else
        {
            _4448 = _4443;
        }
        bool _4453;
        if (_4448)
        {
            bool _7081 = all(bool2(_10463.x > 0.0f.xx.x, _10463.y > 0.0f.xx.y));
            bool _7087;
            if (_7081)
            {
                _7087 = all(bool2(_10463.x < 1.0f.xx.x, _10463.y < 1.0f.xx.y));
            }
            else
            {
                _7087 = _7081;
            }
            _4453 = _7087;
        }
        else
        {
            _4453 = _4448;
        }
        float4 _10601;
        if (_4453)
        {
            float _4456 = _6945.x;
            float _4458 = _6945.y;
            float _4459 = _4456 + _4458;
            float _4464 = _6945.z + _6945.w;
            float _10522;
            if (_4459 > 0.001000000047497451305389404296875f)
            {
                _10522 = _4456 / _4459;
            }
            else
            {
                _10522 = _4365;
            }
            _10601 = float4(_4456 + (_4464 * _10522), _4458 + (_4464 * (1.0f - _10522)), 0.0f, 0.0f);
        }
        else
        {
            _10601 = _6945;
        }
        bool _7115 = (cbFI_pad0 & 1024u) != 0u;
        bool _7091 = !_7115;
        bool _7092 = !_7091;
        bool _7109;
        if (_7092)
        {
            _7109 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10491.y * cbFI_MvDepthLaneSize.x) + _10491.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _7109 = _7091;
        }
        bool _7141;
        if (_7092)
        {
            _7141 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4156.y * cbFI_FlowLaneSize.x) + _4156.x)) * 4 + 0) != 0u;
        }
        else
        {
            _7141 = _7091;
        }
        float _4499 = float(_7141);
        bool _10614;
        float4 _10645;
        float3 _11823;
        if (_7115)
        {
            bool _4509;
            if (_7109)
            {
                _4509 = all(bool2(_10461.x > 0.0f.xx.x, _10461.y > 0.0f.xx.y));
            }
            else
            {
                _4509 = _7109;
            }
            bool _4515;
            if (_4509)
            {
                _4515 = all(bool2(_10461.x < 1.0f.xx.x, _10461.y < 1.0f.xx.y));
            }
            else
            {
                _4515 = _4509;
            }
            bool _4522;
            if (_7109)
            {
                _4522 = all(bool2(_10463.x > 0.0f.xx.x, _10463.y > 0.0f.xx.y));
            }
            else
            {
                _4522 = _7109;
            }
            bool _4528;
            if (_4522)
            {
                _4528 = all(bool2(_10463.x < 1.0f.xx.x, _10463.y < 1.0f.xx.y));
            }
            else
            {
                _4528 = _4522;
            }
            bool _4535;
            if (_7141)
            {
                _4535 = all(bool2(_10464.x > 0.0f.xx.x, _10464.y > 0.0f.xx.y));
            }
            else
            {
                _4535 = _7141;
            }
            bool _4541;
            if (_4535)
            {
                _4541 = all(bool2(_10464.x < 1.0f.xx.x, _10464.y < 1.0f.xx.y));
            }
            else
            {
                _4541 = _4535;
            }
            bool _4548;
            if (_7141)
            {
                _4548 = all(bool2(_10465.x > 0.0f.xx.x, _10465.y > 0.0f.xx.y));
            }
            else
            {
                _4548 = _7141;
            }
            bool _4554;
            if (_4548)
            {
                _4554 = all(bool2(_10465.x < 1.0f.xx.x, _10465.y < 1.0f.xx.y));
            }
            else
            {
                _4554 = _4548;
            }
            bool _4556 = !_7109;
            if (_4556)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7183;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7183);
                }
            }
            bool _4561 = !_7141;
            if (_4561)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7193;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7193);
                }
            }
            if (_7109 && _4561)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7203;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7203);
                }
            }
            if (_4556 && _7141)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7213;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7213);
                }
            }
            float _4580 = float(_4515);
            float _4582 = float(_4528);
            bool _4585 = _4541 && _4554;
            float _10556;
            if (_4585)
            {
                _10556 = 1.0f;
            }
            else
            {
                _10556 = (_4541 || _4554) ? 0.5f : 0.0f;
            }
            bool _10561;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4515)) && (!_4528))
            {
                bool _4615;
                if (_4585)
                {
                    float _10559;
                    do
                    {
                        bool _7297 = all(bool2(_10464.x > 0.0f.xx.x, _10464.y > 0.0f.xx.y));
                        bool _7303;
                        if (_7297)
                        {
                            _7303 = all(bool2(_10464.x < 1.0f.xx.x, _10464.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7303 = _7297;
                        }
                        bool _7234 = !_7303;
                        bool _7241;
                        if (!_7234)
                        {
                            bool _7308 = all(bool2(_10465.x > 0.0f.xx.x, _10465.y > 0.0f.xx.y));
                            bool _7314;
                            if (_7308)
                            {
                                _7314 = all(bool2(_10465.x < 1.0f.xx.x, _10465.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7314 = _7308;
                            }
                            _7241 = !_7314;
                        }
                        else
                        {
                            _7241 = _7234;
                        }
                        if (_7241)
                        {
                            _10559 = 0.0f;
                            break;
                        }
                        uint _7321_dummy_parameter;
                        uint _7337_dummy_parameter;
                        float4 _7262 = mul(float4((float2(_10464.x, 1.0f - _10464.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10464 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7321_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7264 = _7262.w;
                        if (abs(_7264) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10559 = 0.0f;
                            break;
                        }
                        float _7275 = abs(cbFI_DeviceToViewDepth.y / ((_7262.z / _7264) - cbFI_DeviceToViewDepth.x));
                        float _7278 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10465 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7337_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10559 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7275 - _7278) / max(max(_7275, _7278), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4615 = _10559 >= 0.5f;
                }
                else
                {
                    _4615 = _4585;
                }
                bool _4623;
                if (_4615)
                {
                    _4623 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4623 = _4615;
                }
                bool _10562;
                if (_4623)
                {
                    uint _7387_dummy_parameter;
                    float2 _10560;
                    do
                    {
                        float _7413 = 1.0f - _10464.y;
                        float4 _7424 = mul(float4((float2(_10464.x, _7413) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10464 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7387_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7426 = _7424.w;
                        if (!(_7426 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10560 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7439 = ((_7424.xy / _7426.xx) + 1.0f.xx) * 0.5f;
                        _10560 = float2(_7439.x - _10464.x, _7413 - _7439.y);
                        break;
                    } while(false);
                    float2 _4636 = float2(cbFI_DisplaySize);
                    _10562 = length(((_10464 + _10560) - _10465) * _4636) <= ((0.100000001490116119384765625f * length(_10560 * _4636)) + 8.0f);
                }
                else
                {
                    _10562 = _4615;
                }
                _10561 = _10562;
            }
            else
            {
                _10561 = true;
            }
            bool _4650 = !_10561;
            bool _12618 = _4650 ? false : _4554;
            bool _12619 = _4650 ? false : _4541;
            bool _10615;
            float4 _10646;
            if (!(((_4515 && _4528) && _12619) && _12618))
            {
                float4 _4672 = _10601 * float4(_4580, _4582, float(_12619), float(_12618));
                float _4674 = dot(_4672, 1.0f.xxxx);
                bool _4677 = !(_4674 > 0.0f);
                float4 _10647;
                if (!_4677)
                {
                    _10647 = _4672 / _4674.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7461;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7461);
                    }
                    _10647 = 0.0f.xxxx;
                }
                _10646 = _10647;
                _10615 = _4677;
            }
            else
            {
                _10646 = _10601;
                _10615 = false;
            }
            _11823 = float3(_4580, _4582, _10556);
            _10645 = _10646;
            _10614 = _10615;
        }
        else
        {
            _11823 = float3(float(_7109), _4499, 0.0f);
            _10645 = _10601;
            _10614 = false;
        }
        bool _4695 = !_10614;
        float4 _10730;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4695)
        {
            float _4702 = _10645.x + _10645.y;
            float4 _10731;
            if (_4702 > 0.001000000047497451305389404296875f)
            {
                _10731 = float4(_10645.x / _4702, _10645.y / _4702, 0.0f, 0.0f);
            }
            else
            {
                _10731 = float4(_4365, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10730 = _10731;
        }
        else
        {
            _10730 = _10645;
        }
        float4 _10907;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4695) && _7109)
        {
            float _10704;
            do
            {
                uint4 _7601 = r_warped_motion_qdata_tp1.Load(int3(_10491, 0));
                uint _7602 = _7601.x;
                if (_7602 != 0u)
                {
                    float _10703;
                    if (_7602 == 0u)
                    {
                        _10703 = -1.0f;
                    }
                    else
                    {
                        _10703 = float((_7602 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10704 = _10703;
                    break;
                }
                int _10686;
                uint _10687;
                _10687 = _7602;
                _10686 = -1;
                uint _10702;
                for (; _10686 <= 1; _10687 = _10702, _10686++)
                {
                    _10702 = _10687;
                    for (int _10700 = -1; _10700 <= 1; )
                    {
                        _10702 = max(_10702, r_warped_motion_qdata_tp1.Load(int3(clamp(_10491 + int2(_10700, _10686), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10700++;
                        continue;
                    }
                }
                if (_10687 != 0u)
                {
                    float _10699;
                    if (_10687 == 0u)
                    {
                        _10699 = -1.0f;
                    }
                    else
                    {
                        _10699 = float((_10687 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10704 = _10699;
                    break;
                }
                uint _10689;
                _10689 = 4294967295u;
                uint _12589;
                for (int _10688 = 0; _10688 < 8; _10689 = _12589, _10688++)
                {
                    int _10692 = 0;
                    for (;;)
                    {
                        if (_10692 < 5)
                        {
                            int2 _7552 = _10491 + (_1085[_10688] * _1094[_10692].xx);
                            bool _7555 = any(bool2(_7552.x < int2(0, 0).x, _7552.y < int2(0, 0).y));
                            bool _7563;
                            if (!_7555)
                            {
                                _7563 = any(bool2(_7552.x >= cbFI_MvDepthLaneSize.x, _7552.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7563 = _7555;
                            }
                            if (_7563)
                            {
                                _12589 = _10689;
                                break;
                            }
                            uint4 _7641 = r_warped_motion_qdata_tp1.Load(int3(_7552, 0));
                            uint _7642 = _7641.x;
                            if (_7642 != 0u)
                            {
                                _12589 = min(_10689, _7642);
                                break;
                            }
                            _10692++;
                            continue;
                        }
                        else
                        {
                            _12589 = _10689;
                            break;
                        }
                    }
                }
                float _10691;
                if (_10689 == 4294967295u)
                {
                    _10691 = -1.0f;
                }
                else
                {
                    float _10690;
                    if (_10689 == 0u)
                    {
                        _10690 = -1.0f;
                    }
                    else
                    {
                        _10690 = float((_10689 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10691 = _10690;
                }
                _10704 = _10691;
                break;
            } while(false);
            float _4738 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4741 = r_warped_motion_qdata_tp1.Load(int3(_10491, 0)).x == 0u;
            bool _4747;
            if (_4741)
            {
                bool _7667 = all(bool2(_10461.x > 0.0f.xx.x, _10461.y > 0.0f.xx.y));
                bool _7673;
                if (_7667)
                {
                    _7673 = all(bool2(_10461.x < 1.0f.xx.x, _10461.y < 1.0f.xx.y));
                }
                else
                {
                    _7673 = _7667;
                }
                _4747 = _7673;
            }
            else
            {
                _4747 = _4741;
            }
            bool _4752;
            if (_4747)
            {
                bool _7678 = all(bool2(_10463.x > 0.0f.xx.x, _10463.y > 0.0f.xx.y));
                bool _7684;
                if (_7678)
                {
                    _7684 = all(bool2(_10463.x < 1.0f.xx.x, _10463.y < 1.0f.xx.y));
                }
                else
                {
                    _7684 = _7678;
                }
                _4752 = _7684;
            }
            else
            {
                _4752 = _4747;
            }
            bool _10716;
            float4 _10725;
            if (_4752)
            {
                uint _7691_dummy_parameter;
                float _7715 = log((r_depth_tm1.Load(int3(int2(floor(_10461 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7691_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _7723_dummy_parameter;
                float _7747 = log((r_depth_tp1.Load(int3(int2(floor(_10463 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7723_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _4763 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4770;
                if (_4763)
                {
                    _4770 = _7747 > (_7715 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4770 = _4763;
                }
                bool _10721;
                float4 _10743;
                if (_4770)
                {
                    _10743 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    _10721 = true;
                }
                else
                {
                    bool _4776 = (cbFI_NfruT2Flags & 32768u) != 0u;
                    bool _4783;
                    if (_4776)
                    {
                        _4783 = _7715 > (_7747 + 0.07999999821186065673828125f);
                    }
                    else
                    {
                        _4783 = _4776;
                    }
                    bool4 _12620 = _4783.xxxx;
                    _10743 = float4(_12620.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10730.x, _12620.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10730.y, _12620.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10730.z, _12620.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10730.w);
                    _10721 = _4783 ? true : false;
                }
                _10725 = _10743;
                _10716 = _10721;
            }
            else
            {
                _10725 = _10730;
                _10716 = false;
            }
            float4 _10798;
            if (_10716)
            {
                _10798 = 1.0f.xxxx;
            }
            else
            {
                bool _4794 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4800;
                if (_4794)
                {
                    _4800 = _10725.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4800 = _4794;
                }
                bool _4805;
                if (_4800)
                {
                    bool _7753 = all(bool2(_10463.x > 0.0f.xx.x, _10463.y > 0.0f.xx.y));
                    bool _7759;
                    if (_7753)
                    {
                        _7759 = all(bool2(_10463.x < 1.0f.xx.x, _10463.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7759 = _7753;
                    }
                    _4805 = _7759;
                }
                else
                {
                    _4805 = _4800;
                }
                float4 _10799;
                if (_4805)
                {
                    float _10752;
                    if (_10704 >= 0.0f)
                    {
                        _10752 = _10704 - _4738;
                    }
                    else
                    {
                        float _10748;
                        _10748 = 2.0f;
                        float _7816;
                        for (int _10747 = 0; _10747 < 24; _10748 = _7816, _10747++)
                        {
                            float _7780 = float(_10747 & 7) * 0.785398185253143310546875f;
                            int _7782 = _10747 >> 3;
                            int _10749;
                            if (_7782 == 0)
                            {
                                _10749 = 16;
                            }
                            else
                            {
                                _10749 = (_7782 == 1) ? 48 : 96;
                            }
                            uint _7848_dummy_parameter;
                            _7816 = min(_10748, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10463 + ((cbFI_MvDepthLaneSizeRcp * float(_10749)) * float2(cos(_7780), sin(_7780))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7848_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10752 = _10748;
                    }
                    uint _7880_dummy_parameter;
                    float4 _10800;
                    if (r_depth_tp1.Load(int3(int2(floor(_10463 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7880_dummy_parameter))))), 0)).x > ((exp((_10752 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10800 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10800 = 1.0f.xxxx;
                    }
                    _10799 = _10800;
                }
                else
                {
                    _10799 = 1.0f.xxxx;
                }
                _10798 = _10799;
            }
            bool _4833 = _10704 >= 0.0f;
            bool _4834 = (!_10716) && _4833;
            bool _4841;
            if (_4834)
            {
                _4841 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4841 = _4834;
            }
            bool _4847;
            if (_4841)
            {
                _4847 = _10725.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4847 = _4841;
            }
            bool _4852;
            if (_4847)
            {
                bool _7904 = all(bool2(_10461.x > 0.0f.xx.x, _10461.y > 0.0f.xx.y));
                bool _7910;
                if (_7904)
                {
                    _7910 = all(bool2(_10461.x < 1.0f.xx.x, _10461.y < 1.0f.xx.y));
                }
                else
                {
                    _7910 = _7904;
                }
                _4852 = _7910;
            }
            else
            {
                _4852 = _4847;
            }
            float4 _10823;
            if (_4852)
            {
                float _10792;
                if (_4833)
                {
                    _10792 = _10704 - _4738;
                }
                else
                {
                    float _10788;
                    _10788 = 2.0f;
                    float _7967;
                    for (int _10787 = 0; _10787 < 24; _10788 = _7967, _10787++)
                    {
                        float _7931 = float(_10787 & 7) * 0.785398185253143310546875f;
                        int _7933 = _10787 >> 3;
                        int _10789;
                        if (_7933 == 0)
                        {
                            _10789 = 16;
                        }
                        else
                        {
                            _10789 = (_7933 == 1) ? 48 : 96;
                        }
                        uint _7983_dummy_parameter;
                        _7967 = min(_10788, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10461 + ((cbFI_MvDepthLaneSizeRcp * float(_10789)) * float2(cos(_7931), sin(_7931))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7983_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10792 = _10788;
                }
                uint _8031_dummy_parameter;
                float4 _10824;
                if (r_depth_tm1.Load(int3(int2(floor(_10461 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8031_dummy_parameter))))), 0)).x > ((exp((_10792 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10301 = _10798;
                    _10301.x = 0.0f;
                    _10824 = _10301;
                }
                else
                {
                    _10824 = _10798;
                }
                _10823 = _10824;
            }
            else
            {
                _10823 = _10798;
            }
            float4 _10836;
            if (_4834)
            {
                float _8057 = (exp(((_10704 - _4738) + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                bool _4890 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4896;
                if (_4890)
                {
                    _4896 = _10725.w > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4896 = _4890;
                }
                bool _4901;
                if (_4896)
                {
                    bool _8062 = all(bool2(_10465.x > 0.0f.xx.x, _10465.y > 0.0f.xx.y));
                    bool _8068;
                    if (_8062)
                    {
                        _8068 = all(bool2(_10465.x < 1.0f.xx.x, _10465.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8068 = _8062;
                    }
                    _4901 = _8068;
                }
                else
                {
                    _4901 = _4896;
                }
                bool _4909;
                if (_4901)
                {
                    uint _8075_dummy_parameter;
                    _4909 = r_depth_tp1.Load(int3(int2(floor(_10465 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8075_dummy_parameter))))), 0)).x > _8057;
                }
                else
                {
                    _4909 = _4901;
                }
                float4 _10834;
                if (_4909)
                {
                    float4 _10304 = _10823;
                    _10304.w = 0.0f;
                    _10834 = _10304;
                }
                else
                {
                    _10834 = _10823;
                }
                bool _4916 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4922;
                if (_4916)
                {
                    _4922 = _10725.z > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4922 = _4916;
                }
                bool _4927;
                if (_4922)
                {
                    bool _8092 = all(bool2(_10464.x > 0.0f.xx.x, _10464.y > 0.0f.xx.y));
                    bool _8098;
                    if (_8092)
                    {
                        _8098 = all(bool2(_10464.x < 1.0f.xx.x, _10464.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8098 = _8092;
                    }
                    _4927 = _8098;
                }
                else
                {
                    _4927 = _4922;
                }
                bool _4935;
                if (_4927)
                {
                    uint _8105_dummy_parameter;
                    _4935 = r_depth_tm1.Load(int3(int2(floor(_10464 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8105_dummy_parameter))))), 0)).x > _8057;
                }
                else
                {
                    _4935 = _4927;
                }
                float4 _10837;
                if (_4935)
                {
                    float4 _10307 = _10834;
                    _10307.z = 0.0f;
                    _10837 = _10307;
                }
                else
                {
                    _10837 = _10834;
                }
                _10836 = _10837;
            }
            else
            {
                _10836 = _10823;
            }
            float4 _10908;
            if (any(bool4(_10836.x < 1.0f.xxxx.x, _10836.y < 1.0f.xxxx.y, _10836.z < 1.0f.xxxx.z, _10836.w < 1.0f.xxxx.w)))
            {
                float4 _4946 = _10725 * _10836;
                float _4948 = dot(_4946, 1.0f.xxxx);
                float4 _10909;
                if (_4948 > 0.0f)
                {
                    _10909 = _4946 / _4948.xxxx;
                }
                else
                {
                    bool _4959 = _10836.y == 0.0f;
                    bool _4965;
                    if (_4959)
                    {
                        _4965 = _10836.x > 0.0f;
                    }
                    else
                    {
                        _4965 = _4959;
                    }
                    bool _4970;
                    if (_4965)
                    {
                        bool _8122 = all(bool2(_10461.x > 0.0f.xx.x, _10461.y > 0.0f.xx.y));
                        bool _8128;
                        if (_8122)
                        {
                            _8128 = all(bool2(_10461.x < 1.0f.xx.x, _10461.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8128 = _8122;
                        }
                        _4970 = _8128;
                    }
                    else
                    {
                        _4970 = _4965;
                    }
                    float4 _10910;
                    if (_4970)
                    {
                        _10910 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4975 = _10836.x == 0.0f;
                        bool _4981;
                        if (_4975)
                        {
                            _4981 = _10836.y > 0.0f;
                        }
                        else
                        {
                            _4981 = _4975;
                        }
                        bool _4986;
                        if (_4981)
                        {
                            bool _8133 = all(bool2(_10463.x > 0.0f.xx.x, _10463.y > 0.0f.xx.y));
                            bool _8139;
                            if (_8133)
                            {
                                _8139 = all(bool2(_10463.x < 1.0f.xx.x, _10463.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _8139 = _8133;
                            }
                            _4986 = _8139;
                        }
                        else
                        {
                            _4986 = _4981;
                        }
                        bool4 _12623 = _4986.xxxx;
                        _10910 = float4(_12623.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10725.x, _12623.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10725.y, _12623.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10725.z, _12623.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10725.w);
                    }
                    _10909 = _10910;
                }
                _10908 = _10909;
            }
            else
            {
                _10908 = _10725;
            }
            _10907 = _10908;
        }
        else
        {
            _10907 = _10730;
        }
        float4 _11486;
        bool _11506;
        float3 _11620;
        if (((cbFI_pad0 & 32768u) != 0u) && _4695)
        {
            bool _5003 = _10907.x > 0.00999999977648258209228515625f;
            bool _5006 = _10907.y > 0.00999999977648258209228515625f;
            bool _5015 = (_10907.z + _10907.w) > 0.0199999995529651641845703125f;
            bool _5021;
            if (_5015)
            {
                bool _8144 = all(bool2(_10464.x > 0.0f.xx.x, _10464.y > 0.0f.xx.y));
                bool _8150;
                if (_8144)
                {
                    _8150 = all(bool2(_10464.x < 1.0f.xx.x, _10464.y < 1.0f.xx.y));
                }
                else
                {
                    _8150 = _8144;
                }
                _5021 = _8150;
            }
            else
            {
                _5021 = _5015;
            }
            bool _5026;
            if (_5021)
            {
                bool _8155 = all(bool2(_10465.x > 0.0f.xx.x, _10465.y > 0.0f.xx.y));
                bool _8161;
                if (_8155)
                {
                    _8161 = all(bool2(_10465.x < 1.0f.xx.x, _10465.y < 1.0f.xx.y));
                }
                else
                {
                    _8161 = _8155;
                }
                _5026 = _8161;
            }
            else
            {
                _5026 = _5021;
            }
            bool _5033;
            if (_5026)
            {
                float _10918;
                do
                {
                    bool _8244 = all(bool2(_10464.x > 0.0f.xx.x, _10464.y > 0.0f.xx.y));
                    bool _8250;
                    if (_8244)
                    {
                        _8250 = all(bool2(_10464.x < 1.0f.xx.x, _10464.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8250 = _8244;
                    }
                    bool _8181 = !_8250;
                    bool _8188;
                    if (!_8181)
                    {
                        bool _8255 = all(bool2(_10465.x > 0.0f.xx.x, _10465.y > 0.0f.xx.y));
                        bool _8261;
                        if (_8255)
                        {
                            _8261 = all(bool2(_10465.x < 1.0f.xx.x, _10465.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8261 = _8255;
                        }
                        _8188 = !_8261;
                    }
                    else
                    {
                        _8188 = _8181;
                    }
                    if (_8188)
                    {
                        _10918 = 0.0f;
                        break;
                    }
                    uint _8268_dummy_parameter;
                    uint _8284_dummy_parameter;
                    float4 _8209 = mul(float4((float2(_10464.x, 1.0f - _10464.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10464 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8268_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _8211 = _8209.w;
                    if (abs(_8211) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10918 = 0.0f;
                        break;
                    }
                    float _8222 = abs(cbFI_DeviceToViewDepth.y / ((_8209.z / _8211) - cbFI_DeviceToViewDepth.x));
                    float _8225 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10465 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8284_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10918 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8222 - _8225) / max(max(_8222, _8225), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _5033 = _10918 < 0.5f;
            }
            else
            {
                _5033 = _5026;
            }
            float4 _10933;
            if (_5033)
            {
                uint _8334_dummy_parameter;
                uint _8365_dummy_parameter;
                float4 _10934;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10464 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8334_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10465 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8365_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10934 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10934 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10933 = _10934;
            }
            else
            {
                _10933 = 1.0f.xxxx;
            }
            bool _5057;
            if (_7109)
            {
                bool _8394 = all(bool2(_10461.x > 0.0f.xx.x, _10461.y > 0.0f.xx.y));
                bool _8400;
                if (_8394)
                {
                    _8400 = all(bool2(_10461.x < 1.0f.xx.x, _10461.y < 1.0f.xx.y));
                }
                else
                {
                    _8400 = _8394;
                }
                _5057 = _8400;
            }
            else
            {
                _5057 = _7109;
            }
            bool _5063;
            if (_7109)
            {
                bool _8405 = all(bool2(_10463.x > 0.0f.xx.x, _10463.y > 0.0f.xx.y));
                bool _8411;
                if (_8405)
                {
                    _8411 = all(bool2(_10463.x < 1.0f.xx.x, _10463.y < 1.0f.xx.y));
                }
                else
                {
                    _8411 = _8405;
                }
                _5063 = _8411;
            }
            else
            {
                _5063 = _7109;
            }
            bool _5069;
            if (_7141)
            {
                bool _8416 = all(bool2(_10464.x > 0.0f.xx.x, _10464.y > 0.0f.xx.y));
                bool _8422;
                if (_8416)
                {
                    _8422 = all(bool2(_10464.x < 1.0f.xx.x, _10464.y < 1.0f.xx.y));
                }
                else
                {
                    _8422 = _8416;
                }
                _5069 = _8422;
            }
            else
            {
                _5069 = _7141;
            }
            bool _5075;
            if (_7141)
            {
                bool _8427 = all(bool2(_10465.x > 0.0f.xx.x, _10465.y > 0.0f.xx.y));
                bool _8433;
                if (_8427)
                {
                    _8433 = all(bool2(_10465.x < 1.0f.xx.x, _10465.y < 1.0f.xx.y));
                }
                else
                {
                    _8433 = _8427;
                }
                _5075 = _8433;
            }
            else
            {
                _5075 = _7141;
            }
            bool _5078 = _5069 != _5075;
            bool _5084;
            if (_5078)
            {
                _5084 = _5057 || _5063;
            }
            else
            {
                _5084 = _5078;
            }
            float4 _11032;
            if (_5084)
            {
                float4 _10334 = _10933;
                _10334.z = 0.0f;
                _10334.w = 0.0f;
                _11032 = _10334;
            }
            else
            {
                _11032 = _10933;
            }
            bool _5091 = _5057 && _5003;
            bool _5094 = _5063 && _5006;
            float4 _11137;
            float3 _11721;
            if (_5091 || _5094)
            {
                float _11027;
                do
                {
                    uint4 _8572 = r_warped_motion_qdata_tp1.Load(int3(_10491, 0));
                    uint _8573 = _8572.x;
                    if (_8573 != 0u)
                    {
                        float _11026;
                        if (_8573 == 0u)
                        {
                            _11026 = -1.0f;
                        }
                        else
                        {
                            _11026 = float((_8573 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11027 = _11026;
                        break;
                    }
                    int _11009;
                    uint _11010;
                    _11010 = _8573;
                    _11009 = -1;
                    uint _11025;
                    for (; _11009 <= 1; _11010 = _11025, _11009++)
                    {
                        _11025 = _11010;
                        for (int _11023 = -1; _11023 <= 1; )
                        {
                            _11025 = max(_11025, r_warped_motion_qdata_tp1.Load(int3(clamp(_10491 + int2(_11023, _11009), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11023++;
                            continue;
                        }
                    }
                    if (_11010 != 0u)
                    {
                        float _11022;
                        if (_11010 == 0u)
                        {
                            _11022 = -1.0f;
                        }
                        else
                        {
                            _11022 = float((_11010 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11027 = _11022;
                        break;
                    }
                    uint _11012;
                    _11012 = 4294967295u;
                    uint _12590;
                    for (int _11011 = 0; _11011 < 8; _11012 = _12590, _11011++)
                    {
                        int _11015 = 0;
                        for (;;)
                        {
                            if (_11015 < 5)
                            {
                                int2 _8523 = _10491 + (_1085[_11011] * _1094[_11015].xx);
                                bool _8526 = any(bool2(_8523.x < int2(0, 0).x, _8523.y < int2(0, 0).y));
                                bool _8534;
                                if (!_8526)
                                {
                                    _8534 = any(bool2(_8523.x >= cbFI_MvDepthLaneSize.x, _8523.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8534 = _8526;
                                }
                                if (_8534)
                                {
                                    _12590 = _11012;
                                    break;
                                }
                                uint4 _8612 = r_warped_motion_qdata_tp1.Load(int3(_8523, 0));
                                uint _8613 = _8612.x;
                                if (_8613 != 0u)
                                {
                                    _12590 = min(_11012, _8613);
                                    break;
                                }
                                _11015++;
                                continue;
                            }
                            else
                            {
                                _12590 = _11012;
                                break;
                            }
                        }
                    }
                    float _11014;
                    if (_11012 == 4294967295u)
                    {
                        _11014 = -1.0f;
                    }
                    else
                    {
                        float _11013;
                        if (_11012 == 0u)
                        {
                            _11013 = -1.0f;
                        }
                        else
                        {
                            _11013 = float((_11012 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11014 = _11013;
                    }
                    _11027 = _11014;
                    break;
                } while(false);
                bool _5102 = _11027 < 0.0f;
                float _11028;
                if (_5102)
                {
                    _11028 = 0.0f;
                }
                else
                {
                    _11028 = _11027 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8634_dummy_parameter;
                uint _8666_dummy_parameter;
                float4 _11065;
                if ((_5102 && _5091) && _5094)
                {
                    uint _8698_dummy_parameter;
                    float _8722 = log((r_depth_tm1.Load(int3(int2(floor(_10461 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8698_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8730_dummy_parameter;
                    float _8754 = log((r_depth_tp1.Load(int3(int2(floor(_10463 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8730_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _11066;
                    if (_8722 > (_8754 + 0.07999999821186065673828125f))
                    {
                        float4 _10338 = _11032;
                        _10338.x = 0.0f;
                        _11066 = _10338;
                    }
                    else
                    {
                        float4 _11067;
                        if (_8754 > (_8722 + 0.07999999821186065673828125f))
                        {
                            float4 _10340 = _11032;
                            _10340.y = 0.0f;
                            _11067 = _10340;
                        }
                        else
                        {
                            _11067 = _11032;
                        }
                        _11066 = _11067;
                    }
                    _11065 = _11066;
                }
                else
                {
                    _11065 = _11032;
                }
                float _5154 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5156 = _11027 >= 0.0f;
                float _11048;
                if (_5156)
                {
                    _11048 = _11027 - _5154;
                }
                else
                {
                    float _11044;
                    if (_5091)
                    {
                        float _11043;
                        _11043 = 2.0f;
                        float _8812;
                        for (int _11042 = 0; _11042 < 24; _11043 = _8812, _11042++)
                        {
                            float _8776 = float(_11042 & 7) * 0.785398185253143310546875f;
                            int _8778 = _11042 >> 3;
                            int _11045;
                            if (_8778 == 0)
                            {
                                _11045 = 16;
                            }
                            else
                            {
                                _11045 = (_8778 == 1) ? 48 : 96;
                            }
                            uint _8828_dummy_parameter;
                            _8812 = min(_11043, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10461 + ((cbFI_MvDepthLaneSizeRcp * float(_11045)) * float2(cos(_8776), sin(_8776))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8828_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11044 = _11043;
                    }
                    else
                    {
                        _11044 = 0.0f;
                    }
                    _11048 = _11044;
                }
                float _11055;
                if (_5156)
                {
                    _11055 = _11027 - _5154;
                }
                else
                {
                    float _11051;
                    if (_5094)
                    {
                        float _11050;
                        _11050 = 2.0f;
                        float _8926;
                        for (int _11049 = 0; _11049 < 24; _11050 = _8926, _11049++)
                        {
                            float _8890 = float(_11049 & 7) * 0.785398185253143310546875f;
                            int _8892 = _11049 >> 3;
                            int _11052;
                            if (_8892 == 0)
                            {
                                _11052 = 16;
                            }
                            else
                            {
                                _11052 = (_8892 == 1) ? 48 : 96;
                            }
                            uint _8958_dummy_parameter;
                            _8926 = min(_11050, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10463 + ((cbFI_MvDepthLaneSizeRcp * float(_11052)) * float2(cos(_8890), sin(_8890))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8958_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _11051 = _11050;
                    }
                    else
                    {
                        _11051 = 0.0f;
                    }
                    _11055 = _11051;
                }
                float _11056;
                if (_5091)
                {
                    uint _8990_dummy_parameter;
                    _11056 = r_depth_tm1.Load(int3(int2(floor(_10461 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8990_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11056 = 0.0f;
                }
                float _11057;
                if (_5094)
                {
                    uint _9009_dummy_parameter;
                    _11057 = r_depth_tp1.Load(int3(int2(floor(_10463 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9009_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _11057 = 0.0f;
                }
                bool _5211;
                if (_5091)
                {
                    _5211 = _11056 > ((exp((_11048 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5211 = _5091;
                }
                float4 _11073;
                if (_5211)
                {
                    float4 _10342 = _11065;
                    _10342.x = 0.0f;
                    _11073 = _10342;
                }
                else
                {
                    _11073 = _11065;
                }
                bool _5223;
                if (_5094)
                {
                    _5223 = _11057 > ((exp((_11055 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5223 = _5094;
                }
                float4 _11075;
                if (_5223)
                {
                    float4 _10344 = _11073;
                    _10344.y = 0.0f;
                    _11075 = _10344;
                }
                else
                {
                    _11075 = _11073;
                }
                float4 _11138;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5156)
                {
                    bool _5243;
                    if (_5091)
                    {
                        _5243 = _11056 < ((exp((_11048 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5243 = _5091;
                    }
                    float4 _11077;
                    if (_5243)
                    {
                        float4 _10346 = _11075;
                        _10346.x = 0.0f;
                        _11077 = _10346;
                    }
                    else
                    {
                        _11077 = _11075;
                    }
                    bool _5255;
                    if (_5094)
                    {
                        _5255 = _11057 < ((exp((_11055 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5255 = _5094;
                    }
                    float4 _11139;
                    if (_5255)
                    {
                        float4 _10348 = _11077;
                        _10348.y = 0.0f;
                        _11139 = _10348;
                    }
                    else
                    {
                        _11139 = _11077;
                    }
                    _11138 = _11139;
                }
                else
                {
                    _11138 = _11075;
                }
                _11721 = float3(_11028, log((r_depth_tm1.Load(int3(int2(floor(_10461 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8634_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_10463 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8666_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _11137 = _11138;
            }
            else
            {
                _11721 = float3(0.0f, 0.0f, 0.5f);
                _11137 = _11032;
            }
            bool _5266 = ((cbFI_NfruT2Flags & 16u) != 0u) && _5015;
            bool _5272;
            if (_5266)
            {
                _5272 = _5069 || _5075;
            }
            else
            {
                _5272 = _5266;
            }
            float4 _11160;
            if (_5272)
            {
                float _11132;
                do
                {
                    uint4 _9188 = r_warped_motion_qdata_tp1.Load(int3(_10491, 0));
                    uint _9189 = _9188.x;
                    if (_9189 != 0u)
                    {
                        float _11131;
                        if (_9189 == 0u)
                        {
                            _11131 = -1.0f;
                        }
                        else
                        {
                            _11131 = float((_9189 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11132 = _11131;
                        break;
                    }
                    int _11114;
                    uint _11115;
                    _11115 = _9189;
                    _11114 = -1;
                    uint _11130;
                    for (; _11114 <= 1; _11115 = _11130, _11114++)
                    {
                        _11130 = _11115;
                        for (int _11128 = -1; _11128 <= 1; )
                        {
                            _11130 = max(_11130, r_warped_motion_qdata_tp1.Load(int3(clamp(_10491 + int2(_11128, _11114), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _11128++;
                            continue;
                        }
                    }
                    if (_11115 != 0u)
                    {
                        float _11127;
                        if (_11115 == 0u)
                        {
                            _11127 = -1.0f;
                        }
                        else
                        {
                            _11127 = float((_11115 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11132 = _11127;
                        break;
                    }
                    uint _11117;
                    _11117 = 4294967295u;
                    uint _12591;
                    for (int _11116 = 0; _11116 < 8; _11117 = _12591, _11116++)
                    {
                        int _11120 = 0;
                        for (;;)
                        {
                            if (_11120 < 5)
                            {
                                int2 _9139 = _10491 + (_1085[_11116] * _1094[_11120].xx);
                                bool _9142 = any(bool2(_9139.x < int2(0, 0).x, _9139.y < int2(0, 0).y));
                                bool _9150;
                                if (!_9142)
                                {
                                    _9150 = any(bool2(_9139.x >= cbFI_MvDepthLaneSize.x, _9139.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _9150 = _9142;
                                }
                                if (_9150)
                                {
                                    _12591 = _11117;
                                    break;
                                }
                                uint4 _9228 = r_warped_motion_qdata_tp1.Load(int3(_9139, 0));
                                uint _9229 = _9228.x;
                                if (_9229 != 0u)
                                {
                                    _12591 = min(_11117, _9229);
                                    break;
                                }
                                _11120++;
                                continue;
                            }
                            else
                            {
                                _12591 = _11117;
                                break;
                            }
                        }
                    }
                    float _11119;
                    if (_11117 == 4294967295u)
                    {
                        _11119 = -1.0f;
                    }
                    else
                    {
                        float _11118;
                        if (_11117 == 0u)
                        {
                            _11118 = -1.0f;
                        }
                        else
                        {
                            _11118 = float((_11117 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _11119 = _11118;
                    }
                    _11132 = _11119;
                    break;
                } while(false);
                float4 _11161;
                if (_11132 >= 0.0f)
                {
                    float _9250 = (exp((_11132 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5291;
                    if (_5069)
                    {
                        uint _9257_dummy_parameter;
                        _5291 = r_depth_tm1.Load(int3(int2(floor(_10464 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9257_dummy_parameter))))), 0)).x > _9250;
                    }
                    else
                    {
                        _5291 = _5069;
                    }
                    float4 _11150;
                    if (_5291)
                    {
                        float4 _10350 = _11137;
                        _10350.z = 0.0f;
                        _11150 = _10350;
                    }
                    else
                    {
                        _11150 = _11137;
                    }
                    bool _5303;
                    if (_5075)
                    {
                        uint _9276_dummy_parameter;
                        _5303 = r_depth_tp1.Load(int3(int2(floor(_10465 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9276_dummy_parameter))))), 0)).x > _9250;
                    }
                    else
                    {
                        _5303 = _5075;
                    }
                    float4 _11162;
                    if (_5303)
                    {
                        float4 _10352 = _11150;
                        _10352.w = 0.0f;
                        _11162 = _10352;
                    }
                    else
                    {
                        _11162 = _11150;
                    }
                    _11161 = _11162;
                }
                else
                {
                    _11161 = _11137;
                }
                _11160 = _11161;
            }
            else
            {
                _11160 = _11137;
            }
            bool _5311 = _5057 != _5063;
            bool _5318;
            if (_5311)
            {
                _5318 = _5057 ? _5003 : _5006;
            }
            else
            {
                _5318 = _5311;
            }
            bool _5325;
            if (_5318)
            {
                _5325 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5325 = _5318;
            }
            float4 _11245;
            if (_5325)
            {
                bool2 _5330 = _5057.xx;
                float2 _5331 = float2(_5330.x ? _10461.x : _10463.x, _5330.y ? _10461.y : _10463.y);
                float _11152;
                if (_5057)
                {
                    uint _9295_dummy_parameter;
                    _11152 = r_depth_tm1.Load(int3(int2(floor(_5331 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9295_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9311_dummy_parameter;
                    _11152 = r_depth_tp1.Load(int3(int2(floor(_5331 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9311_dummy_parameter))))), 0)).x;
                }
                float4x4 _11153;
                if (_5057)
                {
                    _11153 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _11153 = cbFI_MotionTP1ToTM1;
                }
                float2 _11154;
                do
                {
                    float _9338 = _5331.x;
                    float _9341 = 1.0f - _5331.y;
                    float4 _9352 = mul(float4((float2(_9338, _9341) * 2.0f) - 1.0f.xx, _11152, 1.0f), _11153);
                    float _9354 = _9352.w;
                    if (!(_9354 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11154 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9367 = ((_9352.xy / _9354.xx) + 1.0f.xx) * 0.5f;
                    _11154 = float2(_9367.x - _9338, _9341 - _9367.y);
                    break;
                } while(false);
                float2 _5361 = float2(cbFI_DisplaySize);
                float4 _11246;
                if (!(length(((_5331 + _11154) - float2(_5330.x ? _10463.x : _10461.x, _5330.y ? _10463.y : _10461.y)) * _5361) <= ((0.100000001490116119384765625f * length(_11154 * _5361)) + 8.0f)))
                {
                    float4 _11247;
                    if (_5057)
                    {
                        float4 _10362 = _11160;
                        _10362.x = 0.0f;
                        _11247 = _10362;
                    }
                    else
                    {
                        float4 _10364 = _11160;
                        _10364.y = 0.0f;
                        _11247 = _10364;
                    }
                    _11246 = _11247;
                }
                else
                {
                    _11246 = _11160;
                }
                _11245 = _11246;
            }
            else
            {
                _11245 = _11160;
            }
            float4 _5386 = _10907 * _11245;
            float _5388 = dot(_5386, 1.0f.xxxx);
            float4 _11487;
            bool _11507;
            if (_5388 > 0.0f)
            {
                _11507 = _10614;
                _11487 = _5386 / _5388.xxxx;
            }
            else
            {
                bool _5399 = any(bool4(_11245.x < 1.0f.xxxx.x, _11245.y < 1.0f.xxxx.y, _11245.z < 1.0f.xxxx.z, _11245.w < 1.0f.xxxx.w));
                if (_5399)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9389;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9389);
                    }
                }
                bool4 _12626 = _5399.xxxx;
                _11507 = _5399 ? true : _10614;
                _11487 = float4(_12626.x ? 0.0f.xxxx.x : _10907.x, _12626.y ? 0.0f.xxxx.y : _10907.y, _12626.z ? 0.0f.xxxx.z : _10907.z, _12626.w ? 0.0f.xxxx.w : _10907.w);
            }
            _11620 = _11721;
            _11506 = _11507;
            _11486 = _11487;
        }
        else
        {
            _11620 = float3(0.0f, 0.0f, 0.5f);
            _11506 = _10614;
            _11486 = _10907;
        }
        uint _5408 = (cbFI_pad0 >> 24u) & 31u;
        uint _5412 = (cbFI_pad0 >> 16u) & 255u;
        bool _5414 = _5408 != 0u;
        bool _5416 = _5412 == 12u;
        bool _5419 = _5412 == 13u;
        float4 _11503;
        if ((_5414 || _5416) || _5419)
        {
            float _11248;
            do
            {
                bool _9473 = all(bool2(_10464.x > 0.0f.xx.x, _10464.y > 0.0f.xx.y));
                bool _9479;
                if (_9473)
                {
                    _9479 = all(bool2(_10464.x < 1.0f.xx.x, _10464.y < 1.0f.xx.y));
                }
                else
                {
                    _9479 = _9473;
                }
                bool _9410 = !_9479;
                bool _9417;
                if (!_9410)
                {
                    bool _9484 = all(bool2(_10465.x > 0.0f.xx.x, _10465.y > 0.0f.xx.y));
                    bool _9490;
                    if (_9484)
                    {
                        _9490 = all(bool2(_10465.x < 1.0f.xx.x, _10465.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9490 = _9484;
                    }
                    _9417 = !_9490;
                }
                else
                {
                    _9417 = _9410;
                }
                if (_9417)
                {
                    _11248 = 0.0f;
                    break;
                }
                uint _9497_dummy_parameter;
                uint _9513_dummy_parameter;
                float4 _9438 = mul(float4((float2(_10464.x, 1.0f - _10464.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10464 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9497_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9440 = _9438.w;
                if (abs(_9440) < 9.9999999747524270787835121154785e-07f)
                {
                    _11248 = 0.0f;
                    break;
                }
                float _9451 = abs(cbFI_DeviceToViewDepth.y / ((_9438.z / _9440) - cbFI_DeviceToViewDepth.x));
                float _9454 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10465 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9513_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _11248 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9451 - _9454) / max(max(_9451, _9454), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9561 = all(bool2(_10465.x > 0.0f.xx.x, _10465.y > 0.0f.xx.y));
            bool _9567;
            if (_9561)
            {
                _9567 = all(bool2(_10465.x < 1.0f.xx.x, _10465.y < 1.0f.xx.y));
            }
            else
            {
                _9567 = _9561;
            }
            float _11249;
            if (_9567)
            {
                uint _9574_dummy_parameter;
                _11249 = length((_6195 + (r_motion_tp1.Load(int3(int2(floor(_10465 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9574_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _11249 = 1000000.0f;
            }
            float _11260;
            if ((_5408 & 1u) != 0u)
            {
                _11260 = _11248;
            }
            else
            {
                _11260 = 1.0f;
            }
            float _11261;
            if ((_5408 & 2u) != 0u)
            {
                _11261 = _11260 * (1.0f - smoothstep(2.0f, 8.0f, _11249));
            }
            else
            {
                _11261 = _11260;
            }
            float _11262;
            if ((_5408 & 4u) != 0u)
            {
                _11262 = _11261 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6916 - _6924) - length(_6900 - _6908))));
            }
            else
            {
                _11262 = _11261;
            }
            float _11497;
            if ((_5408 & 8u) != 0u)
            {
                _11497 = lerp(1.0f, _11262, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6900 - _6908)));
            }
            else
            {
                _11497 = _11262;
            }
            bool _5494 = (_5408 & 16u) != 0u;
            bool _5503;
            if (_5494)
            {
                _5503 = length(_10459 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5503 = _5494;
            }
            float _12628 = _5503 ? 1.0f : _11497;
            bool _5509 = _5414 && _7109;
            bool _5514;
            if (_5509)
            {
                bool _9599 = all(bool2(_10461.x > 0.0f.xx.x, _10461.y > 0.0f.xx.y));
                bool _9605;
                if (_9599)
                {
                    _9605 = all(bool2(_10461.x < 1.0f.xx.x, _10461.y < 1.0f.xx.y));
                }
                else
                {
                    _9605 = _9599;
                }
                _5514 = _9605;
            }
            else
            {
                _5514 = _5509;
            }
            bool _5519;
            if (_5514)
            {
                bool _9610 = all(bool2(_10463.x > 0.0f.xx.x, _10463.y > 0.0f.xx.y));
                bool _9616;
                if (_9610)
                {
                    _9616 = all(bool2(_10463.x < 1.0f.xx.x, _10463.y < 1.0f.xx.y));
                }
                else
                {
                    _9616 = _9610;
                }
                _5519 = _9616;
            }
            else
            {
                _5519 = _5514;
            }
            float4 _11504;
            if (_5519)
            {
                float _5525 = _11486.x + _11486.y;
                float _5534 = (_11486.z + _11486.w) * (1.0f - _12628);
                float _11500;
                if (_5525 > 9.9999997473787516355514526367188e-06f)
                {
                    _11500 = _11486.x / _5525;
                }
                else
                {
                    _11500 = _4365;
                }
                _11504 = float4(_11486.x + (_5534 * _11500), _11486.y + (_5534 * (1.0f - _11500)), _11486.zw * _12628);
            }
            else
            {
                _11504 = _11486;
            }
            _11503 = _11504;
        }
        else
        {
            _11503 = _11486;
        }
        float3 _12393;
        if (_11506)
        {
            float3 _9622 = r_current_interpolation_source.Load(int3(_3734, 0)).xyz;
            float3 _12394;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _7109)
            {
                uint _9629_dummy_parameter;
                float _11611;
                _11611 = r_depth_tm1.Load(int3(int2(floor(_10461 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9629_dummy_parameter))))), 0)).x;
                float _5646;
                for (int _11610 = 0; _11610 < 24; _11611 = _5646, _11610++)
                {
                    float _5618 = float(_11610 & 7) * 0.785398185253143310546875f;
                    int _5620 = _11610 >> 3;
                    int _12444;
                    if (_5620 == 0)
                    {
                        _12444 = 16;
                    }
                    else
                    {
                        _12444 = (_5620 == 1) ? 48 : 96;
                    }
                    uint _9649_dummy_parameter;
                    _5646 = min(_11611, r_depth_tm1.Load(int3(int2(floor(clamp(_10461 + ((cbFI_MvDepthLaneSizeRcp * float(_12444)) * float2(cos(_5618), sin(_5618))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9649_dummy_parameter))))), 0)).x);
                }
                float2 _11612;
                do
                {
                    float _9671 = 1.0f - _10461.y;
                    float4 _9682 = mul(float4((float2(_10461.x, _9671) * 2.0f) - 1.0f.xx, _11611, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9684 = _9682.w;
                    if (!(_9684 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11612 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9697 = ((_9682.xy / _9684.xx) + 1.0f.xx) * 0.5f;
                    _11612 = float2(_9697.x - _10461.x, _9671 - _9697.y);
                    break;
                } while(false);
                float2 _5657 = _10461 + _11612;
                bool _9715 = all(bool2(_5657.x > 0.0f.xx.x, _5657.y > 0.0f.xx.y));
                bool _9721;
                if (_9715)
                {
                    _9721 = all(bool2(_5657.x < 1.0f.xx.x, _5657.y < 1.0f.xx.y));
                }
                else
                {
                    _9721 = _9715;
                }
                float3 _12395;
                if (_9721)
                {
                    float _5663 = abs(cbFI_DeviceToViewDepth.y / (_11611 - cbFI_DeviceToViewDepth.x));
                    uint _9741_dummy_parameter;
                    int2 _9741 = int2(spvTextureSize(r_depth_m2, uint(0), _9741_dummy_parameter));
                    float _5667 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5657 * float2(_9741))), int2(0, 0), _9741 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12400;
                    if (abs(_5667 - _5663) <= (0.20000000298023223876953125f * max(_5667, _5663)))
                    {
                        uint _9775_dummy_parameter;
                        int2 _9775 = int2(spvTextureSize(r_colour_m2, uint(0), _9775_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9798;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9798);
                        }
                        _12400 = r_colour_m2.Load(int3(clamp(int2(floor(_5657 * float2(_9775))), int2(0, 0), _9775 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9808;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9808);
                        }
                        _12400 = _9622;
                    }
                    _12395 = _12400;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9818;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9818);
                    }
                    _12395 = _9622;
                }
                _12394 = _12395;
            }
            else
            {
                _12394 = _9622;
            }
            _12393 = _12394;
        }
        else
        {
            _12393 = (((_6900 * _11503.x) + (_6908 * _11503.y)) + (_6916 * _11503.z)) + (_6924 * _11503.w);
        }
        uint _5695 = cbFI_pad0 & 255u;
        bool _12285;
        float3 _12392;
        if (_5695 != 0u)
        {
            float3 _5700 = r_present_backbuffer.Load(int3(_3734, 0)).xyz;
            float3 _5704 = r_current_interpolation_source.Load(int3(_3734, 0)).xyz;
            float3 _5708 = abs(_5700 - _5704);
            float3 _11615;
            if (_5695 == 2u)
            {
                _11615 = (abs(_5704) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11615 = 0.000244140625f.xxx;
            }
            bool _5724 = any(bool3(_5708.x > _11615.x, _5708.y > _11615.y, _5708.z > _11615.z));
            bool3 _12629 = _5724.xxx;
            _12392 = float3(_12629.x ? _5700.x : _12393.x, _12629.y ? _5700.y : _12393.y, _12629.z ? _5700.z : _12393.z);
            _12285 = _5724;
        }
        else
        {
            _12392 = _12393;
            _12285 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9833;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9833);
        }
        float3 _12375;
        if (_5412 == 1u)
        {
            _12375 = lerp(_6900, _6908, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12376;
            if (_5412 == 2u)
            {
                _12376 = lerp(_6916, _6924, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12377;
                if (_5412 == 3u)
                {
                    _12377 = float(_12285).xxx;
                }
                else
                {
                    float3 _12378;
                    if (_5412 == 4u)
                    {
                        _12378 = float3(((_10459 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12379;
                        if (_5412 == 5u)
                        {
                            _12379 = float3(((_6195 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12380;
                            if (_5412 == 6u)
                            {
                                _12380 = float3(_11503.xy, _11503.z + _11503.w);
                            }
                            else
                            {
                                float3 _12381;
                                if (_5412 == 7u)
                                {
                                    _12381 = r_current_interpolation_source.Load(int3(_3734, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12382;
                                    if (_5412 == 8u)
                                    {
                                        _12382 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4140, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12383;
                                        if (_5416)
                                        {
                                            uint _9855_dummy_parameter;
                                            uint _9887_dummy_parameter;
                                            _12383 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4140 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9855_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4140 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9887_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12384;
                                            if (_5419)
                                            {
                                                _12384 = _6916;
                                            }
                                            else
                                            {
                                                float3 _12385;
                                                if (_5412 == 20u)
                                                {
                                                    _12385 = _6900;
                                                }
                                                else
                                                {
                                                    float3 _12386;
                                                    if (_5412 == 21u)
                                                    {
                                                        _12386 = _6908;
                                                    }
                                                    else
                                                    {
                                                        float3 _12387;
                                                        if (_5412 == 22u)
                                                        {
                                                            _12387 = _6924;
                                                        }
                                                        else
                                                        {
                                                            float3 _12388;
                                                            if (_5412 == 18u)
                                                            {
                                                                _12388 = _12031;
                                                            }
                                                            else
                                                            {
                                                                float3 _12389;
                                                                if (_5412 == 19u)
                                                                {
                                                                    _12389 = _11823;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12631 = (_5412 == 23u).xxx;
                                                                    _12389 = float3(_12631.x ? _11620.x : _12392.x, _12631.y ? _11620.y : _12392.y, _12631.z ? _11620.z : _12392.z);
                                                                }
                                                                _12388 = _12389;
                                                            }
                                                            _12387 = _12388;
                                                        }
                                                        _12386 = _12387;
                                                    }
                                                    _12385 = _12386;
                                                }
                                                _12384 = _12385;
                                            }
                                            _12383 = _12384;
                                        }
                                        _12382 = _12383;
                                    }
                                    _12381 = _12382;
                                }
                                _12380 = _12381;
                            }
                            _12379 = _12380;
                        }
                        _12378 = _12379;
                    }
                    _12377 = _12378;
                }
                _12376 = _12377;
            }
            _12375 = _12376;
        }
        float3 _12374;
        if ((_5412 >= 9u) && (_5412 <= 11u))
        {
            uint _5888 = 64u + uint((_10491.y * cbFI_MvDepthLaneSize.x) + _10491.x);
            uint _5892 = rw_nfru_diagnostics.Load<uint>(_5888 * 4 + 0) & 15u;
            float3 _12405;
            if (_5412 == 10u)
            {
                float3 _12373;
                if ((rw_nfru_diagnostics.Load<uint>(_5888 * 4 + 0) & 32u) != 0u)
                {
                    _12373 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12372;
                    if ((rw_nfru_diagnostics.Load<uint>(_5888 * 4 + 0) & 16u) != 0u)
                    {
                        _12372 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5913 = ((rw_nfru_diagnostics.Load<uint>(_5888 * 4 + 0) & 64u) != 0u).xxx;
                        _12372 = float3(_5913.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5913.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5913.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12373 = _12372;
                }
                _12405 = _12373;
            }
            else
            {
                float3 _12406;
                if (_5412 == 11u)
                {
                    uint _5926 = (rw_nfru_diagnostics.Load<uint>(_5888 * 4 + 0) >> 8u) & 15u;
                    uint _5929 = (rw_nfru_diagnostics.Load<uint>(_5888 * 4 + 0) >> 12u) & 15u;
                    float3 _12365;
                    if ((_5892 == 2u) || (_5892 == 3u))
                    {
                        _12365 = _3447[_5892];
                    }
                    else
                    {
                        bool _5941 = _5926 == 3u;
                        bool _5943 = _5929 == 3u;
                        float3 _12366;
                        if (_5941 && _5943)
                        {
                            _12366 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12367;
                            if (_5941)
                            {
                                _12367 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12368;
                                if (_5943)
                                {
                                    _12368 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12369;
                                    if ((_5926 == 4u) || (_5929 == 4u))
                                    {
                                        _12369 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12370;
                                        if ((_5926 == 1u) || (_5929 == 1u))
                                        {
                                            _12370 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12633 = (_5892 == 1u).xxx;
                                            _12370 = float3(_12633.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12633.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12633.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12369 = _12370;
                                    }
                                    _12368 = _12369;
                                }
                                _12367 = _12368;
                            }
                            _12366 = _12367;
                        }
                        _12365 = _12366;
                    }
                    _12406 = _12365;
                }
                else
                {
                    _12406 = _3447[min(_5892, 7u)];
                }
                _12405 = _12406;
            }
            _12374 = _12405;
        }
        else
        {
            _12374 = _12375;
        }
        float4 _12409;
        if ((_5412 >= 14u) && (_5412 <= 16u))
        {
            float2 _12407;
            if (_5412 == 14u)
            {
                uint _5999_dummy_parameter;
                uint _6005_dummy_parameter;
                _12407 = r_flow_tm1.Load(int3(clamp(int2(floor(_4140 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5999_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _6005_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12408;
                if (_5412 == 16u)
                {
                    uint _9938 = r_warped_flow_qdata_tm1.Load(int3(_4156, 0)).x & 2147483647u;
                    uint _9970 = uint(max((int((_9938 >> 16u) & 15u) - 6), 0));
                    _12408 = ((float2(float((1 - (2 * int((_9938 >> 15u) & 1u))) * int(((_9938 >> uint(7)) & 127u) << _9970)), float((1 - (2 * int((_9938 >> 14u) & 1u))) * int((_9938 & 127u) << _9970))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12408 = _6195 * float2(cbFI_DisplaySize);
                }
                _12407 = _12408;
            }
            uint2 _6038 = uint2(clamp(round(_12407 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _6040 = _6038.x;
            uint _6047 = _6038.y;
            _12409 = float4(float(_6040 & 255u), float((_6040 >> 8u) | ((_6047 & 15u) << 4u)), float(_6047 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12410;
            if (_5412 == 17u)
            {
                _12410 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4156, 0)).x != 0u), _4499, 0.0f, 1.0f);
            }
            else
            {
                _12410 = float4(_12374, 1.0f);
            }
            _12409 = _12410;
        }
        rw_output[_3734] = _12409.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _6091 = ((uint(_3734.y) * uint(cbFI_DisplaySize.x)) + uint(_3734.x)) * 6u;
            uint _10016 = spvPackHalf2x16(clamp(_6899.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_6091 * 4 + 0, (((_10016 & 32767u) >> 4u) | ((((_10016 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6899.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10051 = spvPackHalf2x16(clamp(_6907.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6091 + 1u) * 4 + 0, (((_10051 & 32767u) >> 4u) | ((((_10051 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6907.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10086 = spvPackHalf2x16(clamp(_6915.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6091 + 2u) * 4 + 0, (((_10086 & 32767u) >> 4u) | ((((_10086 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6915.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _10121 = spvPackHalf2x16(clamp(_6923.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6091 + 3u) * 4 + 0, (((_10121 & 32767u) >> 4u) | ((((_10121 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6923.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _10148 = r_current_interpolation_source.Load(int3(_3734, 0));
            uint _10162 = spvPackHalf2x16(clamp(_10148.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_6091 + 4u) * 4 + 0, (((_10162 & 32767u) >> 4u) | ((((_10162 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_10148.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12443;
            if (_12285 || (_5412 != 0u))
            {
                _12443 = 4294967295u;
            }
            else
            {
                uint _10197 = spvPackHalf2x16(clamp(_12409.xy, 0.0f.xx, 65000.0f.xx));
                _12443 = (((_10197 & 32767u) >> 4u) | ((((_10197 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12409.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_6091 + 5u) * 4 + 0, _12443);
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
