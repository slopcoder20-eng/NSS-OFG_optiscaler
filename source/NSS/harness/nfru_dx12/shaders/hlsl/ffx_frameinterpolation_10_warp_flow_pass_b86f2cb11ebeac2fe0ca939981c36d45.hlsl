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
    int2 _1947 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1947.x >= cbFI_MvDepthLaneSize.x, _1947.y >= cbFI_MvDepthLaneSize.y)))
        {
            break;
        }
        int _2232 = _1947.x + (_1947.y * cbFI_MvDepthLaneSize.x);
        float _2239 = 1.0f / float(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y);
        float2 _2241 = float2(_1947);
        float2 _2245 = (_2241 + 0.5f.xx) * cbFI_MvDepthLaneSizeRcp;
        bool _2731 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _5289;
        if (_2731)
        {
            float _2744 = ((2.0f * _2245.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            _5289 = float2(atan(_2744) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2245.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_2744 * _2744))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx;
        }
        else
        {
            _5289 = _2245;
        }
        uint _2786_dummy_parameter;
        float4 _2793 = r_depth_tp1.Load(int3(int2(floor(_2245 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2786_dummy_parameter))))), 0));
        float _2794 = _2793.x;
        uint _2802_dummy_parameter;
        float4 _2809 = r_depth_tp1.Load(int3(int2(floor(_2245 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _2802_dummy_parameter))))), 0));
        float _2810 = _2809.x;
        rw_depth_tm1_next[_1947] = float4(_2794, 0.0f, 0.0f, 0.0f).x;
        float2 _2834 = float2(_2245.x, 1.0f - _2245.y);
        float2 _2838 = (_2834 * 2.0f) - 1.0f.xx;
        float _2840 = _2838.x;
        float4 _2845 = mul(float4(_2840, _2838.y, _2794, 1.0f), cbFI_MotionTP1ToTM1);
        float _2847 = _2845.w;
        float _2849 = float(_2847 < 0.0f);
        float2 _2861 = _2834 - (((_2845.xy / _2847.xx) + 1.0f.xx) * 0.5f);
        float2 _2863 = abs(_2861);
        bool2 _2869 = all(bool2(_2863.x < 9.9999997473787516355514526367188e-06f.xx.x, _2863.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _2870 = float2(_2869.x ? 0.0f.xx.x : _2861.x, _2869.y ? 0.0f.xx.y : _2861.y);
        bool2 _2875 = any(isnan(_2870)).xx;
        float2 _2876 = float2(_2875.x ? 0.0f.xx.x : _2870.x, _2875.y ? 0.0f.xx.y : _2870.y);
        bool2 _2881 = any(isinf(_2876)).xx;
        float2 _2882 = float2(_2881.x ? 0.0f.xx.x : _2876.x, _2881.y ? 0.0f.xx.y : _2876.y);
        float _2920 = 1.0f - (log(((_2794 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5290;
        if (_2920 == 1.0f)
        {
            _5290 = _2920 + ((float(_2232) * _2239) * 0.100000001490116119384765625f);
        }
        else
        {
            _5290 = _2920;
        }
        float _2910 = 1.10000002384185791015625f - _5290;
        uint _2927_dummy_parameter;
        float2 _2942 = r_motion_tp1.Load(int3(int2(floor(_2245 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _2927_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale;
        bool _2952 = (cbFI_pad0 & 512u) != 0u;
        if (_2952)
        {
            uint _2956;
            rw_nfru_diagnostics.InterlockedAdd(0, 1u, _2956);
        }
        bool _2969;
        float _2269 = 1.0f - cbFI_Timestep;
        float2 _5291;
        float2 _5292;
        do
        {
            _2969 = !_2731;
            if (_2969)
            {
                _5292 = _2942;
                _5291 = _2942;
                break;
            }
            float2 _2976 = _2245 + _2942;
            float _3012 = ((2.0f * _2976.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _2979 = (float2(atan(_3012) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _2976.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3012 * _3012))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5289;
            float2 _3061 = clamp((((_5289 + (_2979 * _2269)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _3064 = tan(_3061.x);
            _5292 = _2979;
            _5291 = (((float2(_3064 / cbFI_DeviceToViewDepth.z, (tan(_3061.y) * sqrt(1.0f + (_3064 * _3064))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2245) / max(_2269, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        float2 _3110;
        bool _5295;
        int2 _5296;
        uint _5304;
        do
        {
            _3110 = float2(cbFI_MvDepthLaneSize);
            float2 _3111 = _5291 * _3110;
            float2 _3115 = _5292 * _3110;
            bool _3118 = any(isnan(_3111));
            bool _3125;
            if (!_3118)
            {
                _3125 = any(isinf(_3111));
            }
            else
            {
                _3125 = _3118;
            }
            bool _3132;
            if (!_3125)
            {
                _3132 = any(isnan(_3115));
            }
            else
            {
                _3132 = _3125;
            }
            bool _3139;
            if (!_3132)
            {
                _3139 = any(isinf(_3115));
            }
            else
            {
                _3139 = _3132;
            }
            bool _3145;
            if (!_3139)
            {
                _3145 = isnan(_2910);
            }
            else
            {
                _3145 = _3139;
            }
            bool _3151;
            if (!_3145)
            {
                _3151 = isinf(_2910);
            }
            else
            {
                _3151 = _3145;
            }
            if (_3151)
            {
                _5304 = 0u;
                _5296 = int2(0, 0);
                _5295 = false;
                break;
            }
            float2 _3156 = _3111 * _2269;
            bool _3159 = any(isnan(_3156));
            bool _3166;
            if (!_3159)
            {
                _3166 = any(isinf(_3156));
            }
            else
            {
                _3166 = _3159;
            }
            if (_3166)
            {
                _5304 = 0u;
                _5296 = int2(0, 0);
                _5295 = false;
                break;
            }
            float2 _3173 = _2241 + floor(_3156);
            bool _3176 = any(bool2(_3173.x < 0.0f.xx.x, _3173.y < 0.0f.xx.y));
            bool _3185;
            if (!_3176)
            {
                _3185 = any(bool2(_3173.x >= _3110.x, _3173.y >= _3110.y));
            }
            else
            {
                _3185 = _3176;
            }
            if (_3185)
            {
                _5304 = 0u;
                _5296 = int2(0, 0);
                _5295 = false;
                break;
            }
            float2 _3192 = _3115 * 1.0f;
            float _3239 = _3192.x * 16.0146636962890625f;
            int _3247 = int(clamp(sign(_3239) * ceil(abs(_3239)), -16383.0f, 16383.0f));
            float _3251 = _3192.y * 16.0146636962890625f;
            int _3259 = int(clamp(sign(_3251) * ceil(abs(_3251)), -16383.0f, 16383.0f));
            int _3266 = abs(_3247);
            int _3268 = abs(_3259);
            int _3272 = clamp(firstbithigh(max(_3266, _3268)), 0, 15);
            int _3275 = max((_3272 - 6), 0);
            _5304 = (((((uint((int(round(_2910 * 1860.9090576171875f)) & 2047) << 20) | uint((_3272 & 15) << 16)) | uint(int(_3247 < 0) << 15)) | uint(int(_3259 < 0) << 14)) | uint((clamp(_3266 >> _3275, 0, 127) & 127) << 7)) | uint(clamp(_3268 >> _3275, 0, 127) & 127)) & 2147483647u;
            _5296 = int2(_3173);
            _5295 = true;
            break;
        } while(false);
        if (_5295)
        {
            if (_2952)
            {
                uint _3361;
                rw_nfru_diagnostics.InterlockedAdd(12, 1u, _3361);
            }
            uint _3367;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5296], _5304, _3367);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5314 = 0; _5314 < 3; _5314++)
                {
                    int2 _2304 = _5296 + _1322[_5314];
                    if (all(bool2(_2304.x < cbFI_MvDepthLaneSize.x, _2304.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _3372;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2304], _5304, _3372);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2326 = _2245 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2331 = _2245 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                bool _2336 = _2326.x < 1.0f;
                bool _2343;
                if (_2336)
                {
                    uint _3393_dummy_parameter;
                    float4 _3400 = r_depth_tp1.Load(int3(int2(floor(_2326 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3393_dummy_parameter))))), 0));
                    float _3401 = _3400.x;
                    _2343 = abs(_2810 - _3401) <= ((0.0500000007450580596923828125f * max(abs(_2810), abs(_3401))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2343 = _2336;
                }
                bool _2346 = _2331.y < 1.0f;
                bool _2353;
                if (_2346)
                {
                    uint _3423_dummy_parameter;
                    float4 _3430 = r_depth_tp1.Load(int3(int2(floor(_2331 * float2(int2(spvTextureSize(r_depth_tp1, uint(0), _3423_dummy_parameter))))), 0));
                    float _3431 = _3430.x;
                    _2353 = abs(_2810 - _3431) <= ((0.0500000007450580596923828125f * max(abs(_2810), abs(_3431))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2353 = _2346;
                }
                float2 _3456 = (_2245 + (_2942 * _2269)) * _3110;
                uint _3463_dummy_parameter;
                uint _3500_dummy_parameter;
                float2 _5315;
                if (_2343)
                {
                    _5315 = ((_2326 + ((r_motion_tp1.Load(int3(int2(floor(_2326 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3463_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2269)) * _3110) - _3456;
                }
                else
                {
                    _5315 = float2(1.0f, 0.0f);
                }
                float2 _5316;
                if (_2353)
                {
                    _5316 = ((_2331 + ((r_motion_tp1.Load(int3(int2(floor(_2331 * float2(int2(spvTextureSize(r_motion_tp1, uint(0), _3500_dummy_parameter))))), 0)).xy * cbFI_MotionVectorScale) * _2269)) * _3110) - _3456;
                }
                else
                {
                    _5316 = float2(0.0f, 1.0f);
                }
                bool _3556 = any(isnan(_5315));
                bool _3563;
                if (!_3556)
                {
                    _3563 = any(isinf(_5315));
                }
                else
                {
                    _3563 = _3556;
                }
                bool2 _5449 = _3563.xx;
                float2 _5450 = float2(_5449.x ? float2(1.0f, 0.0f).x : _5315.x, _5449.y ? float2(1.0f, 0.0f).y : _5315.y);
                bool _3568 = any(isnan(_5316));
                bool _3575;
                if (!_3568)
                {
                    _3575 = any(isinf(_5316));
                }
                else
                {
                    _3575 = _3568;
                }
                bool2 _5451 = _3575.xx;
                float2 _5452 = float2(_5451.x ? float2(0.0f, 1.0f).x : _5316.x, _5451.y ? float2(0.0f, 1.0f).y : _5316.y);
                int2 _3591 = int2(clamp(floor(min(0.0f.xx, _5450) + min(0.0f.xx, _5452)), (-3.0f).xx, 0.0f.xx));
                int2 _3597 = int2(clamp(ceil(max(0.0f.xx, _5450) + max(0.0f.xx, _5452)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _3605 = _3591.y;
                for (int _5346 = _3605; _5346 <= _3597.y; _5346++)
                {
                    int _3614 = _3591.x;
                    for (int _5431 = _3614; _5431 <= _3597.x; _5431++)
                    {
                        if ((_5431 == 0) && (_5346 == 0))
                        {
                            continue;
                        }
                        int2 _3633 = _5296 + int2(_5431, _5346);
                        bool _3636 = all(bool2(_3633.x >= int2(0, 0).x, _3633.y >= int2(0, 0).y));
                        bool _3643;
                        if (_3636)
                        {
                            _3643 = all(bool2(_3633.x < cbFI_MvDepthLaneSize.x, _3633.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _3643 = _3636;
                        }
                        if (_3643)
                        {
                            uint _3661;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_3633], _5304, _3661);
                        }
                    }
                }
            }
        }
        else
        {
            if (_2952)
            {
                uint _3670;
                rw_nfru_diagnostics.InterlockedAdd(16, 1u, _3670);
            }
        }
        uint _3679_dummy_parameter;
        int2 _3679 = int2(spvTextureSize(r_depth_tp1, uint(0), _3679_dummy_parameter));
        float _2073[9];
        _2073[0] = r_depth_tp1.Load(int3(clamp(int2(floor(_2245 * float2(_3679))), int2(0, 0), _3679 - int2(1, 1)), 0)).x;
        uint _3704_dummy_parameter;
        int2 _3704 = int2(spvTextureSize(r_depth_tp1, uint(0), _3704_dummy_parameter));
        _2073[1] = r_depth_tp1.Load(int3(clamp(int2(floor(_2245 * float2(_3704))) + int2(1, 0), int2(0, 0), _3704 - int2(1, 1)), 0)).x;
        uint _3729_dummy_parameter;
        int2 _3729 = int2(spvTextureSize(r_depth_tp1, uint(0), _3729_dummy_parameter));
        _2073[2] = r_depth_tp1.Load(int3(clamp(int2(floor(_2245 * float2(_3729))) + int2(0, 1), int2(0, 0), _3729 - int2(1, 1)), 0)).x;
        uint _3754_dummy_parameter;
        int2 _3754 = int2(spvTextureSize(r_depth_tp1, uint(0), _3754_dummy_parameter));
        _2073[3] = r_depth_tp1.Load(int3(clamp(int2(floor(_2245 * float2(_3754))) + int2(0, -1), int2(0, 0), _3754 - int2(1, 1)), 0)).x;
        uint _3779_dummy_parameter;
        int2 _3779 = int2(spvTextureSize(r_depth_tp1, uint(0), _3779_dummy_parameter));
        _2073[4] = r_depth_tp1.Load(int3(clamp(int2(floor(_2245 * float2(_3779))) + int2(-1, 0), int2(0, 0), _3779 - int2(1, 1)), 0)).x;
        uint _3804_dummy_parameter;
        int2 _3804 = int2(spvTextureSize(r_depth_tp1, uint(0), _3804_dummy_parameter));
        _2073[5] = r_depth_tp1.Load(int3(clamp(int2(floor(_2245 * float2(_3804))) + int2(-1, 1), int2(0, 0), _3804 - int2(1, 1)), 0)).x;
        uint _3829_dummy_parameter;
        int2 _3829 = int2(spvTextureSize(r_depth_tp1, uint(0), _3829_dummy_parameter));
        _2073[6] = r_depth_tp1.Load(int3(clamp(int2(floor(_2245 * float2(_3829))) + int2(1, 1), int2(0, 0), _3829 - int2(1, 1)), 0)).x;
        uint _3854_dummy_parameter;
        int2 _3854 = int2(spvTextureSize(r_depth_tp1, uint(0), _3854_dummy_parameter));
        _2073[7] = r_depth_tp1.Load(int3(clamp(int2(floor(_2245 * float2(_3854))) + int2(-1, -1), int2(0, 0), _3854 - int2(1, 1)), 0)).x;
        uint _3879_dummy_parameter;
        int2 _3879 = int2(spvTextureSize(r_depth_tp1, uint(0), _3879_dummy_parameter));
        _2073[8] = r_depth_tp1.Load(int3(clamp(int2(floor(_2245 * float2(_3879))) + int2(1, -1), int2(0, 0), _3879 - int2(1, 1)), 0)).x;
        int _5348;
        _5348 = 0;
        float _5453;
        int _5454;
        int _5347 = 1;
        float _5429 = _2073[0];
        for (; _5347 < 9; _5429 = _5453, _5348 = _5454, _5347++)
        {
            bool _2426 = _2073[_5347] < _5429;
            _5453 = _2426 ? _2073[_5347] : _5429;
            _5454 = _2426 ? _5347 : _5348;
        }
        uint _3904_dummy_parameter;
        int2 _3904 = int2(spvTextureSize(r_motion_tp1, uint(0), _3904_dummy_parameter));
        float2 _3922 = r_motion_tp1.Load(int3(clamp(int2(floor(_2245 * float2(_3904))) + _1536[_5348], int2(0, 0), _3904 - int2(1, 1)), 0)).xy * cbFI_MotionVectorScale;
        float2 _5349;
        do
        {
            if (_2969)
            {
                _5349 = _3922;
                break;
            }
            float2 _3946 = _2245 + _3922;
            float _3982 = ((2.0f * _3946.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4031 = clamp((((_5289 + (((float2(atan(_3982) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _3946.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_3982 * _3982))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5289) * _2269)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4034 = tan(_4031.x);
            _5349 = (((float2(_4034 / cbFI_DeviceToViewDepth.z, (tan(_4031.y) * sqrt(1.0f + (_4034 * _4034))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2245) / max(_2269, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        rw_mv_holes_tp1[_1947 + int2(floor((_5349 * _3110) * _2269))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        rw_mv_holes_tm1[_1947 + int2(floor(_3922 * _3110))] = float4(1.0f, 0.0f, 0.0f, 0.0f).x;
        uint _4104_dummy_parameter;
        float4 _4111 = r_depth_tm1.Load(int3(int2(floor(_2245 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4104_dummy_parameter))))), 0));
        float _4112 = _4111.x;
        float4 _4142 = mul(float4(_2840, _2838.y, _4112, 1.0f), cbFI_MotionTM1ToTP1);
        float _4144 = _4142.w;
        float2 _4158 = _2834 - (((_4142.xy / _4144.xx) + 1.0f.xx) * 0.5f);
        float2 _4160 = abs(_4158);
        bool2 _4166 = all(bool2(_4160.x < 9.9999997473787516355514526367188e-06f.xx.x, _4160.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
        float2 _4167 = float2(_4166.x ? 0.0f.xx.x : _4158.x, _4166.y ? 0.0f.xx.y : _4158.y);
        bool2 _4172 = any(isnan(_4167)).xx;
        float2 _4173 = float2(_4172.x ? 0.0f.xx.x : _4167.x, _4172.y ? 0.0f.xx.y : _4167.y);
        bool2 _4178 = any(isinf(_4173)).xx;
        float2 _4179 = float2(_4178.x ? 0.0f.xx.x : _4173.x, _4178.y ? 0.0f.xx.y : _4173.y);
        float2 _4185 = float2(-_4179.x, _4179.y);
        float2 _2467 = float2(-_2882.x, _2882.y) * _3110;
        float2 _2471 = _2942 * _3110;
        float2 _4240 = _2467 * 16.0146636962890625f;
        float2 _4250 = float2(int2(clamp(sign(_4240) * ceil(abs(_4240)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float2 _4266 = _2471 * 16.0146636962890625f;
        float2 _4276 = float2(int2(clamp(sign(_4266) * ceil(abs(_4266)), (-1023.0f).xx, 1023.0f.xx))) * 0.062442772090435028076171875f.xx;
        float _5350;
        if (max(max(length(_4250), length(_4276)), cbFI_MvSimilarityThresholds.y) < cbFI_MvSimilarityThresholds.y)
        {
            _5350 = 0.0f;
        }
        else
        {
            _5350 = float(length(_4250 - _4276) >= cbFI_MvSimilarityThresholds.x);
        }
        uint _2476 = uint(_5350 > 0.0f);
        float _2488 = length(_2471);
        if (_2488 > 4.0f)
        {
            if (_2952)
            {
                uint _4293;
                rw_nfru_diagnostics.InterlockedAdd(72, 1u, _4293);
            }
        }
        bool _2500 = ((cbFI_pad0 & 2048u) != 0u) && (_2476 != 0u);
        bool _2512;
        if (_2500)
        {
            _2512 = length(_2467 - _2471) < (0.07999999821186065673828125f * max(length(_2467), _2488));
        }
        else
        {
            _2512 = _2500;
        }
        bool _2518 = (cbFI_NfruT2Flags & 2048u) != 0u;
        bool _2526;
        if (_2518)
        {
            _2526 = length(_2467 - _2471) > 2.0f;
        }
        else
        {
            _2526 = _2518;
        }
        uint _5456 = _2526 ? 1u : (_2512 ? 0u : _2476);
        rw_dynamic_mask_tp1[_1947] = float4(clamp(float(_5456 + uint(_2849)), 0.0f, 1.0f), 0.0f, 0.0f, 1.0f).x;
        if (_5456 != 0u)
        {
            if (_2952)
            {
                uint _4312;
                rw_nfru_diagnostics.InterlockedAdd(60, 1u, _4312);
            }
        }
        if (_2849 > 0.0f)
        {
            if (_2952)
            {
                uint _4322;
                rw_nfru_diagnostics.InterlockedAdd(64, 1u, _4322);
            }
        }
        if ((cbFI_NfruT2Flags & 512u) != 0u)
        {
            break;
        }
        bool _2554 = (cbFI_NfruT2Flags & 1024u) != 0u;
        bool _2560;
        if (_2554)
        {
            _2560 = (1.0f - (log(((_4112 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f)) < 0.300000011920928955078125f;
        }
        else
        {
            _2560 = _2554;
        }
        if (_2560)
        {
            break;
        }
        if ((uint(r_dynamic_mask_tm1.Load(int3(_1947, 0)).x) + uint(float(_4144 < 0.0f))) > 0u)
        {
            if (_2952)
            {
                uint _4342;
                rw_nfru_diagnostics.InterlockedAdd(68, 1u, _4342);
            }
            break;
        }
        float _4375 = 1.0f - (log(((_4112 - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _5369;
        if (_4375 == 1.0f)
        {
            _5369 = _4375 + ((float(_2232) * _2239) * 0.100000001490116119384765625f);
        }
        else
        {
            _5369 = _4375;
        }
        float _4365 = 1.10000002384185791015625f - _5369;
        float2 _5370;
        float2 _5371;
        do
        {
            if (_2969)
            {
                _5371 = _4185;
                _5370 = _4185;
                break;
            }
            float2 _4394 = _2245 + _4185;
            float _4430 = ((2.0f * _4394.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
            float2 _4397 = (float2(atan(_4430) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _4394.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_4430 * _4430))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) - _5289;
            float2 _4479 = clamp((((_5289 + (_4397 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
            float _4482 = tan(_4479.x);
            _5371 = _4397;
            _5370 = (((float2(_4482 / cbFI_DeviceToViewDepth.z, (tan(_4479.y) * sqrt(1.0f + (_4482 * _4482))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx) - _2245) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
            break;
        } while(false);
        bool _5373;
        int2 _5374;
        uint _5382;
        do
        {
            float2 _4529 = _5370 * _3110;
            float2 _4533 = _5371 * _3110;
            bool _4536 = any(isnan(_4529));
            bool _4543;
            if (!_4536)
            {
                _4543 = any(isinf(_4529));
            }
            else
            {
                _4543 = _4536;
            }
            bool _4550;
            if (!_4543)
            {
                _4550 = any(isnan(_4533));
            }
            else
            {
                _4550 = _4543;
            }
            bool _4557;
            if (!_4550)
            {
                _4557 = any(isinf(_4533));
            }
            else
            {
                _4557 = _4550;
            }
            bool _4563;
            if (!_4557)
            {
                _4563 = isnan(_4365);
            }
            else
            {
                _4563 = _4557;
            }
            bool _4569;
            if (!_4563)
            {
                _4569 = isinf(_4365);
            }
            else
            {
                _4569 = _4563;
            }
            if (_4569)
            {
                _5382 = 0u;
                _5374 = int2(0, 0);
                _5373 = false;
                break;
            }
            float2 _4574 = _4529 * cbFI_Timestep;
            bool _4577 = any(isnan(_4574));
            bool _4584;
            if (!_4577)
            {
                _4584 = any(isinf(_4574));
            }
            else
            {
                _4584 = _4577;
            }
            if (_4584)
            {
                _5382 = 0u;
                _5374 = int2(0, 0);
                _5373 = false;
                break;
            }
            float2 _4591 = _2241 + floor(_4574);
            bool _4594 = any(bool2(_4591.x < 0.0f.xx.x, _4591.y < 0.0f.xx.y));
            bool _4603;
            if (!_4594)
            {
                _4603 = any(bool2(_4591.x >= _3110.x, _4591.y >= _3110.y));
            }
            else
            {
                _4603 = _4594;
            }
            if (_4603)
            {
                _5382 = 0u;
                _5374 = int2(0, 0);
                _5373 = false;
                break;
            }
            float2 _4610 = _4533 * (-1.0f);
            float _4657 = _4610.x * 16.0146636962890625f;
            int _4665 = int(clamp(sign(_4657) * ceil(abs(_4657)), -16383.0f, 16383.0f));
            float _4669 = _4610.y * 16.0146636962890625f;
            int _4677 = int(clamp(sign(_4669) * ceil(abs(_4669)), -16383.0f, 16383.0f));
            int _4684 = abs(_4665);
            int _4686 = abs(_4677);
            int _4690 = clamp(firstbithigh(max(_4684, _4686)), 0, 15);
            int _4693 = max((_4690 - 6), 0);
            _5382 = (((((uint((int(round(_4365 * 1860.9090576171875f)) & 2047) << 20) | uint((_4690 & 15) << 16)) | uint(int(_4665 < 0) << 15)) | uint(int(_4677 < 0) << 14)) | uint((clamp(_4684 >> _4693, 0, 127) & 127) << 7)) | uint(clamp(_4686 >> _4693, 0, 127) & 127)) & 2147483647u;
            _5374 = int2(_4591);
            _5373 = true;
            break;
        } while(false);
        if (_5373)
        {
            uint _4775;
            InterlockedMax(rw_warped_motion_qdata_tp1[_5374], _5382, _4775);
            if ((cbFI_pad0 & 4096u) != 0u)
            {
                for (int _5390 = 0; _5390 < 3; _5390++)
                {
                    int2 _2609 = _5374 + _1322[_5390];
                    if (all(bool2(_2609.x < cbFI_MvDepthLaneSize.x, _2609.y < cbFI_MvDepthLaneSize.y)))
                    {
                        uint _4780;
                        InterlockedMax(rw_warped_motion_qdata_tp1[_2609], _5382, _4780);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _2631 = _2245 + float2(cbFI_MvDepthLaneSizeRcp.x, 0.0f);
                float2 _2636 = _2245 + float2(0.0f, cbFI_MvDepthLaneSizeRcp.y);
                uint _4797_dummy_parameter;
                float4 _4804 = r_depth_tm1.Load(int3(int2(floor(_2245 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4797_dummy_parameter))))), 0));
                float _4805 = _4804.x;
                uint _4813_dummy_parameter;
                float4 _4820 = r_depth_tm1.Load(int3(int2(floor(_2631 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4813_dummy_parameter))))), 0));
                float _4821 = _4820.x;
                uint _4829_dummy_parameter;
                float4 _4836 = r_depth_tm1.Load(int3(int2(floor(_2636 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _4829_dummy_parameter))))), 0));
                float _4837 = _4836.x;
                float _4852 = _2631.x;
                float2 _4856 = float2(_4852, 1.0f - _2631.y);
                float4 _4867 = mul(float4((_4856 * 2.0f) - 1.0f.xx, _4821, 1.0f), cbFI_MotionTM1ToTP1);
                float _4869 = _4867.w;
                float2 _4883 = _4856 - (((_4867.xy / _4869.xx) + 1.0f.xx) * 0.5f);
                float2 _4885 = abs(_4883);
                bool2 _4891 = all(bool2(_4885.x < 9.9999997473787516355514526367188e-06f.xx.x, _4885.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4892 = float2(_4891.x ? 0.0f.xx.x : _4883.x, _4891.y ? 0.0f.xx.y : _4883.y);
                bool2 _4897 = any(isnan(_4892)).xx;
                float2 _4898 = float2(_4897.x ? 0.0f.xx.x : _4892.x, _4897.y ? 0.0f.xx.y : _4892.y);
                bool2 _4903 = any(isinf(_4898)).xx;
                float2 _4904 = float2(_4903.x ? 0.0f.xx.x : _4898.x, _4903.y ? 0.0f.xx.y : _4898.y);
                float _4926 = _2636.y;
                float2 _4928 = float2(_2636.x, 1.0f - _4926);
                float4 _4939 = mul(float4((_4928 * 2.0f) - 1.0f.xx, _4837, 1.0f), cbFI_MotionTM1ToTP1);
                float _4941 = _4939.w;
                float2 _4955 = _4928 - (((_4939.xy / _4941.xx) + 1.0f.xx) * 0.5f);
                float2 _4957 = abs(_4955);
                bool2 _4963 = all(bool2(_4957.x < 9.9999997473787516355514526367188e-06f.xx.x, _4957.y < 9.9999997473787516355514526367188e-06f.xx.y)).xx;
                float2 _4964 = float2(_4963.x ? 0.0f.xx.x : _4955.x, _4963.y ? 0.0f.xx.y : _4955.y);
                bool2 _4969 = any(isnan(_4964)).xx;
                float2 _4970 = float2(_4969.x ? 0.0f.xx.x : _4964.x, _4969.y ? 0.0f.xx.y : _4964.y);
                bool2 _4975 = any(isinf(_4970)).xx;
                float2 _4976 = float2(_4975.x ? 0.0f.xx.x : _4970.x, _4975.y ? 0.0f.xx.y : _4970.y);
                bool _2658 = (_4852 < 1.0f) && (float(_4869 < 0.0f) == 0.0f);
                bool _2664;
                if (_2658)
                {
                    _2664 = abs(_4805 - _4821) <= ((0.0500000007450580596923828125f * max(abs(_4805), abs(_4821))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2664 = _2658;
                }
                bool _2670 = (_4926 < 1.0f) && (float(_4941 < 0.0f) == 0.0f);
                bool _2676;
                if (_2670)
                {
                    _2676 = abs(_4805 - _4837) <= ((0.0500000007450580596923828125f * max(abs(_4805), abs(_4837))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _2676 = _2670;
                }
                float2 _5024 = (_2245 + (_4185 * cbFI_Timestep)) * _3110;
                float2 _5391;
                if (_2664)
                {
                    _5391 = ((_2631 + (float2(-_4904.x, _4904.y) * cbFI_Timestep)) * _3110) - _5024;
                }
                else
                {
                    _5391 = float2(1.0f, 0.0f);
                }
                float2 _5392;
                if (_2676)
                {
                    _5392 = ((_2636 + (float2(-_4976.x, _4976.y) * cbFI_Timestep)) * _3110) - _5024;
                }
                else
                {
                    _5392 = float2(0.0f, 1.0f);
                }
                bool _5078 = any(isnan(_5391));
                bool _5085;
                if (!_5078)
                {
                    _5085 = any(isinf(_5391));
                }
                else
                {
                    _5085 = _5078;
                }
                bool2 _5457 = _5085.xx;
                float2 _5458 = float2(_5457.x ? float2(1.0f, 0.0f).x : _5391.x, _5457.y ? float2(1.0f, 0.0f).y : _5391.y);
                bool _5090 = any(isnan(_5392));
                bool _5097;
                if (!_5090)
                {
                    _5097 = any(isinf(_5392));
                }
                else
                {
                    _5097 = _5090;
                }
                bool2 _5459 = _5097.xx;
                float2 _5460 = float2(_5459.x ? float2(0.0f, 1.0f).x : _5392.x, _5459.y ? float2(0.0f, 1.0f).y : _5392.y);
                int2 _5113 = int2(clamp(floor(min(0.0f.xx, _5458) + min(0.0f.xx, _5460)), (-3.0f).xx, 0.0f.xx));
                int2 _5119 = int2(clamp(ceil(max(0.0f.xx, _5458) + max(0.0f.xx, _5460)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _5127 = _5113.y;
                for (int _5422 = _5127; _5422 <= _5119.y; _5422++)
                {
                    int _5136 = _5113.x;
                    for (int _5423 = _5136; _5423 <= _5119.x; _5423++)
                    {
                        if ((_5423 == 0) && (_5422 == 0))
                        {
                            continue;
                        }
                        int2 _5155 = _5374 + int2(_5423, _5422);
                        bool _5158 = all(bool2(_5155.x >= int2(0, 0).x, _5155.y >= int2(0, 0).y));
                        bool _5165;
                        if (_5158)
                        {
                            _5165 = all(bool2(_5155.x < cbFI_MvDepthLaneSize.x, _5155.y < cbFI_MvDepthLaneSize.y));
                        }
                        else
                        {
                            _5165 = _5158;
                        }
                        if (_5165)
                        {
                            uint _5183;
                            InterlockedMax(rw_warped_motion_qdata_tp1[_5155], _5382, _5183);
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
