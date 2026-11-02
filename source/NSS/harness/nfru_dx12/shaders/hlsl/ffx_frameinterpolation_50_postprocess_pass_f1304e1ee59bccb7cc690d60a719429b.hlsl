static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1093[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _1102[5] = { 2, 4, 7, 11, 16 };
static const float3 _3384[8] = { 0.07999999821186065673828125f.xxx, float3(0.0f, 0.800000011920928955078125f, 0.0f), float3(0.0f, 1.0f, 1.0f), float3(0.0f, 0.300000011920928955078125f, 1.0f), float3(1.0f, 1.0f, 0.0f), float3(1.0f, 0.0f, 1.0f), float3(1.0f, 0.0f, 0.0f), 1.0f.xxx };

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
    int2 _3688 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_3688.x >= cbFI_DisplaySize.x, _3688.y >= cbFI_DisplaySize.y)))
        {
            break;
        }
        if (uint(cbFI_Reset) != 0u)
        {
            rw_output[_3688] = float4(r_present_backbuffer.Load(int3(_3688, 0)).xyz, 1.0f).xyz;
            rw_previous_interpolation_source[_3688] = float4(r_current_interpolation_source.Load(int3(_3688, 0)).xyz, 1.0f).xyz;
            break;
        }
        float2 _4096 = (float2(_3688) + 0.5f.xx) * cbFI_DisplaySizeRcp;
        int2 _4107 = int2(floor(_4096 * float2(cbFI_MvDepthLaneSize)));
        int2 _4112 = int2(floor(_4096 * float2(cbFI_FlowLaneSize)));
        float4 _6098 = (r_out_params_tensor.SampleLevel(s_LinearClamp, (_4096 * float2(cbFI_OfSize)) * cbFI_InputTensorSizeRcp, 0.0f) - cbFI_QuantParamsSNORM.w.xxxx) * cbFI_QuantParamsSNORM.z;
        float2 _6104 = r_warped_filled_flow_tm1.Load(int3(_4112, 0)).xy;
        float2 _6110 = r_warped_filled_motion_tp1.Load(int3(_4107, 0)).xy;
        bool _6132 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _10282;
        if (_6132)
        {
            float _6145 = ((2.0f * _4096.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _10282 = float2(atan(_6145) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4096.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_6145 * _6145))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _10282 = _4096;
        }
        bool _4133 = (cbFI_NfruT2Flags & 8u) != 0u;
        float2 _10303;
        bool _10324;
        int2 _10335;
        float3 _11764;
        if (_4133)
        {
            float _10284;
            float _10286;
            _10286 = 2.0f;
            _10284 = -1.0f;
            uint _3752[9];
            float _12206;
            float _12209;
            for (int _10283 = 0; _10283 < 9; _10286 = _12209, _10284 = _12206, _10283++)
            {
                _3752[_10283] = r_warped_motion_qdata_tp1.Load(int3(clamp(_4107 + int2((_10283 % 3) - 1, (_10283 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x;
                if (_3752[_10283] != 0u)
                {
                    float _12201;
                    if (_3752[_10283] == 0u)
                    {
                        _12201 = -1.0f;
                    }
                    else
                    {
                        _12201 = float((_3752[_10283] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _12209 = min(_10286, _12201);
                    _12206 = max(_10284, _12201);
                }
                else
                {
                    _12209 = _10286;
                    _12206 = _10284;
                }
            }
            float _4179 = float(_10284 >= 0.0f);
            float3 _10075 = 0.0f.xxx;
            _10075.y = _4179;
            float2 _10304;
            bool _10325;
            int2 _10336;
            float3 _11765;
            if ((_10284 - _10286) > 0.0199999995529651641845703125f)
            {
                float _10292;
                int2 _10293;
                float2 _10294;
                int2 _10296;
                float2 _10302;
                _10302 = _6110;
                _10296 = _4107;
                _10294 = _6110;
                _10293 = _4107;
                _10292 = -1.0f;
                float _12214;
                int2 _12218;
                float2 _12229;
                int2 _12240;
                float2 _12273;
                float _12320;
                int _10291 = 0;
                float _12182 = 1000000000.0f;
                for (; _10291 < 9; _12182 = _12320, _10302 = _12273, _10296 = _12240, _10294 = _12229, _10293 = _12218, _10292 = _12214, _10291++)
                {
                    if (_3752[_10291] == 0u)
                    {
                        _12320 = _12182;
                        _12273 = _10302;
                        _12240 = _10296;
                        _12229 = _10294;
                        _12218 = _10293;
                        _12214 = _10292;
                        continue;
                    }
                    int2 _4214 = clamp(_4107 + int2((_10291 % 3) - 1, (_10291 / 3) - 1), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1));
                    uint _6220 = _3752[_10291] & 2147483647u;
                    uint _6252 = uint(max((int((_6220 >> 16u) & 15u) - 6), 0));
                    float2 _4220 = (float2(float((1 - (2 * int((_6220 >> 15u) & 1u))) * int(((_6220 >> uint(7)) & 127u) << _6252)), float((1 - (2 * int((_6220 >> 14u) & 1u))) * int((_6220 & 127u) << _6252))) * 0.0624427758157253265380859375f) * cbFI_MvDepthLaneSizeRcp;
                    float _12168;
                    if (_3752[_10291] == 0u)
                    {
                        _12168 = -1.0f;
                    }
                    else
                    {
                        _12168 = float((_3752[_10291] >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    float _4225 = _12168 - 0.100000001490116119384765625f;
                    float2 _12169;
                    if (_6132)
                    {
                        float2 _6329 = clamp((((_10282 + (_4220 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6332 = tan(_6329.x);
                        _12169 = (float2(_6332 / cbFI_DeviceToViewDepth.z, (tan(_6329.y) * sqrt(1.0f + (_6332 * _6332))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12169 = _10282 + (_4220 * cbFI_Timestep);
                    }
                    float _4232 = cbFI_Timestep - 1.0f;
                    float2 _12170;
                    if (_6132)
                    {
                        float2 _6400 = clamp((((_10282 + (_4220 * _4232)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                        float _6403 = tan(_6400.x);
                        _12170 = (float2(_6403 / cbFI_DeviceToViewDepth.z, (tan(_6400.y) * sqrt(1.0f + (_6403 * _6403))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
                    }
                    else
                    {
                        _12170 = _10282 + (_4220 * _4232);
                    }
                    bool _6436 = all(bool2(_12169.x > 0.0f.xx.x, _12169.y > 0.0f.xx.y));
                    bool _6442;
                    if (_6436)
                    {
                        _6442 = all(bool2(_12169.x < 1.0f.xx.x, _12169.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6442 = _6436;
                    }
                    float _12173;
                    if (_6442)
                    {
                        uint _6449_dummy_parameter;
                        _12173 = max((_4225 - (log((r_depth_tm1.Load(int3(int2(floor(_12169 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6449_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12173 = 0.0f;
                    }
                    bool _6479 = all(bool2(_12170.x > 0.0f.xx.x, _12170.y > 0.0f.xx.y));
                    bool _6485;
                    if (_6479)
                    {
                        _6485 = all(bool2(_12170.x < 1.0f.xx.x, _12170.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6485 = _6479;
                    }
                    float _12174;
                    if (_6485)
                    {
                        uint _6492_dummy_parameter;
                        _12174 = _12173 + max((_4225 - (log((r_depth_tp1.Load(int3(int2(floor(_12170 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6492_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) - 0.0199999995529651641845703125f, 0.0f);
                    }
                    else
                    {
                        _12174 = _12173;
                    }
                    float _12215;
                    int2 _12219;
                    float2 _12230;
                    int2 _12241;
                    float2 _12274;
                    float _12321;
                    if (_12174 == 0.0f)
                    {
                        bool _4267 = _4225 > _10292;
                        bool2 _12329 = _4267.xx;
                        _12321 = _12182;
                        _12274 = float2(_12329.x ? _4220.x : _10302.x, _12329.y ? _4220.y : _10302.y);
                        _12241 = int2(_12329.x ? _4214.x : _10296.x, _12329.y ? _4214.y : _10296.y);
                        _12230 = _10294;
                        _12219 = _10293;
                        _12215 = _4267 ? _4225 : _10292;
                    }
                    else
                    {
                        bool _4276 = _12174 < _12182;
                        bool2 _12325 = _4276.xx;
                        _12321 = _4276 ? _12174 : _12182;
                        _12274 = _10302;
                        _12241 = _10296;
                        _12230 = float2(_12325.x ? _4220.x : _10294.x, _12325.y ? _4220.y : _10294.y);
                        _12219 = int2(_12325.x ? _4214.x : _10293.x, _12325.y ? _4214.y : _10293.y);
                        _12215 = _10292;
                    }
                    _12320 = _12321;
                    _12273 = _12274;
                    _12240 = _12241;
                    _12229 = _12230;
                    _12218 = _12219;
                    _12214 = _12215;
                }
                bool _4288 = _10292 < 0.0f;
                bool2 _12335 = _4288.xx;
                int2 _12338 = int2(_12335.x ? _10293.x : _10296.x, _12335.y ? _10293.y : _10296.y);
                _11765 = float3(1.0f, _4179, float(any(bool2(_12338.x != _4107.x, _12338.y != _4107.y))));
                _10336 = _12338;
                _10325 = _4288 ? false : true;
                _10304 = float2(_12335.x ? _10294.x : _10302.x, _12335.y ? _10294.y : _10302.y);
            }
            else
            {
                _11765 = _10075;
                _10336 = _4107;
                _10325 = false;
                _10304 = _6110;
            }
            _11764 = _11765;
            _10335 = _10336;
            _10324 = _10325;
            _10303 = _10304;
        }
        else
        {
            _11764 = 0.0f.xxx;
            _10335 = _4107;
            _10324 = false;
            _10303 = _6110;
        }
        float2 _10305;
        if (_6132)
        {
            float2 _6557 = clamp((((_10282 + (_10303 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6560 = tan(_6557.x);
            _10305 = (float2(_6560 / cbFI_DeviceToViewDepth.z, (tan(_6557.y) * sqrt(1.0f + (_6560 * _6560))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10305 = _10282 + (_10303 * cbFI_Timestep);
        }
        float _4311 = cbFI_Timestep - 1.0f;
        float2 _10307;
        if (_6132)
        {
            float2 _6628 = clamp((((_10282 + (_10303 * _4311)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6631 = tan(_6628.x);
            _10307 = (float2(_6631 / cbFI_DeviceToViewDepth.z, (tan(_6628.y) * sqrt(1.0f + (_6631 * _6631))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10307 = _10282 + (_10303 * _4311);
        }
        float _4316 = -cbFI_Timestep;
        float2 _10308;
        if (_6132)
        {
            float2 _6699 = clamp((((_10282 + (_6104 * _4316)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6702 = tan(_6699.x);
            _10308 = (float2(_6702 / cbFI_DeviceToViewDepth.z, (tan(_6699.y) * sqrt(1.0f + (_6702 * _6702))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10308 = _10282 + (_6104 * _4316);
        }
        float _4321 = 1.0f - cbFI_Timestep;
        float2 _10309;
        if (_6132)
        {
            float2 _6770 = clamp((((_10282 + (_6104 * _4321)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _6773 = tan(_6770.x);
            _10309 = (float2(_6773 / cbFI_DeviceToViewDepth.z, (tan(_6770.y) * sqrt(1.0f + (_6773 * _6773))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
        }
        else
        {
            _10309 = _10282 + (_6104 * _4321);
        }
        float4 _6808 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10305, 0.0f);
        float3 _6809 = _6808.xyz;
        float4 _6816 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10307, 0.0f);
        float3 _6817 = _6816.xyz;
        float4 _6824 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _10308, 0.0f);
        float3 _6825 = _6824.xyz;
        float4 _6832 = r_current_interpolation_source.SampleLevel(s_LinearClamp, _10309, 0.0f);
        float3 _6833 = _6832.xyz;
        float4 _6847 = exp(_6098 - max(max(max(_6098.x, _6098.y), _6098.z), _6098.w).xxxx);
        float4 _6854 = _6847 / (dot(_6847, 1.0f.xxxx) + 6.103515625e-05f).xxxx;
        bool _4340 = _4133 && (!_10324);
        bool _4349;
        if (_4340)
        {
            _4349 = (_6854.z + _6854.w) > 0.0199999995529651641845703125f;
        }
        else
        {
            _4349 = _4340;
        }
        bool _4360;
        if (_4349)
        {
            _4360 = length((_10308 - _10305) * float2(cbFI_DisplaySize)) > 1.5f;
        }
        else
        {
            _4360 = _4349;
        }
        bool _10348;
        if (_4360)
        {
            uint4 _6873 = r_warped_motion_qdata_tp1.Load(int3(_10335, 0));
            uint _6874 = _6873.x;
            bool _10351;
            if (_6874 != 0u)
            {
                float _10337;
                if (_6874 == 0u)
                {
                    _10337 = -1.0f;
                }
                else
                {
                    _10337 = float((_6874 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                }
                float _4370 = _10337 - 0.12000000476837158203125f;
                bool _6893 = all(bool2(_10308.x > 0.0f.xx.x, _10308.y > 0.0f.xx.y));
                bool _6899;
                if (_6893)
                {
                    _6899 = all(bool2(_10308.x < 1.0f.xx.x, _10308.y < 1.0f.xx.y));
                }
                else
                {
                    _6899 = _6893;
                }
                bool _4380;
                if (_6899)
                {
                    uint _6906_dummy_parameter;
                    _4380 = (log((r_depth_tm1.Load(int3(int2(floor(_10308 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _6906_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4370;
                }
                else
                {
                    _4380 = _6899;
                }
                bool _4394;
                if (!_4380)
                {
                    bool _6936 = all(bool2(_10309.x > 0.0f.xx.x, _10309.y > 0.0f.xx.y));
                    bool _6942;
                    if (_6936)
                    {
                        _6942 = all(bool2(_10309.x < 1.0f.xx.x, _10309.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _6942 = _6936;
                    }
                    bool _4392;
                    if (_6942)
                    {
                        uint _6949_dummy_parameter;
                        _4392 = (log((r_depth_tp1.Load(int3(int2(floor(_10309 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _6949_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f) < _4370;
                    }
                    else
                    {
                        _4392 = _6942;
                    }
                    _4394 = _4392;
                }
                else
                {
                    _4394 = _4380;
                }
                _10351 = _4394;
            }
            else
            {
                _10351 = false;
            }
            _10348 = _10351;
        }
        else
        {
            _10348 = false;
        }
        bool _4399 = _10324 || _10348;
        bool _4404;
        if (_4399)
        {
            bool _6979 = all(bool2(_10305.x > 0.0f.xx.x, _10305.y > 0.0f.xx.y));
            bool _6985;
            if (_6979)
            {
                _6985 = all(bool2(_10305.x < 1.0f.xx.x, _10305.y < 1.0f.xx.y));
            }
            else
            {
                _6985 = _6979;
            }
            _4404 = _6985;
        }
        else
        {
            _4404 = _4399;
        }
        bool _4409;
        if (_4404)
        {
            bool _6990 = all(bool2(_10307.x > 0.0f.xx.x, _10307.y > 0.0f.xx.y));
            bool _6996;
            if (_6990)
            {
                _6996 = all(bool2(_10307.x < 1.0f.xx.x, _10307.y < 1.0f.xx.y));
            }
            else
            {
                _6996 = _6990;
            }
            _4409 = _6996;
        }
        else
        {
            _4409 = _4404;
        }
        float4 _10445;
        if (_4409)
        {
            float _4412 = _6854.x;
            float _4414 = _6854.y;
            float _4415 = _4412 + _4414;
            float _4420 = _6854.z + _6854.w;
            float _10366;
            if (_4415 > 0.001000000047497451305389404296875f)
            {
                _10366 = _4412 / _4415;
            }
            else
            {
                _10366 = _4321;
            }
            _10445 = float4(_4412 + (_4420 * _10366), _4414 + (_4420 * (1.0f - _10366)), 0.0f, 0.0f);
        }
        else
        {
            _10445 = _6854;
        }
        bool _7024 = (cbFI_pad0 & 1024u) != 0u;
        bool _7000 = !_7024;
        bool _7001 = !_7000;
        bool _7018;
        if (_7001)
        {
            _7018 = (rw_nfru_diagnostics.Load<uint>((64u + uint((_10335.y * cbFI_MvDepthLaneSize.x) + _10335.x)) * 4 + 0) & 65536u) != 0u;
        }
        else
        {
            _7018 = _7000;
        }
        bool _7050;
        if (_7001)
        {
            _7050 = rw_nfru_diagnostics.Load<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_4112.y * cbFI_FlowLaneSize.x) + _4112.x)) * 4 + 0) != 0u;
        }
        else
        {
            _7050 = _7000;
        }
        float _4455 = float(_7050);
        bool _10458;
        float4 _10489;
        float3 _11568;
        if (_7024)
        {
            bool _4465;
            if (_7018)
            {
                _4465 = all(bool2(_10305.x > 0.0f.xx.x, _10305.y > 0.0f.xx.y));
            }
            else
            {
                _4465 = _7018;
            }
            bool _4471;
            if (_4465)
            {
                _4471 = all(bool2(_10305.x < 1.0f.xx.x, _10305.y < 1.0f.xx.y));
            }
            else
            {
                _4471 = _4465;
            }
            bool _4478;
            if (_7018)
            {
                _4478 = all(bool2(_10307.x > 0.0f.xx.x, _10307.y > 0.0f.xx.y));
            }
            else
            {
                _4478 = _7018;
            }
            bool _4484;
            if (_4478)
            {
                _4484 = all(bool2(_10307.x < 1.0f.xx.x, _10307.y < 1.0f.xx.y));
            }
            else
            {
                _4484 = _4478;
            }
            bool _4491;
            if (_7050)
            {
                _4491 = all(bool2(_10308.x > 0.0f.xx.x, _10308.y > 0.0f.xx.y));
            }
            else
            {
                _4491 = _7050;
            }
            bool _4497;
            if (_4491)
            {
                _4497 = all(bool2(_10308.x < 1.0f.xx.x, _10308.y < 1.0f.xx.y));
            }
            else
            {
                _4497 = _4491;
            }
            bool _4504;
            if (_7050)
            {
                _4504 = all(bool2(_10309.x > 0.0f.xx.x, _10309.y > 0.0f.xx.y));
            }
            else
            {
                _4504 = _7050;
            }
            bool _4510;
            if (_4504)
            {
                _4510 = all(bool2(_10309.x < 1.0f.xx.x, _10309.y < 1.0f.xx.y));
            }
            else
            {
                _4510 = _4504;
            }
            bool _4512 = !_7018;
            if (_4512)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7092;
                    rw_nfru_diagnostics.InterlockedAdd(220, 1u, _7092);
                }
            }
            bool _4517 = !_7050;
            if (_4517)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7102;
                    rw_nfru_diagnostics.InterlockedAdd(224, 1u, _7102);
                }
            }
            if (_7018 && _4517)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7112;
                    rw_nfru_diagnostics.InterlockedAdd(232, 1u, _7112);
                }
            }
            if (_4512 && _7050)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _7122;
                    rw_nfru_diagnostics.InterlockedAdd(236, 1u, _7122);
                }
            }
            float _4536 = float(_4471);
            float _4538 = float(_4484);
            bool _4541 = _4497 && _4510;
            float _10400;
            if (_4541)
            {
                _10400 = 1.0f;
            }
            else
            {
                _10400 = (_4497 || _4510) ? 0.5f : 0.0f;
            }
            bool _10405;
            if ((((cbFI_NfruT2Flags & 32u) != 0u) && (!_4471)) && (!_4484))
            {
                bool _4571;
                if (_4541)
                {
                    float _10403;
                    do
                    {
                        bool _7206 = all(bool2(_10308.x > 0.0f.xx.x, _10308.y > 0.0f.xx.y));
                        bool _7212;
                        if (_7206)
                        {
                            _7212 = all(bool2(_10308.x < 1.0f.xx.x, _10308.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7212 = _7206;
                        }
                        bool _7143 = !_7212;
                        bool _7150;
                        if (!_7143)
                        {
                            bool _7217 = all(bool2(_10309.x > 0.0f.xx.x, _10309.y > 0.0f.xx.y));
                            bool _7223;
                            if (_7217)
                            {
                                _7223 = all(bool2(_10309.x < 1.0f.xx.x, _10309.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7223 = _7217;
                            }
                            _7150 = !_7223;
                        }
                        else
                        {
                            _7150 = _7143;
                        }
                        if (_7150)
                        {
                            _10403 = 0.0f;
                            break;
                        }
                        uint _7230_dummy_parameter;
                        uint _7246_dummy_parameter;
                        float4 _7171 = mul(float4((float2(_10308.x, 1.0f - _10308.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10308 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7230_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7173 = _7171.w;
                        if (abs(_7173) < 9.9999999747524270787835121154785e-07f)
                        {
                            _10403 = 0.0f;
                            break;
                        }
                        float _7184 = abs(cbFI_DeviceToViewDepth.y / ((_7171.z / _7173) - cbFI_DeviceToViewDepth.x));
                        float _7187 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10309 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7246_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                        _10403 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_7184 - _7187) / max(max(_7184, _7187), 9.9999997473787516355514526367188e-05f));
                        break;
                    } while(false);
                    _4571 = _10403 >= 0.5f;
                }
                else
                {
                    _4571 = _4541;
                }
                bool _4579;
                if (_4571)
                {
                    _4579 = (cbFI_NfruT2Flags & 8192u) == 0u;
                }
                else
                {
                    _4579 = _4571;
                }
                bool _10406;
                if (_4579)
                {
                    uint _7296_dummy_parameter;
                    float2 _10404;
                    do
                    {
                        float _7322 = 1.0f - _10308.y;
                        float4 _7333 = mul(float4((float2(_10308.x, _7322) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10308 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7296_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                        float _7335 = _7333.w;
                        if (!(_7335 > 9.9999999747524270787835121154785e-07f))
                        {
                            _10404 = 1000000.0f.xx;
                            break;
                        }
                        float2 _7348 = ((_7333.xy / _7335.xx) + 1.0f.xx) * 0.5f;
                        _10404 = float2(_7348.x - _10308.x, _7322 - _7348.y);
                        break;
                    } while(false);
                    float2 _4592 = float2(cbFI_DisplaySize);
                    _10406 = length(((_10308 + _10404) - _10309) * _4592) <= ((0.100000001490116119384765625f * length(_10404 * _4592)) + 8.0f);
                }
                else
                {
                    _10406 = _4571;
                }
                _10405 = _10406;
            }
            else
            {
                _10405 = true;
            }
            bool _4606 = !_10405;
            bool _12339 = _4606 ? false : _4510;
            bool _12340 = _4606 ? false : _4497;
            bool _10459;
            float4 _10490;
            if (!(((_4471 && _4484) && _12340) && _12339))
            {
                float4 _4628 = _10445 * float4(_4536, _4538, float(_12340), float(_12339));
                float _4630 = dot(_4628, 1.0f.xxxx);
                bool _4633 = !(_4630 > 0.0f);
                float4 _10491;
                if (!_4633)
                {
                    _10491 = _4628 / _4630.xxxx;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _7370;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _7370);
                    }
                    _10491 = 0.0f.xxxx;
                }
                _10490 = _10491;
                _10459 = _4633;
            }
            else
            {
                _10490 = _10445;
                _10459 = false;
            }
            _11568 = float3(_4536, _4538, _10400);
            _10489 = _10490;
            _10458 = _10459;
        }
        else
        {
            _11568 = float3(float(_7018), _4455, 0.0f);
            _10489 = _10445;
            _10458 = false;
        }
        bool _4651 = !_10458;
        float4 _10553;
        if (((cbFI_NfruT2Flags & 65536u) != 0u) && _4651)
        {
            float _4658 = _10489.x + _10489.y;
            float4 _10554;
            if (_4658 > 0.001000000047497451305389404296875f)
            {
                _10554 = float4(_10489.x / _4658, _10489.y / _4658, 0.0f, 0.0f);
            }
            else
            {
                _10554 = float4(_4321, cbFI_Timestep, 0.0f, 0.0f);
            }
            _10553 = _10554;
        }
        else
        {
            _10553 = _10489;
        }
        float4 _10677;
        if ((((cbFI_NfruT2Flags & 49152u) != 0u) && _4651) && _7018)
        {
            float _10548;
            do
            {
                uint4 _7510 = r_warped_motion_qdata_tp1.Load(int3(_10335, 0));
                uint _7511 = _7510.x;
                if (_7511 != 0u)
                {
                    float _10547;
                    if (_7511 == 0u)
                    {
                        _10547 = -1.0f;
                    }
                    else
                    {
                        _10547 = float((_7511 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10548 = _10547;
                    break;
                }
                int _10530;
                uint _10531;
                _10531 = _7511;
                _10530 = -1;
                uint _10546;
                for (; _10530 <= 1; _10531 = _10546, _10530++)
                {
                    _10546 = _10531;
                    for (int _10544 = -1; _10544 <= 1; )
                    {
                        _10546 = max(_10546, r_warped_motion_qdata_tp1.Load(int3(clamp(_10335 + int2(_10544, _10530), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                        _10544++;
                        continue;
                    }
                }
                if (_10531 != 0u)
                {
                    float _10543;
                    if (_10531 == 0u)
                    {
                        _10543 = -1.0f;
                    }
                    else
                    {
                        _10543 = float((_10531 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10548 = _10543;
                    break;
                }
                uint _10533;
                _10533 = 4294967295u;
                uint _12310;
                for (int _10532 = 0; _10532 < 8; _10533 = _12310, _10532++)
                {
                    int _10536 = 0;
                    for (;;)
                    {
                        if (_10536 < 5)
                        {
                            int2 _7461 = _10335 + (_1093[_10532] * _1102[_10536].xx);
                            bool _7464 = any(bool2(_7461.x < int2(0, 0).x, _7461.y < int2(0, 0).y));
                            bool _7472;
                            if (!_7464)
                            {
                                _7472 = any(bool2(_7461.x >= cbFI_MvDepthLaneSize.x, _7461.y >= cbFI_MvDepthLaneSize.y));
                            }
                            else
                            {
                                _7472 = _7464;
                            }
                            if (_7472)
                            {
                                _12310 = _10533;
                                break;
                            }
                            uint4 _7550 = r_warped_motion_qdata_tp1.Load(int3(_7461, 0));
                            uint _7551 = _7550.x;
                            if (_7551 != 0u)
                            {
                                _12310 = min(_10533, _7551);
                                break;
                            }
                            _10536++;
                            continue;
                        }
                        else
                        {
                            _12310 = _10533;
                            break;
                        }
                    }
                }
                float _10535;
                if (_10533 == 4294967295u)
                {
                    _10535 = -1.0f;
                }
                else
                {
                    float _10534;
                    if (_10533 == 0u)
                    {
                        _10534 = -1.0f;
                    }
                    else
                    {
                        _10534 = float((_10533 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                    }
                    _10535 = _10534;
                }
                _10548 = _10535;
                break;
            } while(false);
            float _4694 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
            bool _4696 = _10548 < 0.0f;
            bool _4701;
            if (_4696)
            {
                bool _7570 = all(bool2(_10305.x > 0.0f.xx.x, _10305.y > 0.0f.xx.y));
                bool _7576;
                if (_7570)
                {
                    _7576 = all(bool2(_10305.x < 1.0f.xx.x, _10305.y < 1.0f.xx.y));
                }
                else
                {
                    _7576 = _7570;
                }
                _4701 = _7576;
            }
            else
            {
                _4701 = _4696;
            }
            bool _4706;
            if (_4701)
            {
                bool _7581 = all(bool2(_10307.x > 0.0f.xx.x, _10307.y > 0.0f.xx.y));
                bool _7587;
                if (_7581)
                {
                    _7587 = all(bool2(_10307.x < 1.0f.xx.x, _10307.y < 1.0f.xx.y));
                }
                else
                {
                    _7587 = _7581;
                }
                _4706 = _7587;
            }
            else
            {
                _4706 = _4701;
            }
            float4 _10610;
            if (_4706)
            {
                uint _7594_dummy_parameter;
                float _7618 = log((r_depth_tm1.Load(int3(int2(floor(_10305 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7594_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                uint _7626_dummy_parameter;
                float _7650 = log((r_depth_tp1.Load(int3(int2(floor(_10307 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7626_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                bool _4717 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4724;
                if (_4717)
                {
                    _4724 = _7650 > (_7618 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4724 = _4717;
                }
                float4 _10584;
                if (_4724)
                {
                    _10584 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                }
                else
                {
                    _10584 = 1.0f.xxxx;
                }
                bool _4731 = (cbFI_NfruT2Flags & 32768u) != 0u;
                bool _4738;
                if (_4731)
                {
                    _4738 = _7618 > (_7650 + 0.07999999821186065673828125f);
                }
                else
                {
                    _4738 = _4731;
                }
                float4 _10613;
                if (_4738)
                {
                    float4 _10145 = _10584;
                    _10145.x = 0.0f;
                    _10613 = _10145;
                }
                else
                {
                    _10613 = _10584;
                }
                _10610 = _10613;
            }
            else
            {
                bool _4746 = (cbFI_NfruT2Flags & 16384u) != 0u;
                bool _4752;
                if (_4746)
                {
                    _4752 = _10553.y > 0.00999999977648258209228515625f;
                }
                else
                {
                    _4752 = _4746;
                }
                bool _4757;
                if (_4752)
                {
                    bool _7656 = all(bool2(_10307.x > 0.0f.xx.x, _10307.y > 0.0f.xx.y));
                    bool _7662;
                    if (_7656)
                    {
                        _7662 = all(bool2(_10307.x < 1.0f.xx.x, _10307.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _7662 = _7656;
                    }
                    _4757 = _7662;
                }
                else
                {
                    _4757 = _4752;
                }
                float4 _10611;
                if (_4757)
                {
                    float _10571;
                    if (_10548 >= 0.0f)
                    {
                        _10571 = _10548 - _4694;
                    }
                    else
                    {
                        float _10567;
                        _10567 = 2.0f;
                        float _7719;
                        for (int _10566 = 0; _10566 < 24; _10567 = _7719, _10566++)
                        {
                            float _7683 = float(_10566 & 7) * 0.785398185253143310546875f;
                            int _7685 = _10566 >> 3;
                            int _10568;
                            if (_7685 == 0)
                            {
                                _10568 = 16;
                            }
                            else
                            {
                                _10568 = (_7685 == 1) ? 48 : 96;
                            }
                            uint _7751_dummy_parameter;
                            _7719 = min(_10567, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10307 + ((cbFI_MvDepthLaneSizeRcp * float(_10568)) * float2(cos(_7683), sin(_7683))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7751_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10571 = _10567;
                    }
                    uint _7783_dummy_parameter;
                    float4 _10612;
                    if (r_depth_tp1.Load(int3(int2(floor(_10307 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _7783_dummy_parameter))))), 0)).x > ((exp((_10571 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                    {
                        _10612 = float4(1.0f, 0.0f, 1.0f, 1.0f);
                    }
                    else
                    {
                        _10612 = 1.0f.xxxx;
                    }
                    _10611 = _10612;
                }
                else
                {
                    _10611 = 1.0f.xxxx;
                }
                _10610 = _10611;
            }
            bool _4783 = _10548 >= 0.0f;
            bool _4790;
            if (_4783)
            {
                _4790 = (cbFI_NfruT2Flags & 32768u) != 0u;
            }
            else
            {
                _4790 = _4783;
            }
            bool _4796;
            if (_4790)
            {
                _4796 = _10553.x > 0.00999999977648258209228515625f;
            }
            else
            {
                _4796 = _4790;
            }
            bool _4801;
            if (_4796)
            {
                bool _7807 = all(bool2(_10305.x > 0.0f.xx.x, _10305.y > 0.0f.xx.y));
                bool _7813;
                if (_7807)
                {
                    _7813 = all(bool2(_10305.x < 1.0f.xx.x, _10305.y < 1.0f.xx.y));
                }
                else
                {
                    _7813 = _7807;
                }
                _4801 = _7813;
            }
            else
            {
                _4801 = _4796;
            }
            float4 _10616;
            if (_4801)
            {
                float _10604;
                if (_4783)
                {
                    _10604 = _10548 - _4694;
                }
                else
                {
                    float _10600;
                    _10600 = 2.0f;
                    float _7870;
                    for (int _10599 = 0; _10599 < 24; _10600 = _7870, _10599++)
                    {
                        float _7834 = float(_10599 & 7) * 0.785398185253143310546875f;
                        int _7836 = _10599 >> 3;
                        int _10601;
                        if (_7836 == 0)
                        {
                            _10601 = 16;
                        }
                        else
                        {
                            _10601 = (_7836 == 1) ? 48 : 96;
                        }
                        uint _7886_dummy_parameter;
                        _7870 = min(_10600, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10305 + ((cbFI_MvDepthLaneSizeRcp * float(_10601)) * float2(cos(_7834), sin(_7834))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7886_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                    }
                    _10604 = _10600;
                }
                uint _7934_dummy_parameter;
                float4 _10617;
                if (r_depth_tm1.Load(int3(int2(floor(_10305 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _7934_dummy_parameter))))), 0)).x > ((exp((_10604 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f))
                {
                    float4 _10151 = _10610;
                    _10151.x = 0.0f;
                    _10617 = _10151;
                }
                else
                {
                    _10617 = _10610;
                }
                _10616 = _10617;
            }
            else
            {
                _10616 = _10610;
            }
            float4 _10678;
            if (any(bool4(_10616.x < 1.0f.xxxx.x, _10616.y < 1.0f.xxxx.y, _10616.z < 1.0f.xxxx.z, _10616.w < 1.0f.xxxx.w)))
            {
                float4 _4831 = _10553 * _10616;
                float _4833 = dot(_4831, 1.0f.xxxx);
                float4 _10679;
                if (_4833 > 0.0f)
                {
                    _10679 = _4831 / _4833.xxxx;
                }
                else
                {
                    bool _4844 = _10616.y == 0.0f;
                    bool _4850;
                    if (_4844)
                    {
                        _4850 = _10616.x > 0.0f;
                    }
                    else
                    {
                        _4850 = _4844;
                    }
                    bool _4855;
                    if (_4850)
                    {
                        bool _7958 = all(bool2(_10305.x > 0.0f.xx.x, _10305.y > 0.0f.xx.y));
                        bool _7964;
                        if (_7958)
                        {
                            _7964 = all(bool2(_10305.x < 1.0f.xx.x, _10305.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _7964 = _7958;
                        }
                        _4855 = _7964;
                    }
                    else
                    {
                        _4855 = _4850;
                    }
                    float4 _10680;
                    if (_4855)
                    {
                        _10680 = float4(1.0f, 0.0f, 0.0f, 0.0f);
                    }
                    else
                    {
                        bool _4860 = _10616.x == 0.0f;
                        bool _4866;
                        if (_4860)
                        {
                            _4866 = _10616.y > 0.0f;
                        }
                        else
                        {
                            _4866 = _4860;
                        }
                        bool _4871;
                        if (_4866)
                        {
                            bool _7969 = all(bool2(_10307.x > 0.0f.xx.x, _10307.y > 0.0f.xx.y));
                            bool _7975;
                            if (_7969)
                            {
                                _7975 = all(bool2(_10307.x < 1.0f.xx.x, _10307.y < 1.0f.xx.y));
                            }
                            else
                            {
                                _7975 = _7969;
                            }
                            _4871 = _7975;
                        }
                        else
                        {
                            _4871 = _4866;
                        }
                        bool4 _12341 = _4871.xxxx;
                        _10680 = float4(_12341.x ? float4(0.0f, 1.0f, 0.0f, 0.0f).x : _10553.x, _12341.y ? float4(0.0f, 1.0f, 0.0f, 0.0f).y : _10553.y, _12341.z ? float4(0.0f, 1.0f, 0.0f, 0.0f).z : _10553.z, _12341.w ? float4(0.0f, 1.0f, 0.0f, 0.0f).w : _10553.w);
                    }
                    _10679 = _10680;
                }
                _10678 = _10679;
            }
            else
            {
                _10678 = _10553;
            }
            _10677 = _10678;
        }
        else
        {
            _10677 = _10553;
        }
        float4 _11243;
        bool _11263;
        float3 _11377;
        if (((cbFI_pad0 & 32768u) != 0u) && _4651)
        {
            bool _4888 = _10677.x > 0.00999999977648258209228515625f;
            bool _4891 = _10677.y > 0.00999999977648258209228515625f;
            bool _4900 = (_10677.z + _10677.w) > 0.0199999995529651641845703125f;
            bool _4906;
            if (_4900)
            {
                bool _7980 = all(bool2(_10308.x > 0.0f.xx.x, _10308.y > 0.0f.xx.y));
                bool _7986;
                if (_7980)
                {
                    _7986 = all(bool2(_10308.x < 1.0f.xx.x, _10308.y < 1.0f.xx.y));
                }
                else
                {
                    _7986 = _7980;
                }
                _4906 = _7986;
            }
            else
            {
                _4906 = _4900;
            }
            bool _4911;
            if (_4906)
            {
                bool _7991 = all(bool2(_10309.x > 0.0f.xx.x, _10309.y > 0.0f.xx.y));
                bool _7997;
                if (_7991)
                {
                    _7997 = all(bool2(_10309.x < 1.0f.xx.x, _10309.y < 1.0f.xx.y));
                }
                else
                {
                    _7997 = _7991;
                }
                _4911 = _7997;
            }
            else
            {
                _4911 = _4906;
            }
            bool _4918;
            if (_4911)
            {
                float _10688;
                do
                {
                    bool _8080 = all(bool2(_10308.x > 0.0f.xx.x, _10308.y > 0.0f.xx.y));
                    bool _8086;
                    if (_8080)
                    {
                        _8086 = all(bool2(_10308.x < 1.0f.xx.x, _10308.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _8086 = _8080;
                    }
                    bool _8017 = !_8086;
                    bool _8024;
                    if (!_8017)
                    {
                        bool _8091 = all(bool2(_10309.x > 0.0f.xx.x, _10309.y > 0.0f.xx.y));
                        bool _8097;
                        if (_8091)
                        {
                            _8097 = all(bool2(_10309.x < 1.0f.xx.x, _10309.y < 1.0f.xx.y));
                        }
                        else
                        {
                            _8097 = _8091;
                        }
                        _8024 = !_8097;
                    }
                    else
                    {
                        _8024 = _8017;
                    }
                    if (_8024)
                    {
                        _10688 = 0.0f;
                        break;
                    }
                    uint _8104_dummy_parameter;
                    uint _8120_dummy_parameter;
                    float4 _8045 = mul(float4((float2(_10308.x, 1.0f - _10308.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10308 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8104_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                    float _8047 = _8045.w;
                    if (abs(_8047) < 9.9999999747524270787835121154785e-07f)
                    {
                        _10688 = 0.0f;
                        break;
                    }
                    float _8058 = abs(cbFI_DeviceToViewDepth.y / ((_8045.z / _8047) - cbFI_DeviceToViewDepth.x));
                    float _8061 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10309 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8120_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                    _10688 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_8058 - _8061) / max(max(_8058, _8061), 9.9999997473787516355514526367188e-05f));
                    break;
                } while(false);
                _4918 = _10688 < 0.5f;
            }
            else
            {
                _4918 = _4911;
            }
            float4 _10703;
            if (_4918)
            {
                uint _8170_dummy_parameter;
                uint _8201_dummy_parameter;
                float4 _10704;
                if (abs(cbFI_DeviceToViewDepth.y / (r_depth_tm1.Load(int3(int2(floor(_10308 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8170_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)) < abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10309 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8201_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x)))
                {
                    _10704 = float4(1.0f, 1.0f, 0.0f, 1.0f);
                }
                else
                {
                    _10704 = float4(1.0f, 1.0f, 1.0f, 0.0f);
                }
                _10703 = _10704;
            }
            else
            {
                _10703 = 1.0f.xxxx;
            }
            bool _4942;
            if (_7018)
            {
                bool _8230 = all(bool2(_10305.x > 0.0f.xx.x, _10305.y > 0.0f.xx.y));
                bool _8236;
                if (_8230)
                {
                    _8236 = all(bool2(_10305.x < 1.0f.xx.x, _10305.y < 1.0f.xx.y));
                }
                else
                {
                    _8236 = _8230;
                }
                _4942 = _8236;
            }
            else
            {
                _4942 = _7018;
            }
            bool _4948;
            if (_7018)
            {
                bool _8241 = all(bool2(_10307.x > 0.0f.xx.x, _10307.y > 0.0f.xx.y));
                bool _8247;
                if (_8241)
                {
                    _8247 = all(bool2(_10307.x < 1.0f.xx.x, _10307.y < 1.0f.xx.y));
                }
                else
                {
                    _8247 = _8241;
                }
                _4948 = _8247;
            }
            else
            {
                _4948 = _7018;
            }
            bool _4954;
            if (_7050)
            {
                bool _8252 = all(bool2(_10308.x > 0.0f.xx.x, _10308.y > 0.0f.xx.y));
                bool _8258;
                if (_8252)
                {
                    _8258 = all(bool2(_10308.x < 1.0f.xx.x, _10308.y < 1.0f.xx.y));
                }
                else
                {
                    _8258 = _8252;
                }
                _4954 = _8258;
            }
            else
            {
                _4954 = _7050;
            }
            bool _4960;
            if (_7050)
            {
                bool _8263 = all(bool2(_10309.x > 0.0f.xx.x, _10309.y > 0.0f.xx.y));
                bool _8269;
                if (_8263)
                {
                    _8269 = all(bool2(_10309.x < 1.0f.xx.x, _10309.y < 1.0f.xx.y));
                }
                else
                {
                    _8269 = _8263;
                }
                _4960 = _8269;
            }
            else
            {
                _4960 = _7050;
            }
            bool _4963 = _4954 != _4960;
            bool _4969;
            if (_4963)
            {
                _4969 = _4942 || _4948;
            }
            else
            {
                _4969 = _4963;
            }
            float4 _10801;
            if (_4969)
            {
                float4 _10178 = _10703;
                _10178.z = 0.0f;
                _10178.w = 0.0f;
                _10801 = _10178;
            }
            else
            {
                _10801 = _10703;
            }
            bool _4976 = _4942 && _4888;
            bool _4979 = _4948 && _4891;
            float4 _10906;
            float3 _11466;
            if (_4976 || _4979)
            {
                float _10796;
                do
                {
                    uint4 _8408 = r_warped_motion_qdata_tp1.Load(int3(_10335, 0));
                    uint _8409 = _8408.x;
                    if (_8409 != 0u)
                    {
                        float _10795;
                        if (_8409 == 0u)
                        {
                            _10795 = -1.0f;
                        }
                        else
                        {
                            _10795 = float((_8409 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10796 = _10795;
                        break;
                    }
                    int _10778;
                    uint _10779;
                    _10779 = _8409;
                    _10778 = -1;
                    uint _10794;
                    for (; _10778 <= 1; _10779 = _10794, _10778++)
                    {
                        _10794 = _10779;
                        for (int _10792 = -1; _10792 <= 1; )
                        {
                            _10794 = max(_10794, r_warped_motion_qdata_tp1.Load(int3(clamp(_10335 + int2(_10792, _10778), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10792++;
                            continue;
                        }
                    }
                    if (_10779 != 0u)
                    {
                        float _10791;
                        if (_10779 == 0u)
                        {
                            _10791 = -1.0f;
                        }
                        else
                        {
                            _10791 = float((_10779 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10796 = _10791;
                        break;
                    }
                    uint _10781;
                    _10781 = 4294967295u;
                    uint _12311;
                    for (int _10780 = 0; _10780 < 8; _10781 = _12311, _10780++)
                    {
                        int _10784 = 0;
                        for (;;)
                        {
                            if (_10784 < 5)
                            {
                                int2 _8359 = _10335 + (_1093[_10780] * _1102[_10784].xx);
                                bool _8362 = any(bool2(_8359.x < int2(0, 0).x, _8359.y < int2(0, 0).y));
                                bool _8370;
                                if (!_8362)
                                {
                                    _8370 = any(bool2(_8359.x >= cbFI_MvDepthLaneSize.x, _8359.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8370 = _8362;
                                }
                                if (_8370)
                                {
                                    _12311 = _10781;
                                    break;
                                }
                                uint4 _8448 = r_warped_motion_qdata_tp1.Load(int3(_8359, 0));
                                uint _8449 = _8448.x;
                                if (_8449 != 0u)
                                {
                                    _12311 = min(_10781, _8449);
                                    break;
                                }
                                _10784++;
                                continue;
                            }
                            else
                            {
                                _12311 = _10781;
                                break;
                            }
                        }
                    }
                    float _10783;
                    if (_10781 == 4294967295u)
                    {
                        _10783 = -1.0f;
                    }
                    else
                    {
                        float _10782;
                        if (_10781 == 0u)
                        {
                            _10782 = -1.0f;
                        }
                        else
                        {
                            _10782 = float((_10781 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10783 = _10782;
                    }
                    _10796 = _10783;
                    break;
                } while(false);
                bool _4987 = _10796 < 0.0f;
                float _10797;
                if (_4987)
                {
                    _10797 = 0.0f;
                }
                else
                {
                    _10797 = _10796 - (((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f);
                }
                uint _8470_dummy_parameter;
                uint _8502_dummy_parameter;
                float4 _10834;
                if ((_4987 && _4976) && _4979)
                {
                    uint _8534_dummy_parameter;
                    float _8558 = log((r_depth_tm1.Load(int3(int2(floor(_10305 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8534_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    uint _8566_dummy_parameter;
                    float _8590 = log((r_depth_tp1.Load(int3(int2(floor(_10307 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8566_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f;
                    float4 _10835;
                    if (_8558 > (_8590 + 0.07999999821186065673828125f))
                    {
                        float4 _10182 = _10801;
                        _10182.x = 0.0f;
                        _10835 = _10182;
                    }
                    else
                    {
                        float4 _10836;
                        if (_8590 > (_8558 + 0.07999999821186065673828125f))
                        {
                            float4 _10184 = _10801;
                            _10184.y = 0.0f;
                            _10836 = _10184;
                        }
                        else
                        {
                            _10836 = _10801;
                        }
                        _10835 = _10836;
                    }
                    _10834 = _10835;
                }
                else
                {
                    _10834 = _10801;
                }
                float _5039 = ((cbFI_NfruT2Flags & 64u) != 0u) ? 0.100000001490116119384765625f : 0.0f;
                bool _5041 = _10796 >= 0.0f;
                float _10817;
                if (_5041)
                {
                    _10817 = _10796 - _5039;
                }
                else
                {
                    float _10813;
                    if (_4976)
                    {
                        float _10812;
                        _10812 = 2.0f;
                        float _8648;
                        for (int _10811 = 0; _10811 < 24; _10812 = _8648, _10811++)
                        {
                            float _8612 = float(_10811 & 7) * 0.785398185253143310546875f;
                            int _8614 = _10811 >> 3;
                            int _10814;
                            if (_8614 == 0)
                            {
                                _10814 = 16;
                            }
                            else
                            {
                                _10814 = (_8614 == 1) ? 48 : 96;
                            }
                            uint _8664_dummy_parameter;
                            _8648 = min(_10812, log((r_depth_tm1.Load(int3(int2(floor(clamp(_10305 + ((cbFI_MvDepthLaneSizeRcp * float(_10814)) * float2(cos(_8612), sin(_8612))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8664_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10813 = _10812;
                    }
                    else
                    {
                        _10813 = 0.0f;
                    }
                    _10817 = _10813;
                }
                float _10824;
                if (_5041)
                {
                    _10824 = _10796 - _5039;
                }
                else
                {
                    float _10820;
                    if (_4979)
                    {
                        float _10819;
                        _10819 = 2.0f;
                        float _8762;
                        for (int _10818 = 0; _10818 < 24; _10819 = _8762, _10818++)
                        {
                            float _8726 = float(_10818 & 7) * 0.785398185253143310546875f;
                            int _8728 = _10818 >> 3;
                            int _10821;
                            if (_8728 == 0)
                            {
                                _10821 = 16;
                            }
                            else
                            {
                                _10821 = (_8728 == 1) ? 48 : 96;
                            }
                            uint _8794_dummy_parameter;
                            _8762 = min(_10819, log((r_depth_tp1.Load(int3(int2(floor(clamp(_10307 + ((cbFI_MvDepthLaneSizeRcp * float(_10821)) * float2(cos(_8726), sin(_8726))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8794_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                        }
                        _10820 = _10819;
                    }
                    else
                    {
                        _10820 = 0.0f;
                    }
                    _10824 = _10820;
                }
                float _10825;
                if (_4976)
                {
                    uint _8826_dummy_parameter;
                    _10825 = r_depth_tm1.Load(int3(int2(floor(_10305 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8826_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10825 = 0.0f;
                }
                float _10826;
                if (_4979)
                {
                    uint _8845_dummy_parameter;
                    _10826 = r_depth_tp1.Load(int3(int2(floor(_10307 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8845_dummy_parameter))))), 0)).x;
                }
                else
                {
                    _10826 = 0.0f;
                }
                bool _5096;
                if (_4976)
                {
                    _5096 = _10825 > ((exp((_10817 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5096 = _4976;
                }
                float4 _10842;
                if (_5096)
                {
                    float4 _10186 = _10834;
                    _10186.x = 0.0f;
                    _10842 = _10186;
                }
                else
                {
                    _10842 = _10834;
                }
                bool _5108;
                if (_4979)
                {
                    _5108 = _10826 > ((exp((_10824 + 0.07999999821186065673828125f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                }
                else
                {
                    _5108 = _4979;
                }
                float4 _10844;
                if (_5108)
                {
                    float4 _10188 = _10842;
                    _10188.y = 0.0f;
                    _10844 = _10188;
                }
                else
                {
                    _10844 = _10842;
                }
                float4 _10907;
                if (((cbFI_NfruT2Flags & 128u) != 0u) && _5041)
                {
                    bool _5128;
                    if (_4976)
                    {
                        _5128 = _10825 < ((exp((_10817 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5128 = _4976;
                    }
                    float4 _10846;
                    if (_5128)
                    {
                        float4 _10190 = _10844;
                        _10190.x = 0.0f;
                        _10846 = _10190;
                    }
                    else
                    {
                        _10846 = _10844;
                    }
                    bool _5140;
                    if (_4979)
                    {
                        _5140 = _10826 < ((exp((_10824 - 0.039999999105930328369140625f) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f);
                    }
                    else
                    {
                        _5140 = _4979;
                    }
                    float4 _10908;
                    if (_5140)
                    {
                        float4 _10192 = _10846;
                        _10192.y = 0.0f;
                        _10908 = _10192;
                    }
                    else
                    {
                        _10908 = _10846;
                    }
                    _10907 = _10908;
                }
                else
                {
                    _10907 = _10844;
                }
                _11466 = float3(_10797, log((r_depth_tm1.Load(int3(int2(floor(_10305 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _8470_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tp1.Load(int3(int2(floor(_10307 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _8502_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
                _10906 = _10907;
            }
            else
            {
                _11466 = float3(0.0f, 0.0f, 0.5f);
                _10906 = _10801;
            }
            bool _5151 = ((cbFI_NfruT2Flags & 16u) != 0u) && _4900;
            bool _5157;
            if (_5151)
            {
                _5157 = _4954 || _4960;
            }
            else
            {
                _5157 = _5151;
            }
            float4 _10929;
            if (_5157)
            {
                float _10901;
                do
                {
                    uint4 _9024 = r_warped_motion_qdata_tp1.Load(int3(_10335, 0));
                    uint _9025 = _9024.x;
                    if (_9025 != 0u)
                    {
                        float _10900;
                        if (_9025 == 0u)
                        {
                            _10900 = -1.0f;
                        }
                        else
                        {
                            _10900 = float((_9025 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10901 = _10900;
                        break;
                    }
                    int _10883;
                    uint _10884;
                    _10884 = _9025;
                    _10883 = -1;
                    uint _10899;
                    for (; _10883 <= 1; _10884 = _10899, _10883++)
                    {
                        _10899 = _10884;
                        for (int _10897 = -1; _10897 <= 1; )
                        {
                            _10899 = max(_10899, r_warped_motion_qdata_tp1.Load(int3(clamp(_10335 + int2(_10897, _10883), int2(0, 0), cbFI_MvDepthLaneSize - int2(1, 1)), 0)).x);
                            _10897++;
                            continue;
                        }
                    }
                    if (_10884 != 0u)
                    {
                        float _10896;
                        if (_10884 == 0u)
                        {
                            _10896 = -1.0f;
                        }
                        else
                        {
                            _10896 = float((_10884 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10901 = _10896;
                        break;
                    }
                    uint _10886;
                    _10886 = 4294967295u;
                    uint _12312;
                    for (int _10885 = 0; _10885 < 8; _10886 = _12312, _10885++)
                    {
                        int _10889 = 0;
                        for (;;)
                        {
                            if (_10889 < 5)
                            {
                                int2 _8975 = _10335 + (_1093[_10885] * _1102[_10889].xx);
                                bool _8978 = any(bool2(_8975.x < int2(0, 0).x, _8975.y < int2(0, 0).y));
                                bool _8986;
                                if (!_8978)
                                {
                                    _8986 = any(bool2(_8975.x >= cbFI_MvDepthLaneSize.x, _8975.y >= cbFI_MvDepthLaneSize.y));
                                }
                                else
                                {
                                    _8986 = _8978;
                                }
                                if (_8986)
                                {
                                    _12312 = _10886;
                                    break;
                                }
                                uint4 _9064 = r_warped_motion_qdata_tp1.Load(int3(_8975, 0));
                                uint _9065 = _9064.x;
                                if (_9065 != 0u)
                                {
                                    _12312 = min(_10886, _9065);
                                    break;
                                }
                                _10889++;
                                continue;
                            }
                            else
                            {
                                _12312 = _10886;
                                break;
                            }
                        }
                    }
                    float _10888;
                    if (_10886 == 4294967295u)
                    {
                        _10888 = -1.0f;
                    }
                    else
                    {
                        float _10887;
                        if (_10886 == 0u)
                        {
                            _10887 = -1.0f;
                        }
                        else
                        {
                            _10887 = float((_10886 >> 20u) & 2047u) * 0.0005373717867769300937652587890625f;
                        }
                        _10888 = _10887;
                    }
                    _10901 = _10888;
                    break;
                } while(false);
                float4 _10930;
                if (_10901 >= 0.0f)
                {
                    float _9086 = (exp((_10901 + (-0.020000003278255462646484375f)) * 7.0909099578857421875f) - 1.0f) * 0.000833333353511989116668701171875f;
                    bool _5176;
                    if (_4954)
                    {
                        uint _9093_dummy_parameter;
                        _5176 = r_depth_tm1.Load(int3(int2(floor(_10308 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9093_dummy_parameter))))), 0)).x > _9086;
                    }
                    else
                    {
                        _5176 = _4954;
                    }
                    float4 _10919;
                    if (_5176)
                    {
                        float4 _10194 = _10906;
                        _10194.z = 0.0f;
                        _10919 = _10194;
                    }
                    else
                    {
                        _10919 = _10906;
                    }
                    bool _5188;
                    if (_4960)
                    {
                        uint _9112_dummy_parameter;
                        _5188 = r_depth_tp1.Load(int3(int2(floor(_10309 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9112_dummy_parameter))))), 0)).x > _9086;
                    }
                    else
                    {
                        _5188 = _4960;
                    }
                    float4 _10931;
                    if (_5188)
                    {
                        float4 _10196 = _10919;
                        _10196.w = 0.0f;
                        _10931 = _10196;
                    }
                    else
                    {
                        _10931 = _10919;
                    }
                    _10930 = _10931;
                }
                else
                {
                    _10930 = _10906;
                }
                _10929 = _10930;
            }
            else
            {
                _10929 = _10906;
            }
            bool _5196 = _4942 != _4948;
            bool _5203;
            if (_5196)
            {
                _5203 = _4942 ? _4888 : _4891;
            }
            else
            {
                _5203 = _5196;
            }
            bool _5210;
            if (_5203)
            {
                _5210 = (cbFI_NfruT2Flags & 8192u) == 0u;
            }
            else
            {
                _5210 = _5203;
            }
            float4 _11014;
            if (_5210)
            {
                bool2 _5215 = _4942.xx;
                float2 _5216 = float2(_5215.x ? _10305.x : _10307.x, _5215.y ? _10305.y : _10307.y);
                float _10921;
                if (_4942)
                {
                    uint _9131_dummy_parameter;
                    _10921 = r_depth_tm1.Load(int3(int2(floor(_5216 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9131_dummy_parameter))))), 0)).x;
                }
                else
                {
                    uint _9147_dummy_parameter;
                    _10921 = r_depth_tp1.Load(int3(int2(floor(_5216 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9147_dummy_parameter))))), 0)).x;
                }
                float4x4 _10922;
                if (_4942)
                {
                    _10922 = cbFI_MotionTM1ToTP1;
                }
                else
                {
                    _10922 = cbFI_MotionTP1ToTM1;
                }
                float2 _10923;
                do
                {
                    float _9174 = _5216.x;
                    float _9177 = 1.0f - _5216.y;
                    float4 _9188 = mul(float4((float2(_9174, _9177) * 2.0f) - 1.0f.xx, _10921, 1.0f), _10922);
                    float _9190 = _9188.w;
                    if (!(_9190 > 9.9999999747524270787835121154785e-07f))
                    {
                        _10923 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9203 = ((_9188.xy / _9190.xx) + 1.0f.xx) * 0.5f;
                    _10923 = float2(_9203.x - _9174, _9177 - _9203.y);
                    break;
                } while(false);
                float2 _5246 = float2(cbFI_DisplaySize);
                float4 _11015;
                if (!(length(((_5216 + _10923) - float2(_5215.x ? _10307.x : _10305.x, _5215.y ? _10307.y : _10305.y)) * _5246) <= ((0.100000001490116119384765625f * length(_10923 * _5246)) + 8.0f)))
                {
                    float4 _11016;
                    if (_4942)
                    {
                        float4 _10206 = _10929;
                        _10206.x = 0.0f;
                        _11016 = _10206;
                    }
                    else
                    {
                        float4 _10208 = _10929;
                        _10208.y = 0.0f;
                        _11016 = _10208;
                    }
                    _11015 = _11016;
                }
                else
                {
                    _11015 = _10929;
                }
                _11014 = _11015;
            }
            else
            {
                _11014 = _10929;
            }
            float4 _5271 = _10677 * _11014;
            float _5273 = dot(_5271, 1.0f.xxxx);
            float4 _11244;
            bool _11264;
            if (_5273 > 0.0f)
            {
                _11264 = _10458;
                _11244 = _5271 / _5273.xxxx;
            }
            else
            {
                bool _5284 = any(bool4(_11014.x < 1.0f.xxxx.x, _11014.y < 1.0f.xxxx.y, _11014.z < 1.0f.xxxx.z, _11014.w < 1.0f.xxxx.w));
                if (_5284)
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9225;
                        rw_nfru_diagnostics.InterlockedAdd(228, 1u, _9225);
                    }
                }
                bool4 _12344 = _5284.xxxx;
                _11264 = _5284 ? true : _10458;
                _11244 = float4(_12344.x ? 0.0f.xxxx.x : _10677.x, _12344.y ? 0.0f.xxxx.y : _10677.y, _12344.z ? 0.0f.xxxx.z : _10677.z, _12344.w ? 0.0f.xxxx.w : _10677.w);
            }
            _11377 = _11466;
            _11263 = _11264;
            _11243 = _11244;
        }
        else
        {
            _11377 = float3(0.0f, 0.0f, 0.5f);
            _11263 = _10458;
            _11243 = _10677;
        }
        uint _5293 = (cbFI_pad0 >> 24u) & 31u;
        uint _5297 = (cbFI_pad0 >> 16u) & 255u;
        bool _5299 = _5293 != 0u;
        bool _5301 = _5297 == 12u;
        bool _5304 = _5297 == 13u;
        float4 _11260;
        if ((_5299 || _5301) || _5304)
        {
            float _11017;
            do
            {
                bool _9309 = all(bool2(_10308.x > 0.0f.xx.x, _10308.y > 0.0f.xx.y));
                bool _9315;
                if (_9309)
                {
                    _9315 = all(bool2(_10308.x < 1.0f.xx.x, _10308.y < 1.0f.xx.y));
                }
                else
                {
                    _9315 = _9309;
                }
                bool _9246 = !_9315;
                bool _9253;
                if (!_9246)
                {
                    bool _9320 = all(bool2(_10309.x > 0.0f.xx.x, _10309.y > 0.0f.xx.y));
                    bool _9326;
                    if (_9320)
                    {
                        _9326 = all(bool2(_10309.x < 1.0f.xx.x, _10309.y < 1.0f.xx.y));
                    }
                    else
                    {
                        _9326 = _9320;
                    }
                    _9253 = !_9326;
                }
                else
                {
                    _9253 = _9246;
                }
                if (_9253)
                {
                    _11017 = 0.0f;
                    break;
                }
                uint _9333_dummy_parameter;
                uint _9349_dummy_parameter;
                float4 _9274 = mul(float4((float2(_10308.x, 1.0f - _10308.y) * 2.0f) - 1.0f.xx, r_depth_tm1.Load(int3(int2(floor(_10308 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9333_dummy_parameter))))), 0)).x, 1.0f), cbFI_MotionTM1ToTP1);
                float _9276 = _9274.w;
                if (abs(_9276) < 9.9999999747524270787835121154785e-07f)
                {
                    _11017 = 0.0f;
                    break;
                }
                float _9287 = abs(cbFI_DeviceToViewDepth.y / ((_9274.z / _9276) - cbFI_DeviceToViewDepth.x));
                float _9290 = abs(cbFI_DeviceToViewDepth.y / (r_depth_tp1.Load(int3(int2(floor(_10309 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9349_dummy_parameter))))), 0)).x - cbFI_DeviceToViewDepth.x));
                _11017 = 1.0f - smoothstep(0.0199999995529651641845703125f, 0.100000001490116119384765625f, abs(_9287 - _9290) / max(max(_9287, _9290), 9.9999997473787516355514526367188e-05f));
                break;
            } while(false);
            bool _9397 = all(bool2(_10309.x > 0.0f.xx.x, _10309.y > 0.0f.xx.y));
            bool _9403;
            if (_9397)
            {
                _9403 = all(bool2(_10309.x < 1.0f.xx.x, _10309.y < 1.0f.xx.y));
            }
            else
            {
                _9403 = _9397;
            }
            float _11018;
            if (_9403)
            {
                uint _9410_dummy_parameter;
                _11018 = length((_6104 + (r_motion_tp1.Load(int3(int2(floor(_10309 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _9410_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale)) * float2(cbFI_DisplaySize));
            }
            else
            {
                _11018 = 1000000.0f;
            }
            float _11029;
            if ((_5293 & 1u) != 0u)
            {
                _11029 = _11017;
            }
            else
            {
                _11029 = 1.0f;
            }
            float _11030;
            if ((_5293 & 2u) != 0u)
            {
                _11030 = _11029 * (1.0f - smoothstep(2.0f, 8.0f, _11018));
            }
            else
            {
                _11030 = _11029;
            }
            float _11031;
            if ((_5293 & 4u) != 0u)
            {
                _11031 = _11030 * (1.0f - smoothstep(0.0199999995529651641845703125f, 0.119999997317790985107421875f, max(0.0f, length(_6825 - _6833) - length(_6809 - _6817))));
            }
            else
            {
                _11031 = _11030;
            }
            float _11254;
            if ((_5293 & 8u) != 0u)
            {
                _11254 = lerp(1.0f, _11031, 1.0f - smoothstep(0.02999999932944774627685546875f, 0.1500000059604644775390625f, length(_6809 - _6817)));
            }
            else
            {
                _11254 = _11031;
            }
            bool _5379 = (_5293 & 16u) != 0u;
            bool _5388;
            if (_5379)
            {
                _5388 = length(_10303 * float2(cbFI_DisplaySize)) < 0.25f;
            }
            else
            {
                _5388 = _5379;
            }
            float _12346 = _5388 ? 1.0f : _11254;
            bool _5394 = _5299 && _7018;
            bool _5399;
            if (_5394)
            {
                bool _9435 = all(bool2(_10305.x > 0.0f.xx.x, _10305.y > 0.0f.xx.y));
                bool _9441;
                if (_9435)
                {
                    _9441 = all(bool2(_10305.x < 1.0f.xx.x, _10305.y < 1.0f.xx.y));
                }
                else
                {
                    _9441 = _9435;
                }
                _5399 = _9441;
            }
            else
            {
                _5399 = _5394;
            }
            bool _5404;
            if (_5399)
            {
                bool _9446 = all(bool2(_10307.x > 0.0f.xx.x, _10307.y > 0.0f.xx.y));
                bool _9452;
                if (_9446)
                {
                    _9452 = all(bool2(_10307.x < 1.0f.xx.x, _10307.y < 1.0f.xx.y));
                }
                else
                {
                    _9452 = _9446;
                }
                _5404 = _9452;
            }
            else
            {
                _5404 = _5399;
            }
            float4 _11261;
            if (_5404)
            {
                float _5410 = _11243.x + _11243.y;
                float _5419 = (_11243.z + _11243.w) * (1.0f - _12346);
                float _11257;
                if (_5410 > 9.9999997473787516355514526367188e-06f)
                {
                    _11257 = _11243.x / _5410;
                }
                else
                {
                    _11257 = _4321;
                }
                _11261 = float4(_11243.x + (_5419 * _11257), _11243.y + (_5419 * (1.0f - _11257)), _11243.zw * _12346);
            }
            else
            {
                _11261 = _11243;
            }
            _11260 = _11261;
        }
        else
        {
            _11260 = _11243;
        }
        float3 _12114;
        if (_11263)
        {
            float3 _9458 = r_current_interpolation_source.Load(int3(_3688, 0)).xyz;
            float3 _12115;
            if (((cbFI_NfruT2Flags & 1u) != 0u) && _7018)
            {
                uint _9465_dummy_parameter;
                float _11368;
                _11368 = r_depth_tm1.Load(int3(int2(floor(_10305 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9465_dummy_parameter))))), 0)).x;
                float _5531;
                for (int _11367 = 0; _11367 < 24; _11368 = _5531, _11367++)
                {
                    float _5503 = float(_11367 & 7) * 0.785398185253143310546875f;
                    int _5505 = _11367 >> 3;
                    int _12165;
                    if (_5505 == 0)
                    {
                        _12165 = 16;
                    }
                    else
                    {
                        _12165 = (_5505 == 1) ? 48 : 96;
                    }
                    uint _9485_dummy_parameter;
                    _5531 = min(_11368, r_depth_tm1.Load(int3(int2(floor(clamp(_10305 + ((cbFI_MvDepthLaneSizeRcp * float(_12165)) * float2(cos(_5503), sin(_5503))), 0.0f.xx, 1.0f.xx) * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9485_dummy_parameter))))), 0)).x);
                }
                float2 _11369;
                do
                {
                    float _9507 = 1.0f - _10305.y;
                    float4 _9518 = mul(float4((float2(_10305.x, _9507) * 2.0f) - 1.0f.xx, _11368, 1.0f), cbFI_MotionTM1ToTM2);
                    float _9520 = _9518.w;
                    if (!(_9520 > 9.9999999747524270787835121154785e-07f))
                    {
                        _11369 = 1000000.0f.xx;
                        break;
                    }
                    float2 _9533 = ((_9518.xy / _9520.xx) + 1.0f.xx) * 0.5f;
                    _11369 = float2(_9533.x - _10305.x, _9507 - _9533.y);
                    break;
                } while(false);
                float2 _5542 = _10305 + _11369;
                bool _9551 = all(bool2(_5542.x > 0.0f.xx.x, _5542.y > 0.0f.xx.y));
                bool _9557;
                if (_9551)
                {
                    _9557 = all(bool2(_5542.x < 1.0f.xx.x, _5542.y < 1.0f.xx.y));
                }
                else
                {
                    _9557 = _9551;
                }
                float3 _12116;
                if (_9557)
                {
                    float _5548 = abs(cbFI_DeviceToViewDepth.y / (_11368 - cbFI_DeviceToViewDepth.x));
                    uint _9577_dummy_parameter;
                    int2 _9577 = int2(spvTextureSize(r_depth_m2, uint(0), _9577_dummy_parameter));
                    float _5552 = abs(cbFI_DeviceToViewDepth.y / (r_depth_m2.Load(int3(clamp(int2(floor(_5542 * float2(_9577))), int2(0, 0), _9577 - int2(1, 1)), 0)).x - cbFI_DeviceToViewDepth.x));
                    float3 _12121;
                    if (abs(_5552 - _5548) <= (0.20000000298023223876953125f * max(_5552, _5548)))
                    {
                        uint _9611_dummy_parameter;
                        int2 _9611 = int2(spvTextureSize(r_colour_m2, uint(0), _9611_dummy_parameter));
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9634;
                            rw_nfru_diagnostics.InterlockedAdd(76, 1u, _9634);
                        }
                        _12121 = r_colour_m2.Load(int3(clamp(int2(floor(_5542 * float2(_9611))), int2(0, 0), _9611 - int2(1, 1)), 0)).xyz;
                    }
                    else
                    {
                        if ((cbFI_pad0 & 512u) != 0u)
                        {
                            uint _9644;
                            rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9644);
                        }
                        _12121 = _9458;
                    }
                    _12116 = _12121;
                }
                else
                {
                    if ((cbFI_pad0 & 512u) != 0u)
                    {
                        uint _9654;
                        rw_nfru_diagnostics.InterlockedAdd(84, 1u, _9654);
                    }
                    _12116 = _9458;
                }
                _12115 = _12116;
            }
            else
            {
                _12115 = _9458;
            }
            _12114 = _12115;
        }
        else
        {
            _12114 = (((_6809 * _11260.x) + (_6817 * _11260.y)) + (_6825 * _11260.z)) + (_6833 * _11260.w);
        }
        uint _5580 = cbFI_pad0 & 255u;
        bool _12006;
        float3 _12113;
        if (_5580 != 0u)
        {
            float3 _5585 = r_present_backbuffer.Load(int3(_3688, 0)).xyz;
            float3 _5589 = r_current_interpolation_source.Load(int3(_3688, 0)).xyz;
            float3 _5593 = abs(_5585 - _5589);
            float3 _11372;
            if (_5580 == 2u)
            {
                _11372 = (abs(_5589) * float3(0.015625f, 0.015625f, 0.03125f)) + 0.0039215688593685626983642578125f.xxx;
            }
            else
            {
                _11372 = 0.000244140625f.xxx;
            }
            bool _5609 = any(bool3(_5593.x > _11372.x, _5593.y > _11372.y, _5593.z > _11372.z));
            bool3 _12347 = _5609.xxx;
            _12113 = float3(_12347.x ? _5585.x : _12114.x, _12347.y ? _5585.y : _12114.y, _12347.z ? _5585.z : _12114.z);
            _12006 = _5609;
        }
        else
        {
            _12113 = _12114;
            _12006 = false;
        }
        if ((cbFI_pad0 & 512u) != 0u)
        {
            uint _9669;
            rw_nfru_diagnostics.InterlockedAdd(80, 1u, _9669);
        }
        float3 _12096;
        if (_5297 == 1u)
        {
            _12096 = lerp(_6809, _6817, cbFI_Timestep.xxx);
        }
        else
        {
            float3 _12097;
            if (_5297 == 2u)
            {
                _12097 = lerp(_6825, _6833, cbFI_Timestep.xxx);
            }
            else
            {
                float3 _12098;
                if (_5297 == 3u)
                {
                    _12098 = float(_12006).xxx;
                }
                else
                {
                    float3 _12099;
                    if (_5297 == 4u)
                    {
                        _12099 = float3(((_10303 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                    }
                    else
                    {
                        float3 _12100;
                        if (_5297 == 5u)
                        {
                            _12100 = float3(((_6104 * float2(cbFI_DisplaySize)) * 0.015625f.xx) + 0.5f.xx, 0.0f);
                        }
                        else
                        {
                            float3 _12101;
                            if (_5297 == 6u)
                            {
                                _12101 = float3(_11260.xy, _11260.z + _11260.w);
                            }
                            else
                            {
                                float3 _12102;
                                if (_5297 == 7u)
                                {
                                    _12102 = r_current_interpolation_source.Load(int3(_3688, 0)).xyz;
                                }
                                else
                                {
                                    float3 _12103;
                                    if (_5297 == 8u)
                                    {
                                        _12103 = r_previous_interpolation_source.SampleLevel(s_LinearClamp, _4096, 0.0f).xyz;
                                    }
                                    else
                                    {
                                        float3 _12104;
                                        if (_5301)
                                        {
                                            uint _9691_dummy_parameter;
                                            uint _9723_dummy_parameter;
                                            _12104 = float3(log((r_depth_tp1.Load(int3(int2(floor(_4096 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _9691_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, log((r_depth_tm1.Load(int3(int2(floor(_4096 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _9723_dummy_parameter))))), 0)).x * 1200.0f) + 1.0f) * 0.14102561771869659423828125f, 0.0f);
                                        }
                                        else
                                        {
                                            float3 _12105;
                                            if (_5304)
                                            {
                                                _12105 = _6825;
                                            }
                                            else
                                            {
                                                float3 _12106;
                                                if (_5297 == 20u)
                                                {
                                                    _12106 = _6809;
                                                }
                                                else
                                                {
                                                    float3 _12107;
                                                    if (_5297 == 21u)
                                                    {
                                                        _12107 = _6817;
                                                    }
                                                    else
                                                    {
                                                        float3 _12108;
                                                        if (_5297 == 22u)
                                                        {
                                                            _12108 = _6833;
                                                        }
                                                        else
                                                        {
                                                            float3 _12109;
                                                            if (_5297 == 18u)
                                                            {
                                                                _12109 = _11764;
                                                            }
                                                            else
                                                            {
                                                                float3 _12110;
                                                                if (_5297 == 19u)
                                                                {
                                                                    _12110 = _11568;
                                                                }
                                                                else
                                                                {
                                                                    bool3 _12349 = (_5297 == 23u).xxx;
                                                                    _12110 = float3(_12349.x ? _11377.x : _12113.x, _12349.y ? _11377.y : _12113.y, _12349.z ? _11377.z : _12113.z);
                                                                }
                                                                _12109 = _12110;
                                                            }
                                                            _12108 = _12109;
                                                        }
                                                        _12107 = _12108;
                                                    }
                                                    _12106 = _12107;
                                                }
                                                _12105 = _12106;
                                            }
                                            _12104 = _12105;
                                        }
                                        _12103 = _12104;
                                    }
                                    _12102 = _12103;
                                }
                                _12101 = _12102;
                            }
                            _12100 = _12101;
                        }
                        _12099 = _12100;
                    }
                    _12098 = _12099;
                }
                _12097 = _12098;
            }
            _12096 = _12097;
        }
        float3 _12095;
        if ((_5297 >= 9u) && (_5297 <= 11u))
        {
            uint _5773 = 64u + uint((_10335.y * cbFI_MvDepthLaneSize.x) + _10335.x);
            uint _5777 = rw_nfru_diagnostics.Load<uint>(_5773 * 4 + 0) & 15u;
            float3 _12126;
            if (_5297 == 10u)
            {
                float3 _12094;
                if ((rw_nfru_diagnostics.Load<uint>(_5773 * 4 + 0) & 32u) != 0u)
                {
                    _12094 = float3(1.0f, 0.0f, 0.0f);
                }
                else
                {
                    float3 _12093;
                    if ((rw_nfru_diagnostics.Load<uint>(_5773 * 4 + 0) & 16u) != 0u)
                    {
                        _12093 = float3(1.0f, 1.0f, 0.0f);
                    }
                    else
                    {
                        bool3 _5798 = ((rw_nfru_diagnostics.Load<uint>(_5773 * 4 + 0) & 64u) != 0u).xxx;
                        _12093 = float3(_5798.x ? float3(0.0f, 1.0f, 1.0f).x : 0.07999999821186065673828125f.xxx.x, _5798.y ? float3(0.0f, 1.0f, 1.0f).y : 0.07999999821186065673828125f.xxx.y, _5798.z ? float3(0.0f, 1.0f, 1.0f).z : 0.07999999821186065673828125f.xxx.z);
                    }
                    _12094 = _12093;
                }
                _12126 = _12094;
            }
            else
            {
                float3 _12127;
                if (_5297 == 11u)
                {
                    uint _5811 = (rw_nfru_diagnostics.Load<uint>(_5773 * 4 + 0) >> 8u) & 15u;
                    uint _5814 = (rw_nfru_diagnostics.Load<uint>(_5773 * 4 + 0) >> 12u) & 15u;
                    float3 _12086;
                    if ((_5777 == 2u) || (_5777 == 3u))
                    {
                        _12086 = _3384[_5777];
                    }
                    else
                    {
                        bool _5826 = _5811 == 3u;
                        bool _5828 = _5814 == 3u;
                        float3 _12087;
                        if (_5826 && _5828)
                        {
                            _12087 = 1.0f.xxx;
                        }
                        else
                        {
                            float3 _12088;
                            if (_5826)
                            {
                                _12088 = float3(1.0f, 0.0f, 1.0f);
                            }
                            else
                            {
                                float3 _12089;
                                if (_5828)
                                {
                                    _12089 = float3(1.0f, 1.0f, 0.0f);
                                }
                                else
                                {
                                    float3 _12090;
                                    if ((_5811 == 4u) || (_5814 == 4u))
                                    {
                                        _12090 = float3(1.0f, 0.0f, 0.0f);
                                    }
                                    else
                                    {
                                        float3 _12091;
                                        if ((_5811 == 1u) || (_5814 == 1u))
                                        {
                                            _12091 = float3(1.0f, 0.5f, 0.0f);
                                        }
                                        else
                                        {
                                            bool3 _12351 = (_5777 == 1u).xxx;
                                            _12091 = float3(_12351.x ? float3(0.0f, 0.800000011920928955078125f, 0.0f).x : 0.07999999821186065673828125f.xxx.x, _12351.y ? float3(0.0f, 0.800000011920928955078125f, 0.0f).y : 0.07999999821186065673828125f.xxx.y, _12351.z ? float3(0.0f, 0.800000011920928955078125f, 0.0f).z : 0.07999999821186065673828125f.xxx.z);
                                        }
                                        _12090 = _12091;
                                    }
                                    _12089 = _12090;
                                }
                                _12088 = _12089;
                            }
                            _12087 = _12088;
                        }
                        _12086 = _12087;
                    }
                    _12127 = _12086;
                }
                else
                {
                    _12127 = _3384[min(_5777, 7u)];
                }
                _12126 = _12127;
            }
            _12095 = _12126;
        }
        else
        {
            _12095 = _12096;
        }
        float4 _12130;
        if ((_5297 >= 14u) && (_5297 <= 16u))
        {
            float2 _12128;
            if (_5297 == 14u)
            {
                uint _5884_dummy_parameter;
                uint _5890_dummy_parameter;
                _12128 = r_flow_tm1.Load(int3(clamp(int2(floor(_4096 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _5884_dummy_parameter))))), int2(0, 0), int2(spvTextureSize(r_flow_tm1, uint(0), _5890_dummy_parameter)) - int2(1, 1)), 0)).xy;
            }
            else
            {
                float2 _12129;
                if (_5297 == 16u)
                {
                    uint _9774 = r_warped_flow_qdata_tm1.Load(int3(_4112, 0)).x & 2147483647u;
                    uint _9806 = uint(max((int((_9774 >> 16u) & 15u) - 6), 0));
                    _12129 = ((float2(float((1 - (2 * int((_9774 >> 15u) & 1u))) * int(((_9774 >> uint(7)) & 127u) << _9806)), float((1 - (2 * int((_9774 >> 14u) & 1u))) * int((_9774 & 127u) << _9806))) * 0.0624427758157253265380859375f) * cbFI_FlowLaneSizeRcp) * float2(cbFI_DisplaySize);
                }
                else
                {
                    _12129 = _6104 * float2(cbFI_DisplaySize);
                }
                _12128 = _12129;
            }
            uint2 _5923 = uint2(clamp(round(_12128 * 2.0f) + 2048.0f.xx, 0.0f.xx, 4095.0f.xx));
            uint _5925 = _5923.x;
            uint _5932 = _5923.y;
            _12130 = float4(float(_5925 & 255u), float((_5925 >> 8u) | ((_5932 & 15u) << 4u)), float(_5932 >> 4u), 255.0f) * 0.0039215688593685626983642578125f.xxxx;
        }
        else
        {
            float4 _12131;
            if (_5297 == 17u)
            {
                _12131 = float4(float(r_warped_flow_qdata_tm1.Load(int3(_4112, 0)).x != 0u), _4455, 0.0f, 1.0f);
            }
            else
            {
                _12131 = float4(_12095, 1.0f);
            }
            _12130 = _12131;
        }
        rw_output[_3688] = _12130.xyz;
        if ((cbFI_NfruT2Flags & 256u) != 0u)
        {
            uint _5976 = ((uint(_3688.y) * uint(cbFI_DisplaySize.x)) + uint(_3688.x)) * 6u;
            uint _9852 = spvPackHalf2x16(clamp(_6808.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>(_5976 * 4 + 0, (((_9852 & 32767u) >> 4u) | ((((_9852 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6808.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9887 = spvPackHalf2x16(clamp(_6816.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5976 + 1u) * 4 + 0, (((_9887 & 32767u) >> 4u) | ((((_9887 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6816.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9922 = spvPackHalf2x16(clamp(_6824.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5976 + 2u) * 4 + 0, (((_9922 & 32767u) >> 4u) | ((((_9922 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6824.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _9957 = spvPackHalf2x16(clamp(_6832.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5976 + 3u) * 4 + 0, (((_9957 & 32767u) >> 4u) | ((((_9957 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_6832.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            float4 _9984 = r_current_interpolation_source.Load(int3(_3688, 0));
            uint _9998 = spvPackHalf2x16(clamp(_9984.xy, 0.0f.xx, 65000.0f.xx));
            rw_nfru_select.Store<uint>((_5976 + 4u) * 4 + 0, (((_9998 & 32767u) >> 4u) | ((((_9998 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_9984.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u));
            uint _12164;
            if (_12006 || (_5297 != 0u))
            {
                _12164 = 4294967295u;
            }
            else
            {
                uint _10033 = spvPackHalf2x16(clamp(_12130.xy, 0.0f.xx, 65000.0f.xx));
                _12164 = (((_10033 & 32767u) >> 4u) | ((((_10033 >> 16u) & 32767u) >> 4u) << 11u)) | (((spvPackHalf2x16(float2(clamp(_12130.z, 0.0f, 65000.0f), 0.0f)) & 32767u) >> 5u) << 22u);
            }
            rw_nfru_select.Store<uint>((_5976 + 5u) * 4 + 0, _12164);
        }
        if ((cbFI_NfruT2Flags & 4u) == 0u)
        {
            rw_previous_interpolation_source[_3688] = float4(r_current_interpolation_source.Load(int3(_3688, 0)).xyz, 1.0f).xyz;
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
