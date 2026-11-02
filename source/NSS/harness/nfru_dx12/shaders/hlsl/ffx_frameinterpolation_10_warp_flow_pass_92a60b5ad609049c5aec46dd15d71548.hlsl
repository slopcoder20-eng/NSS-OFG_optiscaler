static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _1322[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };
static const int2 _1536[9] = { int2(0, 0), int2(1, 0), int2(0, 1), int2(0, -1), int2(-1, 0), int2(-1, 1), int2(1, 1), int2(-1, -1), int2(1, -1) };

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
RWTexture2D<float> rw_depth_tm1_next : register(u8, space0);
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
    int2 _1953 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1953.x >= cbFI_MvDepthLaneSize.x, _1953.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2238 = _1953.x + (_1953.y * cbFI_MvDepthLaneSize.x);
        float _2245 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2247 = float2(_1953);
        float2 _2251 = (_2247 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2743 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5301;
        if (_2743)
        {
            float _2756 = ((2.0f * _2251.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5301 = float2(atan(_2756) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2251.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2756 * _2756))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5301 = _2251;
        }
        uint _2798_dummy_parameter;
        float4 _2805 = r_depth_tp1.Load(int3(int2(floor(_2251 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2798_dummy_parameter))))), 0));
        float _2806 = _2805.x;
        uint _2814_dummy_parameter;
        float4 _2821 = r_depth_tp1.Load(int3(int2(floor(_2251 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2814_dummy_parameter))))), 0));
        float _2822 = _2821.x;
        rw_depth_tm1_next[_1953] = float4(_2806, 0.0f, 0.0f, 0.0f).x;
        float2 _2846 = float2(_2251.x, 1.0f - _2251.y);
        float2 _2850 = (_2846 * 2.0f) - 1.0f.xx;
        float _2852 = _2850.x;
        float4 _2857 = mul(float4(_2852, _2850.y, _2806, 1.0f), cbFI_MotionTP1ToTM1);
        float _2859 = _2857.w;
        float _2861 = float(_2859 < 0.0f);
        float2 _2873 = _2846 - (((_2857.xy / _2859.xx) + 1.0f.xx) * 0.5f);
        float2 _2875 = abs(_2873);
        bool2 _2881 = all(bool2(_2875.x < 9.9999997473787516355514526367188e-06f.xx.x, _2875.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2882 = float2(_2881.x ? 0.0f.xx.x : _2873.x, _2881.y ? 0.0f.xx.y : _2873.y);
        bool2 _2887 = any(isnan(_2882)).xx;
        float2 _2888 = float2(_2887.x ? 0.0f.xx.x : _2882.x, _2887.y ? 0.0f.xx.y : _2882.y);
        bool2 _2893 = any(isinf(_2888)).xx;
        float2 _2894 = float2(_2893.x ? 0.0f.xx.x : _2888.x, _2893.y ? 0.0f.xx.y : _2888.y);
        float _2932 = 1.0f - (log((_2806 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5302;
        if (_2932 == 1.0f)
        {
            _5302 = _2932 + ((float(_2238) * _2245) * 0.100000001490116119384765625f);
        }
        else
        {
            _5302 = _2932;
        }
        float _2922 = 1.10000002384185791015625f - _5302;
        uint _2939_dummy_parameter;
        float2 _2954 = r_motion_tp1.Load(int3(int2(floor(_2251 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2939_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _2964 = (cbFI_pad0 & 512u) != 0u;
        if (_2964)
        {
            uint _2968;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _2968);
        }
        bool _2981;
        float _2275 = 1.0f - cbFI_Timestep;
        float2 _5303;
        float2 _5304;
        do
        {
            _2981 = !_2743;
            if (_2981)
            {
                _5304 = _2954;
                _5303 = _2954;
                break;
            }
            float2 _2988 = _2251 + _2954;
            float _3024 = ((2.0f * _2988.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _2991 = (float2(atan(_3024) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2988.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3024 * _3024))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5301;
            float2 _3073 = clamp((((_5301 + (_2991 * _2275)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3076 = tan(_3073.x);
            _5304 = _2991;
            _5303 = (((float2(_3076 / cbFI_DeviceToViewDepth.z, (tan(_3073.y) * sqrt(1.0f + (_3076 * _3076))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2251) / max(_2275, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _3122;
        bool _5307;
        int2 _5308;
        uint _5316;
        do
        {
            _3122 = float2(cbFI_MvDepthLaneSize);
            float2 _3123 = _5303 * _3122;
            float2 _3127 = _5304 * _3122;
            bool _3130 = any(isnan(_3123));
            bool _3137;
            if (!_3130)
            {
                _3137 = any(isinf(_3123));
            }
            else
            {
                _3137 = _3130;
            }
            bool _3144;
            if (!_3137)
            {
                _3144 = any(isnan(_3127));
            }
            else
            {
                _3144 = _3137;
            }
            bool _3151;
            if (!_3144)
            {
                _3151 = any(isinf(_3127));
            }
            else
            {
                _3151 = _3144;
            }
            bool _3157;
            if (!_3151)
            {
                _3157 = isnan(_2922);
            }
            else
            {
                _3157 = _3151;
            }
            bool _3163;
            if (!_3157)
            {
                _3163 = isinf(_2922);
            }
            else
            {
                _3163 = _3157;
            }
            if (_3163)
            {
                _5316 = 0u;
                _5308 = int2(0, 0);
                _5307 = false;
                break;
            }
            float2 _3168 = _3123 * _2275;
            bool _3171 = any(isnan(_3168));
            bool _3178;
            if (!_3171)
            {
                _3178 = any(isinf(_3168));
            }
            else
            {
                _3178 = _3171;
            }
            if (_3178)
            {
                _5316 = 0u;
                _5308 = int2(0, 0);
                _5307 = false;
                break;
            }
            float2 _3185 = _2247 + floor(_3168);
            bool _3188 = any(bool2(_3185.x < 0.0f.xx.x, _3185.y < 0.0f.xx.y));
            bool _3197;
            if (!_3188)
            {
                _3197 = any(bool2(_3185.x >= _3122.x, _3185.y >= _3122.y));
            }
            else
            {
                _3197 = _3188;
            }
            if (_3197)
            {
                _5316 = 0u;
                _5308 = int2(0, 0);
                _5307 = false;
                break;
            }
            float2 _3204 = _3127 * 1.0f;
            float _3251 = _3204.x * 16.0146636962890625f;
            int _3259 = int(clamp(sign(_3251) * ceil(abs(_3251)), -16383.0f, 16383.0f));
            float _3263 = _3204.y * 16.0146636962890625f;
            int _3271 = int(clamp(sign(_3263) * ceil(abs(_3263)), -16383.0f, 16383.0f));
            int _3278 = abs(_3259);
            int _3280 = abs(_3271);
            int _3284 = clamp(firstbithigh(max(_3278, _3280)), 0, 15);
            int _3287 = max((_3284 - 6), 0);
            _5316 = (((((uint((int(round(_2922 * 1860.9090576171875f)) & 2047) << 20) | uint((_3284 & 15) << 16)) | uint(int(_3259 < 0) << 15)) | uint(int(_3271 < 0) << 14)) | uint((clamp(_3278 >> _3287, 0, 127) & 127) << 7)) | uint(clamp(_3280 >> _3287, 0, 127) & 127)) & 2147483647u;
            _5308 = int2(_3185);
            _5307 = true;
            break;
        } while(false);
        if (_5307)
        {
            if (_2964)
            {
                uint _3373;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3373);
            }
            uint _3379;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5308], _5316, _3379);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5326 = 0; _5326 < 3; _5326++)
                {
                    int2 _2310 = _5308 + _1322[_5326];
                    if (all(bool2(_2310.x < cbFI_MvDepthLaneSize.x, _2310.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3384;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2310], _5316, _3384);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2332 = _2251 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2337 = _2251 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2342 = _2332.x < 1.0f;
                bool _2349;
                if (_2342)
                {
                    uint _3405_dummy_parameter;
                    float4 _3412 = r_depth_tp1.Load(int3(int2(floor(_2332 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3405_dummy_parameter))))), 0));
                    float _3413 = _3412.x;
                    _2349 = abs(_2822 - _3413) <= ((0.0500000007450580596923828125f * max(abs(_2822), abs(_3413))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2349 = _2342;
                }
                bool _2352 = _2337.y < 1.0f;
                bool _2359;
                if (_2352)
                {
                    uint _3435_dummy_parameter;
                    float4 _3442 = r_depth_tp1.Load(int3(int2(floor(_2337 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3435_dummy_parameter))))), 0));
                    float _3443 = _3442.x;
                    _2359 = abs(_2822 - _3443) <= ((0.0500000007450580596923828125f * max(abs(_2822), abs(_3443))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2359 = _2352;
                }
                float2 _3468 = (_2251 + (_2954 * _2275)) * _3122;
                uint _3475_dummy_parameter;
                uint _3512_dummy_parameter;
                float2 _5327;
                if (_2349)
                {
                    _5327 = ((_2332 + ((r_motion_tp1.Load(int3(int2(floor(_2332 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3475_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2275)) * _3122) - _3468;
                }
                else
                {
                    _5327 = float2(1.0f, 0.0f);
                }
                float2 _5328;
                if (_2359)
                {
                    _5328 = ((_2337 + ((r_motion_tp1.Load(int3(int2(floor(_2337 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3512_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2275)) * _3122) - _3468;
                }
                else
                {
                    _5328 = float2(0.0f, 1.0f);
                }
                bool _3568 = any(isnan(_5327));
                bool _3575;
                if (!_3568)
                {
                    _3575 = any(isinf(_5327));
                }
                else
                {
                    _3575 = _3568;
                }
                bool2 _5463 = _3575.xx;
                float2 _5464 = float2(_5463.x ? float2(1.0f, 0.0f).x : _5327.x, _5463.y ? float2(1.0f, 0.0f).y : _5327.y);
                bool _3580 = any(isnan(_5328));
                bool _3587;
                if (!_3580)
                {
                    _3587 = any(isinf(_5328));
                }
                else
                {
                    _3587 = _3580;
                }
                bool2 _5465 = _3587.xx;
                float2 _5466 = float2(_5465.x ? float2(0.0f, 1.0f).x : _5328.x, _5465.y ? float2(0.0f, 1.0f).y : _5328.y);
                int2 _3603 = int2(clamp(floor(min(0.0f.xx, _5464) + min(0.0f.xx, _5466)), (-3.0f).xx, 0.0f.xx));
                int2 _3609 = int2(clamp(ceil(max(0.0f.xx, _5464) + max(0.0f.xx, _5466)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3617 = _3603.y;
                for (int _5358 = _3617; _5358 <= _3609.y; _5358++)
                {
                    int _3626 = _3603.x;
                    for (int _5445 = _3626; _5445 <= _3609.x; _5445++)
                    {
                        if ((_5445 == 0) && (_5358 == 0))
                        {
                            continue;
                        }
                        int2 _3645 = _5308 + int2(_5445, _5358);
                        bool _3648 = all(bool2(_3645.x >= int2(0, 0).x, _3645.y >= int2(0, 0).y));
                        bool _3655;
                        if (_3648)
                        {
                            _3655 = all(bool2(_3645.x < cbFI_MvDepthLaneSize.x, _3645.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3655 = _3648;
                        }
                        if (_3655)
                        {
                            uint _3673;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3645], _5316, _3673);
                        }
                    }
                }
            }
        }
        else
        {
            if (_2964)
            {
                uint _3682;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3682);
            }
        }
        uint _3691_dummy_parameter;
        int2 _3691 = int2(spvTextureSize(r_depth_tp1, uint(0), _3691_dummy_parameter));
        float _2079[9];
        _2079[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2251 * float2(_3691))), int2(0, 0), _3691 - int2(1, 1)), 0)).x;
        uint _3716_dummy_parameter;
        int2 _3716 = int2(spvTextureSize(r_depth_tp1, uint(0), _3716_dummy_parameter));
        _2079[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2251 * float2(_3716))) + int2(1, 0), int2(0, 0), _3716 - int2(1, 1)), 0)).x;
        uint _3741_dummy_parameter;
        int2 _3741 = int2(spvTextureSize(r_depth_tp1, uint(0), _3741_dummy_parameter));
        _2079[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2251 * float2(_3741))) + int2(0, 1), int2(0, 0), _3741 - int2(1, 1)), 0)).x;
        uint _3766_dummy_parameter;
        int2 _3766 = int2(spvTextureSize(r_depth_tp1, uint(0), _3766_dummy_parameter));
        _2079[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2251 * float2(_3766))) + int2(0, -1), int2(0, 0), _3766 - int2(1, 1)), 0)).x;
        uint _3791_dummy_parameter;
        int2 _3791 = int2(spvTextureSize(r_depth_tp1, uint(0), _3791_dummy_parameter));
        _2079[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2251 * float2(_3791))) + int2(-1, 0), int2(0, 0), _3791 - int2(1, 1)), 0)).x;
        uint _3816_dummy_parameter;
        int2 _3816 = int2(spvTextureSize(r_depth_tp1, uint(0), _3816_dummy_parameter));
        _2079[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2251 * float2(_3816))) + int2(-1, 1), int2(0, 0), _3816 - int2(1, 1)), 0)).x;
        uint _3841_dummy_parameter;
        int2 _3841 = int2(spvTextureSize(r_depth_tp1, uint(0), _3841_dummy_parameter));
        _2079[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2251 * float2(_3841))) + int2(1, 1), int2(0, 0), _3841 - int2(1, 1)), 0)).x;
        uint _3866_dummy_parameter;
        int2 _3866 = int2(spvTextureSize(r_depth_tp1, uint(0), _3866_dummy_parameter));
        _2079[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2251 * float2(_3866))) + int2(-1, -1), int2(0, 0), _3866 - int2(1, 1)), 0)).x;
        uint _3891_dummy_parameter;
        int2 _3891 = int2(spvTextureSize(r_depth_tp1, uint(0), _3891_dummy_parameter));
        _2079[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2251 * float2(_3891))) + int2(1, -1), int2(0, 0), _3891 - int2(1, 1)), 0)).x;
        int _5360;
        _5360 = 0;
        float _5467;
        int _5468;
        int _5359 = 1;
        float _5443 = _2079[0];
        for (; _5359 < 9; _5443 = _5467, _5360 = _5468, _5359++)
        {
            bool _2432 = _2079[_5359] > _5443;
            _5467 = _2432 ? _2079[_5359] : _5443;
            _5468 = _2432 ? _5359 : _5360;
        }
        uint _3916_dummy_parameter;
        int2 _3916 = int2(spvTextureSize(r_motion_tp1, uint(0), _3916_dummy_parameter));
        float2 _3934 = r_motion_tp1.Load(int3(clamp(int2(floor(_2251 * float2(_3916))) + _1536[_5360], int2(0, 0), _3916 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5361;
        do
        {
            if (_2981)
            {
                _5361 = _3934;
                break;
            }
            float2 _3958 = _2251 + _3934;
            float _3994 = ((2.0f * _3958.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4043 = clamp((((_5301 + (((float2(atan(_3994) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3958.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3994 * _3994))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5301) * _2275)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4046 = tan(_4043.x);
            _5361 = (((float2(_4046 / cbFI_DeviceToViewDepth.z, (tan(_4043.y) * sqrt(1.0f + (_4046 * _4046))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2251) / max(_2275, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        rw_mv_holes_tp1[_1953 + int2(floor((_5361 * _3122) * _2275))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1953 + int2(floor(_3934 * _3122))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4116_dummy_parameter;
        float4 _4123 = r_depth_tm1.Load(int3(int2(floor(_2251 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4116_dummy_parameter))))), 0));
        float _4124 = _4123.x;
        float4 _4154 = mul(float4(_2852, _2850.y, _4124, 1.0f), cbFI_MotionTM1ToTP1);
        float _4156 = _4154.w;
        float2 _4170 = _2846 - (((_4154.xy / _4156.xx) + 1.0f.xx) * 0.5f);
        float2 _4172 = abs(_4170);
        bool2 _4178 = all(bool2(_4172.x < 9.9999997473787516355514526367188e-06f.xx.x, _4172.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4179 = float2(_4178.x ? 0.0f.xx.x : _4170.x, _4178.y ? 0.0f.xx.y : _4170.y);
        bool2 _4184 = any(isnan(_4179)).xx;
        float2 _4185 = float2(_4184.x ? 0.0f.xx.x : _4179.x, _4184.y ? 0.0f.xx.y : _4179.y);
        bool2 _4190 = any(isinf(_4185)).xx;
        float2 _4191 = float2(_4190.x ? 0.0f.xx.x : _4185.x, _4190.y ? 0.0f.xx.y : _4185.y);
        float2 _4197 = float2(-_4191.x, _4191.y);
        float2 _2473 = float2(-_2894.x, _2894.y) * _3122;
        float2 _2477 = _2954 * _3122;
        float2 _4252 = _2473 * 16.0146636962890625f;
        float2 _4262 = float2(int2(clamp(sign(_4252) * ceil(abs(_4252)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4278 = _2477 * 16.0146636962890625f;
        float2 _4288 = float2(int2(clamp(sign(_4278) * ceil(abs(_4278)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5362;
        if (max(max(length(_4262), length(_4288)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5362 = 0.0f;
        }
        else
        {
            _5362 = float(length(_4262 - _4288) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2482 = uint(_5362 > 0.0f);
        float _2494 = length(_2477);
        if (_2494 > 4.0f)
        {
            if (_2964)
            {
                uint _4305;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4305);
            }
        }
        bool _2506 = ((cbFI_pad0 & 2048u) != 0u) && (_2482 != 0u);
        bool _2518;
        if (_2506)
        {
            _2518 = length(_2473 - _2477) < (0.07999999821186065673828125f * max(length(_2473), _2494));
        }
        else
        {
            _2518 = _2506;
        }
        bool _2524 = (cbFI_NfruT2Flags & 2048u) != 0u;
        bool _2532;
        if (_2524)
        {
            _2532 = length(_2473 - _2477) > 2.0f;
        }
        else
        {
            _2532 = _2524;
        }
        uint _5471 = ((cbFI_NfruT2Flags & 4096u) != 0u) ? 1u : (_2532 ? 1u : (_2518 ? 0u : _2482));
        rw_dynamic_mask_tp1[_1953] = float4(clamp(float(_5471 + uint(_2861)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5471 != 0u)
        {
            if (_2964)
            {
                uint _4324;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4324);
            }
        }
        if (_2861 > 0.0f)
        {
            if (_2964)
            {
                uint _4334;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4334);
            }
        }
        if ((cbFI_NfruT2Flags & 512u) != 0u)
        {
            break;
        }
        bool _2566 = (cbFI_NfruT2Flags & 1024u) != 0u;
        bool _2572;
        if (_2566)
        {
            _2572 = (1.0f - (log((_4124 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f)) < 0.300000011920928955078125f;
        }
        else
        {
            _2572 = _2566;
        }
        if (_2572)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1953, 0)).x) + uint(float(_4156 < 0.0f))) > 0u)
        {
            if (_2964)
            {
                uint _4354;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4354);
            }
            break;
        }
        float _4387 = 1.0f - (log((_4124 * 1200.0f) + 1.0f) * 0.14102561771869659423828125f);
        float _5383;
        if (_4387 == 1.0f)
        {
            _5383 = _4387 + ((float(_2238) * _2245) * 0.100000001490116119384765625f);
        }
        else
        {
            _5383 = _4387;
        }
        float _4377 = 1.10000002384185791015625f - _5383;
        float2 _5384;
        float2 _5385;
        do
        {
            if (_2981)
            {
                _5385 = _4197;
                _5384 = _4197;
                break;
            }
            float2 _4406 = _2251 + _4197;
            float _4442 = ((2.0f * _4406.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4409 = (float2(atan(_4442) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4406.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4442 * _4442))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5301;
            float2 _4491 = clamp((((_5301 + (_4409 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4494 = tan(_4491.x);
            _5385 = _4409;
            _5384 = (((float2(_4494 / cbFI_DeviceToViewDepth.z, (tan(_4491.y) * sqrt(1.0f + (_4494 * _4494))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2251) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5387;
        int2 _5388;
        uint _5396;
        do
        {
            float2 _4541 = _5384 * _3122;
            float2 _4545 = _5385 * _3122;
            bool _4548 = any(isnan(_4541));
            bool _4555;
            if (!_4548)
            {
                _4555 = any(isinf(_4541));
            }
            else
            {
                _4555 = _4548;
            }
            bool _4562;
            if (!_4555)
            {
                _4562 = any(isnan(_4545));
            }
            else
            {
                _4562 = _4555;
            }
            bool _4569;
            if (!_4562)
            {
                _4569 = any(isinf(_4545));
            }
            else
            {
                _4569 = _4562;
            }
            bool _4575;
            if (!_4569)
            {
                _4575 = isnan(_4377);
            }
            else
            {
                _4575 = _4569;
            }
            bool _4581;
            if (!_4575)
            {
                _4581 = isinf(_4377);
            }
            else
            {
                _4581 = _4575;
            }
            if (_4581)
            {
                _5396 = 0u;
                _5388 = int2(0, 0);
                _5387 = false;
                break;
            }
            float2 _4586 = _4541 * cbFI_Timestep;
            bool _4589 = any(isnan(_4586));
            bool _4596;
            if (!_4589)
            {
                _4596 = any(isinf(_4586));
            }
            else
            {
                _4596 = _4589;
            }
            if (_4596)
            {
                _5396 = 0u;
                _5388 = int2(0, 0);
                _5387 = false;
                break;
            }
            float2 _4603 = _2247 + floor(_4586);
            bool _4606 = any(bool2(_4603.x < 0.0f.xx.x, _4603.y < 0.0f.xx.y));
            bool _4615;
            if (!_4606)
            {
                _4615 = any(bool2(_4603.x >= _3122.x, _4603.y >= _3122.y));
            }
            else
            {
                _4615 = _4606;
            }
            if (_4615)
            {
                _5396 = 0u;
                _5388 = int2(0, 0);
                _5387 = false;
                break;
            }
            float2 _4622 = _4545 * (-1.0f);
            float _4669 = _4622.x * 16.0146636962890625f;
            int _4677 = int(clamp(sign(_4669) * ceil(abs(_4669)), -16383.0f, 16383.0f));
            float _4681 = _4622.y * 16.0146636962890625f;
            int _4689 = int(clamp(sign(_4681) * ceil(abs(_4681)), -16383.0f, 16383.0f));
            int _4696 = abs(_4677);
            int _4698 = abs(_4689);
            int _4702 = clamp(firstbithigh(max(_4696, _4698)), 0, 15);
            int _4705 = max((_4702 - 6), 0);
            _5396 = (((((uint((int(round(_4377 * 1860.9090576171875f)) & 2047) << 20) | uint((_4702 & 15) << 16)) | uint(int(_4677 < 0) << 15)) | uint(int(_4689 < 0) << 14)) | uint((clamp(_4696 >> _4705, 0, 127) & 127) << 7)) | uint(clamp(_4698 >> _4705, 0, 127) & 127)) & 2147483647u;
            _5388 = int2(_4603);
            _5387 = true;
            break;
        } while(false);
        if (_5387)
        {
            uint _4787;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5388], _5396, _4787);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5404 = 0; _5404 < 3; _5404++)
                {
                    int2 _2621 = _5388 + _1322[_5404];
                    if (all(bool2(_2621.x < cbFI_MvDepthLaneSize.x, _2621.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4792;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2621], _5396, _4792);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2643 = _2251 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2648 = _2251 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4809_dummy_parameter;
                float4 _4816 = r_depth_tm1.Load(int3(int2(floor(_2251 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4809_dummy_parameter))))), 0));
                float _4817 = _4816.x;
                uint _4825_dummy_parameter;
                float4 _4832 = r_depth_tm1.Load(int3(int2(floor(_2643 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4825_dummy_parameter))))), 0));
                float _4833 = _4832.x;
                uint _4841_dummy_parameter;
                float4 _4848 = r_depth_tm1.Load(int3(int2(floor(_2648 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4841_dummy_parameter))))), 0));
                float _4849 = _4848.x;
                float _4864 = _2643.x;
                float2 _4868 = float2(_4864, 1.0f - _2643.y);
                float4 _4879 = mul(float4((_4868 * 2.0f) - 1.0f.xx, _4833, 1.0f), cbFI_MotionTM1ToTP1);
                float _4881 = _4879.w;
                float2 _4895 = _4868 - (((_4879.xy / _4881.xx) + 1.0f.xx) * 0.5f);
                float2 _4897 = abs(_4895);
                bool2 _4903 = all(bool2(_4897.x < 9.9999997473787516355514526367188e-06f.xx.x, _4897.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4904 = float2(_4903.x ? 0.0f.xx.x : _4895.x, _4903.y ? 0.0f.xx.y : _4895.y);
                bool2 _4909 = any(isnan(_4904)).xx;
                float2 _4910 = float2(_4909.x ? 0.0f.xx.x : _4904.x, _4909.y ? 0.0f.xx.y : _4904.y);
                bool2 _4915 = any(isinf(_4910)).xx;
                float2 _4916 = float2(_4915.x ? 0.0f.xx.x : _4910.x, _4915.y ? 0.0f.xx.y : _4910.y);
                float _4938 = _2648.y;
                float2 _4940 = float2(_2648.x, 1.0f - _4938);
                float4 _4951 = mul(float4((_4940 * 2.0f) - 1.0f.xx, _4849, 1.0f), cbFI_MotionTM1ToTP1);
                float _4953 = _4951.w;
                float2 _4967 = _4940 - (((_4951.xy / _4953.xx) + 1.0f.xx) * 0.5f);
                float2 _4969 = abs(_4967);
                bool2 _4975 = all(bool2(_4969.x < 9.9999997473787516355514526367188e-06f.xx.x, _4969.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4976 = float2(_4975.x ? 0.0f.xx.x : _4967.x, _4975.y ? 0.0f.xx.y : _4967.y);
                bool2 _4981 = any(isnan(_4976)).xx;
                float2 _4982 = float2(_4981.x ? 0.0f.xx.x : _4976.x, _4981.y ? 0.0f.xx.y : _4976.y);
                bool2 _4987 = any(isinf(_4982)).xx;
                float2 _4988 = float2(_4987.x ? 0.0f.xx.x : _4982.x, _4987.y ? 0.0f.xx.y : _4982.y);
                bool _2670 = (_4864 < 1.0f) && (float(_4881 < 0.0f) == 0.0f);
                bool _2676;
                if (_2670)
                {
                    _2676 = abs(_4817 - _4833) <= ((0.0500000007450580596923828125f * max(abs(_4817), abs(_4833))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2676 = _2670;
                }
                bool _2682 = (_4938 < 1.0f) && (float(_4953 < 0.0f) == 0.0f);
                bool _2688;
                if (_2682)
                {
                    _2688 = abs(_4817 - _4849) <= ((0.0500000007450580596923828125f * max(abs(_4817), abs(_4849))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2688 = _2682;
                }
                float2 _5036 = (_2251 + (_4197 * cbFI_Timestep)) * _3122;
                float2 _5405;
                if (_2676)
                {
                    _5405 = ((_2643 + (float2(-_4916.x, _4916.y) * cbFI_Timestep)) * _3122) - _5036;
                }
                else
                {
                    _5405 = float2(1.0f, 0.0f);
                }
                float2 _5406;
                if (_2688)
                {
                    _5406 = ((_2648 + (float2(-_4988.x, _4988.y) * cbFI_Timestep)) * _3122) - _5036;
                }
                else
                {
                    _5406 = float2(0.0f, 1.0f);
                }
                bool _5090 = any(isnan(_5405));
                bool _5097;
                if (!_5090)
                {
                    _5097 = any(isinf(_5405));
                }
                else
                {
                    _5097 = _5090;
                }
                bool2 _5472 = _5097.xx;
                float2 _5473 = float2(_5472.x ? float2(1.0f, 0.0f).x : _5405.x, _5472.y ? float2(1.0f, 0.0f).y : _5405.y);
                bool _5102 = any(isnan(_5406));
                bool _5109;
                if (!_5102)
                {
                    _5109 = any(isinf(_5406));
                }
                else
                {
                    _5109 = _5102;
                }
                bool2 _5474 = _5109.xx;
                float2 _5475 = float2(_5474.x ? float2(0.0f, 1.0f).x : _5406.x, _5474.y ? float2(0.0f, 1.0f).y : _5406.y);
                int2 _5125 = int2(clamp(floor(min(0.0f.xx, _5473) + min(0.0f.xx, _5475)), (-3.0f).xx, 0.0f.xx));
                int2 _5131 = int2(clamp(ceil(max(0.0f.xx, _5473) + max(0.0f.xx, _5475)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5139 = _5125.y;
                for (int _5436 = _5139; _5436 <= _5131.y; _5436++)
                {
                    int _5148 = _5125.x;
                    for (int _5437 = _5148; _5437 <= _5131.x; _5437++)
                    {
                        if ((_5437 == 0) && (_5436 == 0))
                        {
                            continue;
                        }
                        int2 _5167 = _5388 + int2(_5437, _5436);
                        bool _5170 = all(bool2(_5167.x >= int2(0, 0).x, _5167.y >= int2(0, 0).y));
                        bool _5177;
                        if (_5170)
                        {
                            _5177 = all(bool2(_5167.x < cbFI_MvDepthLaneSize.x, _5167.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5177 = _5170;
                        }
                        if (_5177)
                        {
                            uint _5195;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5167], _5396, _5195);
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
