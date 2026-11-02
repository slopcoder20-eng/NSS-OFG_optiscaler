static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1305[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };
static const int2 _1519[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

cbuffer cbFI_t : register(b9, space0)
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
Texture2D<float4> r_motion_tp1 : register(t0, space0);
Texture2D<float4> r_depth_tp1 : register(t1, space0);
Texture2D<float4> r_depth_tm1 : register(t2, space0);
Texture2D<float4> r_dynamic_mask_tm1 : register(t3, space0);
RWTexture2D<unorm float> rw_dynamic_mask_tp1 : register(u4, space0);
RWTexture2D<uint> rw_warped_motion_qdata_tp1 : register(u5, space0);
RWTexture2D<unorm float> rw_mv_holes_tp1 : register(u6, space0);
RWTexture2D<unorm float> rw_mv_holes_tm1 : register(u7, space0);

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

void comp_main()
{
    int2 _1892 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1892.x >= cbFI_MvDepthLaneSize.x, _1892.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2174 = _1892.x + (_1892.y * cbFI_MvDepthLaneSize.x);
        float _2181 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2183 = float2(_1892);
        float2 _2187 = (_2183 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2638 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5181;
        if (_2638)
        {
            float _2651 = ((2.0f * _2187.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5181 = float2(atan(_2651) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2187.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2651 * _2651))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5181 = _2187;
        }
        uint _2693_dummy_parameter;
        float4 _2700 = r_depth_tp1.Load(int3(int2(floor(_2187 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2693_dummy_parameter))))), 0));
        float _2701 = _2700.x;
        uint _2709_dummy_parameter;
        float4 _2716 = r_depth_tp1.Load(int3(int2(floor(_2187 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2709_dummy_parameter))))), 0));
        float _2717 = _2716.x;
        float2 _2736 = float2(_2187.x, 1.0f - _2187.y);
        float2 _2740 = (_2736 * 2.0f) - 1.0f.xx;
        float _2742 = _2740.x;
        float4 _2747 = mul(float4(_2742, _2740.y, _2701, 1.0f), cbFI_MotionTP1ToTM1);
        float _2749 = _2747.w;
        float _2751 = float(_2749 < 0.0f);
        float2 _2763 = _2736 - (((_2747.xy / _2749.xx) + 1.0f.xx) * 0.5f);
        float2 _2765 = abs(_2763);
        bool2 _2771 = all(bool2(_2765.x < 9.9999997473787516355514526367188e-06f.xx.x, _2765.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2772 = float2(_2771.x ? 0.0f.xx.x : _2763.x, _2771.y ? 0.0f.xx.y : _2763.y);
        bool2 _2777 = any(isnan(_2772)).xx;
        float2 _2778 = float2(_2777.x ? 0.0f.xx.x : _2772.x, _2777.y ? 0.0f.xx.y : _2772.y);
        bool2 _2783 = any(isinf(_2778)).xx;
        float2 _2784 = float2(_2783.x ? 0.0f.xx.x : _2778.x, _2783.y ? 0.0f.xx.y : _2778.y);
        float _2822 = 1.0f - (log(((_2701 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5182;
        if (_2822 == 1.0f)
        {
            _5182 = _2822 + ((float(_2174) * _2181) * 0.100000001490116119384765625f);
        }
        else
        {
            _5182 = _2822;
        }
        float _2812 = 1.10000002384185791015625f - _5182;
        uint _2829_dummy_parameter;
        float2 _2844 = r_motion_tp1.Load(int3(int2(floor(_2187 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2829_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _2854 = (cbFI_pad0 & 512u) != 0u;
        if (_2854)
        {
            uint _2858;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _2858);
        }
        bool _2871;
        float _2208 = 1.0f - cbFI_Timestep;
        float2 _5183;
        float2 _5184;
        do
        {
            _2871 = !_2638;
            if (_2871)
            {
                _5184 = _2844;
                _5183 = _2844;
                break;
            }
            float2 _2878 = _2187 + _2844;
            float _2914 = ((2.0f * _2878.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _2881 = (float2(atan(_2914) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2878.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2914 * _2914))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5181;
            float2 _2963 = clamp((((_5181 + (_2881 * _2208)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _2966 = tan(_2963.x);
            _5184 = _2881;
            _5183 = (((float2(_2966 / cbFI_DeviceToViewDepth.z, (tan(_2963.y) * sqrt(1.0f + (_2966 * _2966))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2187) / max(_2208, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _3012;
        bool _5187;
        int2 _5188;
        uint _5196;
        do
        {
            _3012 = float2(cbFI_MvDepthLaneSize);
            float2 _3013 = _5183 * _3012;
            float2 _3017 = _5184 * _3012;
            bool _3020 = any(isnan(_3013));
            bool _3027;
            if (!_3020)
            {
                _3027 = any(isinf(_3013));
            }
            else
            {
                _3027 = _3020;
            }
            bool _3034;
            if (!_3027)
            {
                _3034 = any(isnan(_3017));
            }
            else
            {
                _3034 = _3027;
            }
            bool _3041;
            if (!_3034)
            {
                _3041 = any(isinf(_3017));
            }
            else
            {
                _3041 = _3034;
            }
            bool _3047;
            if (!_3041)
            {
                _3047 = isnan(_2812);
            }
            else
            {
                _3047 = _3041;
            }
            bool _3053;
            if (!_3047)
            {
                _3053 = isinf(_2812);
            }
            else
            {
                _3053 = _3047;
            }
            if (_3053)
            {
                _5196 = 0u;
                _5188 = int2(0, 0);
                _5187 = false;
                break;
            }
            float2 _3058 = _3013 * _2208;
            bool _3061 = any(isnan(_3058));
            bool _3068;
            if (!_3061)
            {
                _3068 = any(isinf(_3058));
            }
            else
            {
                _3068 = _3061;
            }
            if (_3068)
            {
                _5196 = 0u;
                _5188 = int2(0, 0);
                _5187 = false;
                break;
            }
            float2 _3075 = _2183 + floor(_3058);
            bool _3078 = any(bool2(_3075.x < 0.0f.xx.x, _3075.y < 0.0f.xx.y));
            bool _3087;
            if (!_3078)
            {
                _3087 = any(bool2(_3075.x >= _3012.x, _3075.y >= _3012.y));
            }
            else
            {
                _3087 = _3078;
            }
            if (_3087)
            {
                _5196 = 0u;
                _5188 = int2(0, 0);
                _5187 = false;
                break;
            }
            float2 _3094 = _3017 * 1.0f;
            float _3141 = _3094.x * 16.0146636962890625f;
            int _3149 = int(clamp(sign(_3141) * ceil(abs(_3141)), -16383.0f, 16383.0f));
            float _3153 = _3094.y * 16.0146636962890625f;
            int _3161 = int(clamp(sign(_3153) * ceil(abs(_3153)), -16383.0f, 16383.0f));
            int _3168 = abs(_3149);
            int _3170 = abs(_3161);
            int _3174 = clamp(firstbithigh(max(_3168, _3170)), 0, 15);
            int _3177 = max((_3174 - 6), 0);
            _5196 = (((((uint((int(round(_2812 * 1860.9090576171875f)) & 2047) << 20) | uint((_3174 & 15) << 16)) | uint(int(_3149 < 0) << 15)) | uint(int(_3161 < 0) << 14)) | uint((clamp(_3168 >> _3177, 0, 127) & 127) << 7)) | uint(clamp(_3170 >> _3177, 0, 127) & 127)) & 2147483647u;
            _5188 = int2(_3075);
            _5187 = true;
            break;
        } while(false);
        if (_5187)
        {
            if (_2854)
            {
                uint _3263;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3263);
            }
            uint _3269;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5188], _5196, _3269);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5206 = 0; _5206 < 3; _5206++)
                {
                    int2 _2243 = _5188 + _1305[_5206];
                    if (all(bool2(_2243.x < cbFI_MvDepthLaneSize.x, _2243.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3274;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2243], _5196, _3274);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2265 = _2187 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2270 = _2187 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2275 = _2265.x < 1.0f;
                bool _2282;
                if (_2275)
                {
                    uint _3295_dummy_parameter;
                    float4 _3302 = r_depth_tp1.Load(int3(int2(floor(_2265 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3295_dummy_parameter))))), 0));
                    float _3303 = _3302.x;
                    _2282 = abs(_2717 - _3303) <= ((0.0500000007450580596923828125f * max(abs(_2717), abs(_3303))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2282 = _2275;
                }
                bool _2285 = _2270.y < 1.0f;
                bool _2292;
                if (_2285)
                {
                    uint _3325_dummy_parameter;
                    float4 _3332 = r_depth_tp1.Load(int3(int2(floor(_2270 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3325_dummy_parameter))))), 0));
                    float _3333 = _3332.x;
                    _2292 = abs(_2717 - _3333) <= ((0.0500000007450580596923828125f * max(abs(_2717), abs(_3333))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2292 = _2285;
                }
                float2 _3358 = (_2187 + (_2844 * _2208)) * _3012;
                uint _3365_dummy_parameter;
                uint _3402_dummy_parameter;
                float2 _5207;
                if (_2282)
                {
                    _5207 = ((_2265 + ((r_motion_tp1.Load(int3(int2(floor(_2265 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3365_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2208)) * _3012) - _3358;
                }
                else
                {
                    _5207 = float2(1.0f, 0.0f);
                }
                float2 _5208;
                if (_2292)
                {
                    _5208 = ((_2270 + ((r_motion_tp1.Load(int3(int2(floor(_2270 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3402_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2208)) * _3012) - _3358;
                }
                else
                {
                    _5208 = float2(0.0f, 1.0f);
                }
                bool _3458 = any(isnan(_5207));
                bool _3465;
                if (!_3458)
                {
                    _3465 = any(isinf(_5207));
                }
                else
                {
                    _3465 = _3458;
                }
                bool2 _5336 = _3465.xx;
                float2 _5337 = float2(_5336.x ? float2(1.0f, 0.0f).x : _5207.x, _5336.y ? float2(1.0f, 0.0f).y : _5207.y);
                bool _3470 = any(isnan(_5208));
                bool _3477;
                if (!_3470)
                {
                    _3477 = any(isinf(_5208));
                }
                else
                {
                    _3477 = _3470;
                }
                bool2 _5338 = _3477.xx;
                float2 _5339 = float2(_5338.x ? float2(0.0f, 1.0f).x : _5208.x, _5338.y ? float2(0.0f, 1.0f).y : _5208.y);
                int2 _3493 = int2(clamp(floor(min(0.0f.xx, _5337) + min(0.0f.xx, _5339)), (-3.0f).xx, 0.0f.xx));
                int2 _3499 = int2(clamp(ceil(max(0.0f.xx, _5337) + max(0.0f.xx, _5339)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3507 = _3493.y;
                for (int _5238 = _3507; _5238 <= _3499.y; _5238++)
                {
                    int _3516 = _3493.x;
                    for (int _5318 = _3516; _5318 <= _3499.x; _5318++)
                    {
                        if ((_5318 == 0) && (_5238 == 0))
                        {
                            continue;
                        }
                        int2 _3535 = _5188 + int2(_5318, _5238);
                        bool _3538 = all(bool2(_3535.x >= int2(0, 0).x, _3535.y >= int2(0, 0).y));
                        bool _3545;
                        if (_3538)
                        {
                            _3545 = all(bool2(_3535.x < cbFI_MvDepthLaneSize.x, _3535.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3545 = _3538;
                        }
                        if (_3545)
                        {
                            uint _3563;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3535], _5196, _3563);
                        }
                    }
                }
            }
        }
        else
        {
            if (_2854)
            {
                uint _3572;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3572);
            }
        }
        uint _3581_dummy_parameter;
        int2 _3581 = int2(spvTextureSize(r_depth_tp1, uint(0), _3581_dummy_parameter));
        float _2016[9];
        _2016[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2187 * float2(_3581))), int2(0, 0), _3581 - int2(1, 1)), 0)).x;
        uint _3606_dummy_parameter;
        int2 _3606 = int2(spvTextureSize(r_depth_tp1, uint(0), _3606_dummy_parameter));
        _2016[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2187 * float2(_3606))) + int2(1, 0), int2(0, 0), _3606 - int2(1, 1)), 0)).x;
        uint _3631_dummy_parameter;
        int2 _3631 = int2(spvTextureSize(r_depth_tp1, uint(0), _3631_dummy_parameter));
        _2016[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2187 * float2(_3631))) + int2(0, 1), int2(0, 0), _3631 - int2(1, 1)), 0)).x;
        uint _3656_dummy_parameter;
        int2 _3656 = int2(spvTextureSize(r_depth_tp1, uint(0), _3656_dummy_parameter));
        _2016[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2187 * float2(_3656))) + int2(0, -1), int2(0, 0), _3656 - int2(1, 1)), 0)).x;
        uint _3681_dummy_parameter;
        int2 _3681 = int2(spvTextureSize(r_depth_tp1, uint(0), _3681_dummy_parameter));
        _2016[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2187 * float2(_3681))) + int2(-1, 0), int2(0, 0), _3681 - int2(1, 1)), 0)).x;
        uint _3706_dummy_parameter;
        int2 _3706 = int2(spvTextureSize(r_depth_tp1, uint(0), _3706_dummy_parameter));
        _2016[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2187 * float2(_3706))) + int2(-1, 1), int2(0, 0), _3706 - int2(1, 1)), 0)).x;
        uint _3731_dummy_parameter;
        int2 _3731 = int2(spvTextureSize(r_depth_tp1, uint(0), _3731_dummy_parameter));
        _2016[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2187 * float2(_3731))) + int2(1, 1), int2(0, 0), _3731 - int2(1, 1)), 0)).x;
        uint _3756_dummy_parameter;
        int2 _3756 = int2(spvTextureSize(r_depth_tp1, uint(0), _3756_dummy_parameter));
        _2016[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2187 * float2(_3756))) + int2(-1, -1), int2(0, 0), _3756 - int2(1, 1)), 0)).x;
        uint _3781_dummy_parameter;
        int2 _3781 = int2(spvTextureSize(r_depth_tp1, uint(0), _3781_dummy_parameter));
        _2016[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2187 * float2(_3781))) + int2(1, -1), int2(0, 0), _3781 - int2(1, 1)), 0)).x;
        int _5240;
        _5240 = 0;
        float _5340;
        int _5341;
        int _5239 = 1;
        float _5316 = _2016[0];
        for (; _5239 < 9; _5316 = _5340, _5240 = _5341, _5239++)
        {
            bool _2365 = _2016[_5239] < _5316;
            _5340 = _2365 ? _2016[_5239] : _5316;
            _5341 = _2365 ? _5239 : _5240;
        }
        uint _3806_dummy_parameter;
        int2 _3806 = int2(spvTextureSize(r_motion_tp1, uint(0), _3806_dummy_parameter));
        float2 _3824 = r_motion_tp1.Load(int3(clamp(int2(floor(_2187 * float2(_3806))) + _1519[_5240], int2(0, 0), _3806 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5241;
        do
        {
            if (_2871)
            {
                _5241 = _3824;
                break;
            }
            float2 _3848 = _2187 + _3824;
            float _3884 = ((2.0f * _3848.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _3933 = clamp((((_5181 + (((float2(atan(_3884) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3848.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3884 * _3884))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5181) * _2208)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3936 = tan(_3933.x);
            _5241 = (((float2(_3936 / cbFI_DeviceToViewDepth.z, (tan(_3933.y) * sqrt(1.0f + (_3936 * _3936))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2187) / max(_2208, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        rw_mv_holes_tp1[_1892 + int2(floor((_5241 * _3012) * _2208))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1892 + int2(floor(_3824 * _3012))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4006_dummy_parameter;
        float4 _4013 = r_depth_tm1.Load(int3(int2(floor(_2187 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4006_dummy_parameter))))), 0));
        float _4014 = _4013.x;
        float4 _4044 = mul(float4(_2742, _2740.y, _4014, 1.0f), cbFI_MotionTM1ToTP1);
        float _4046 = _4044.w;
        float2 _4060 = _2736 - (((_4044.xy / _4046.xx) + 1.0f.xx) * 0.5f);
        float2 _4062 = abs(_4060);
        bool2 _4068 = all(bool2(_4062.x < 9.9999997473787516355514526367188e-06f.xx.x, _4062.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4069 = float2(_4068.x ? 0.0f.xx.x : _4060.x, _4068.y ? 0.0f.xx.y : _4060.y);
        bool2 _4074 = any(isnan(_4069)).xx;
        float2 _4075 = float2(_4074.x ? 0.0f.xx.x : _4069.x, _4074.y ? 0.0f.xx.y : _4069.y);
        bool2 _4080 = any(isinf(_4075)).xx;
        float2 _4081 = float2(_4080.x ? 0.0f.xx.x : _4075.x, _4080.y ? 0.0f.xx.y : _4075.y);
        float2 _4087 = float2(-_4081.x, _4081.y);
        float2 _2406 = float2(-_2784.x, _2784.y) * _3012;
        float2 _2410 = _2844 * _3012;
        float2 _4142 = _2406 * 16.0146636962890625f;
        float2 _4152 = float2(int2(clamp(sign(_4142) * ceil(abs(_4142)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4168 = _2410 * 16.0146636962890625f;
        float2 _4178 = float2(int2(clamp(sign(_4168) * ceil(abs(_4168)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5242;
        if (max(max(length(_4152), length(_4178)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5242 = 0.0f;
        }
        else
        {
            _5242 = float(length(_4152 - _4178) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2415 = uint(_5242 > 0.0f);
        float _2427 = length(_2410);
        if (_2427 > 4.0f)
        {
            if (_2854)
            {
                uint _4195;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4195);
            }
        }
        bool _2439 = ((cbFI_pad0 & 2048u) != 0u) && (_2415 != 0u);
        bool _2451;
        if (_2439)
        {
            _2451 = length(_2406 - _2410) < (0.07999999821186065673828125f * max(length(_2406), _2427));
        }
        else
        {
            _2451 = _2439;
        }
        uint _5342 = _2451 ? 0u : _2415;
        rw_dynamic_mask_tp1[_1892] = float4(clamp(float(_5342 + uint(_2751)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5342 != 0u)
        {
            if (_2854)
            {
                uint _4214;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4214);
            }
        }
        if (_2751 > 0.0f)
        {
            if (_2854)
            {
                uint _4224;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4224);
            }
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1892, 0)).x) + uint(float(_4046 < 0.0f))) > 0u)
        {
            if (_2854)
            {
                uint _4234;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4234);
            }
            break;
        }
        float _4267 = 1.0f - (log(((_4014 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5256;
        if (_4267 == 1.0f)
        {
            _5256 = _4267 + ((float(_2174) * _2181) * 0.100000001490116119384765625f);
        }
        else
        {
            _5256 = _4267;
        }
        float _4257 = 1.10000002384185791015625f - _5256;
        float2 _5257;
        float2 _5258;
        do
        {
            if (_2871)
            {
                _5258 = _4087;
                _5257 = _4087;
                break;
            }
            float2 _4286 = _2187 + _4087;
            float _4322 = ((2.0f * _4286.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4289 = (float2(atan(_4322) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4286.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4322 * _4322))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5181;
            float2 _4371 = clamp((((_5181 + (_4289 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4374 = tan(_4371.x);
            _5258 = _4289;
            _5257 = (((float2(_4374 / cbFI_DeviceToViewDepth.z, (tan(_4371.y) * sqrt(1.0f + (_4374 * _4374))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2187) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5260;
        int2 _5261;
        uint _5269;
        do
        {
            float2 _4421 = _5257 * _3012;
            float2 _4425 = _5258 * _3012;
            bool _4428 = any(isnan(_4421));
            bool _4435;
            if (!_4428)
            {
                _4435 = any(isinf(_4421));
            }
            else
            {
                _4435 = _4428;
            }
            bool _4442;
            if (!_4435)
            {
                _4442 = any(isnan(_4425));
            }
            else
            {
                _4442 = _4435;
            }
            bool _4449;
            if (!_4442)
            {
                _4449 = any(isinf(_4425));
            }
            else
            {
                _4449 = _4442;
            }
            bool _4455;
            if (!_4449)
            {
                _4455 = isnan(_4257);
            }
            else
            {
                _4455 = _4449;
            }
            bool _4461;
            if (!_4455)
            {
                _4461 = isinf(_4257);
            }
            else
            {
                _4461 = _4455;
            }
            if (_4461)
            {
                _5269 = 0u;
                _5261 = int2(0, 0);
                _5260 = false;
                break;
            }
            float2 _4466 = _4421 * cbFI_Timestep;
            bool _4469 = any(isnan(_4466));
            bool _4476;
            if (!_4469)
            {
                _4476 = any(isinf(_4466));
            }
            else
            {
                _4476 = _4469;
            }
            if (_4476)
            {
                _5269 = 0u;
                _5261 = int2(0, 0);
                _5260 = false;
                break;
            }
            float2 _4483 = _2183 + floor(_4466);
            bool _4486 = any(bool2(_4483.x < 0.0f.xx.x, _4483.y < 0.0f.xx.y));
            bool _4495;
            if (!_4486)
            {
                _4495 = any(bool2(_4483.x >= _3012.x, _4483.y >= _3012.y));
            }
            else
            {
                _4495 = _4486;
            }
            if (_4495)
            {
                _5269 = 0u;
                _5261 = int2(0, 0);
                _5260 = false;
                break;
            }
            float2 _4502 = _4425 * (-1.0f);
            float _4549 = _4502.x * 16.0146636962890625f;
            int _4557 = int(clamp(sign(_4549) * ceil(abs(_4549)), -16383.0f, 16383.0f));
            float _4561 = _4502.y * 16.0146636962890625f;
            int _4569 = int(clamp(sign(_4561) * ceil(abs(_4561)), -16383.0f, 16383.0f));
            int _4576 = abs(_4557);
            int _4578 = abs(_4569);
            int _4582 = clamp(firstbithigh(max(_4576, _4578)), 0, 15);
            int _4585 = max((_4582 - 6), 0);
            _5269 = (((((uint((int(round(_4257 * 1860.9090576171875f)) & 2047) << 20) | uint((_4582 & 15) << 16)) | uint(int(_4557 < 0) << 15)) | uint(int(_4569 < 0) << 14)) | uint((clamp(_4576 >> _4585, 0, 127) & 127) << 7)) | uint(clamp(_4578 >> _4585, 0, 127) & 127)) & 2147483647u;
            _5261 = int2(_4483);
            _5260 = true;
            break;
        } while(false);
        if (_5260)
        {
            uint _4667;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5261], _5269, _4667);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5277 = 0; _5277 < 3; _5277++)
                {
                    int2 _2516 = _5261 + _1305[_5277];
                    if (all(bool2(_2516.x < cbFI_MvDepthLaneSize.x, _2516.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4672;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2516], _5269, _4672);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2538 = _2187 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2543 = _2187 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4689_dummy_parameter;
                float4 _4696 = r_depth_tm1.Load(int3(int2(floor(_2187 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4689_dummy_parameter))))), 0));
                float _4697 = _4696.x;
                uint _4705_dummy_parameter;
                float4 _4712 = r_depth_tm1.Load(int3(int2(floor(_2538 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4705_dummy_parameter))))), 0));
                float _4713 = _4712.x;
                uint _4721_dummy_parameter;
                float4 _4728 = r_depth_tm1.Load(int3(int2(floor(_2543 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4721_dummy_parameter))))), 0));
                float _4729 = _4728.x;
                float _4744 = _2538.x;
                float2 _4748 = float2(_4744, 1.0f - _2538.y);
                float4 _4759 = mul(float4((_4748 * 2.0f) - 1.0f.xx, _4713, 1.0f), cbFI_MotionTM1ToTP1);
                float _4761 = _4759.w;
                float2 _4775 = _4748 - (((_4759.xy / _4761.xx) + 1.0f.xx) * 0.5f);
                float2 _4777 = abs(_4775);
                bool2 _4783 = all(bool2(_4777.x < 9.9999997473787516355514526367188e-06f.xx.x, _4777.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4784 = float2(_4783.x ? 0.0f.xx.x : _4775.x, _4783.y ? 0.0f.xx.y : _4775.y);
                bool2 _4789 = any(isnan(_4784)).xx;
                float2 _4790 = float2(_4789.x ? 0.0f.xx.x : _4784.x, _4789.y ? 0.0f.xx.y : _4784.y);
                bool2 _4795 = any(isinf(_4790)).xx;
                float2 _4796 = float2(_4795.x ? 0.0f.xx.x : _4790.x, _4795.y ? 0.0f.xx.y : _4790.y);
                float _4818 = _2543.y;
                float2 _4820 = float2(_2543.x, 1.0f - _4818);
                float4 _4831 = mul(float4((_4820 * 2.0f) - 1.0f.xx, _4729, 1.0f), cbFI_MotionTM1ToTP1);
                float _4833 = _4831.w;
                float2 _4847 = _4820 - (((_4831.xy / _4833.xx) + 1.0f.xx) * 0.5f);
                float2 _4849 = abs(_4847);
                bool2 _4855 = all(bool2(_4849.x < 9.9999997473787516355514526367188e-06f.xx.x, _4849.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4856 = float2(_4855.x ? 0.0f.xx.x : _4847.x, _4855.y ? 0.0f.xx.y : _4847.y);
                bool2 _4861 = any(isnan(_4856)).xx;
                float2 _4862 = float2(_4861.x ? 0.0f.xx.x : _4856.x, _4861.y ? 0.0f.xx.y : _4856.y);
                bool2 _4867 = any(isinf(_4862)).xx;
                float2 _4868 = float2(_4867.x ? 0.0f.xx.x : _4862.x, _4867.y ? 0.0f.xx.y : _4862.y);
                bool _2565 = (_4744 < 1.0f) && (float(_4761 < 0.0f) == 0.0f);
                bool _2571;
                if (_2565)
                {
                    _2571 = abs(_4697 - _4713) <= ((0.0500000007450580596923828125f * max(abs(_4697), abs(_4713))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2571 = _2565;
                }
                bool _2577 = (_4818 < 1.0f) && (float(_4833 < 0.0f) == 0.0f);
                bool _2583;
                if (_2577)
                {
                    _2583 = abs(_4697 - _4729) <= ((0.0500000007450580596923828125f * max(abs(_4697), abs(_4729))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2583 = _2577;
                }
                float2 _4916 = (_2187 + (_4087 * cbFI_Timestep)) * _3012;
                float2 _5278;
                if (_2571)
                {
                    _5278 = ((_2538 + (float2(-_4796.x, _4796.y) * cbFI_Timestep)) * _3012) - _4916;
                }
                else
                {
                    _5278 = float2(1.0f, 0.0f);
                }
                float2 _5279;
                if (_2583)
                {
                    _5279 = ((_2543 + (float2(-_4868.x, _4868.y) * cbFI_Timestep)) * _3012) - _4916;
                }
                else
                {
                    _5279 = float2(0.0f, 1.0f);
                }
                bool _4970 = any(isnan(_5278));
                bool _4977;
                if (!_4970)
                {
                    _4977 = any(isinf(_5278));
                }
                else
                {
                    _4977 = _4970;
                }
                bool2 _5343 = _4977.xx;
                float2 _5344 = float2(_5343.x ? float2(1.0f, 0.0f).x : _5278.x, _5343.y ? float2(1.0f, 0.0f).y : _5278.y);
                bool _4982 = any(isnan(_5279));
                bool _4989;
                if (!_4982)
                {
                    _4989 = any(isinf(_5279));
                }
                else
                {
                    _4989 = _4982;
                }
                bool2 _5345 = _4989.xx;
                float2 _5346 = float2(_5345.x ? float2(0.0f, 1.0f).x : _5279.x, _5345.y ? float2(0.0f, 1.0f).y : _5279.y);
                int2 _5005 = int2(clamp(floor(min(0.0f.xx, _5344) + min(0.0f.xx, _5346)), (-3.0f).xx, 0.0f.xx));
                int2 _5011 = int2(clamp(ceil(max(0.0f.xx, _5344) + max(0.0f.xx, _5346)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5019 = _5005.y;
                for (int _5309 = _5019; _5309 <= _5011.y; _5309++)
                {
                    int _5028 = _5005.x;
                    for (int _5310 = _5028; _5310 <= _5011.x; _5310++)
                    {
                        if ((_5310 == 0) && (_5309 == 0))
                        {
                            continue;
                        }
                        int2 _5047 = _5261 + int2(_5310, _5309);
                        bool _5050 = all(bool2(_5047.x >= int2(0, 0).x, _5047.y >= int2(0, 0).y));
                        bool _5057;
                        if (_5050)
                        {
                            _5057 = all(bool2(_5047.x < cbFI_MvDepthLaneSize.x, _5047.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5057 = _5050;
                        }
                        if (_5057)
                        {
                            uint _5075;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5047], _5269, _5075);
                        }
                    }
                }
            }
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
