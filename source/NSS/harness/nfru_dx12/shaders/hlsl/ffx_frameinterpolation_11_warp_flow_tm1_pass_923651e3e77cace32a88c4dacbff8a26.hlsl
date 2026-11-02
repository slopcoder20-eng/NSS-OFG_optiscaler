static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _905[3] = { int2(1, 0), int2(0, 1), int2(1, 1) };

cbuffer cbFI_t : register(b3, space0)
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

Texture2D<float4> r_flow_tm1 : register(t0, space0);
Texture2D<float4> r_depth_tm1 : register(t1, space0);
RWTexture2D<uint> rw_warped_flow_qdata_tm1 : register(u2, space0);

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
    int2 _1109 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_1109.x >= cbFI_FlowLaneSize.x, _1109.y >= cbFI_FlowLaneSize.y)))
        {
            break;
        }
        float2 _1243 = float2(_1109);
        float2 _1255 = (_1243 + 0.5f.xx) * float2(1.0f / float(cbFI_FlowLaneSize.x), 1.0f / float(cbFI_FlowLaneSize.y));
        uint _1491_dummy_parameter;
        float _1532 = 1.0f - (log(((r_depth_tm1.Load(int3(int2(floor(_1255 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _1491_dummy_parameter))))), 0)).x - 1.0f) * (-1200.0f)) + 1.0f) * 0.14102561771869659423828125f);
        float _2399;
        if (_1532 == 1.0f)
        {
            _2399 = _1532 + ((float(_1109.x + (_1109.y * cbFI_FlowLaneSize.x)) * (cbFI_FlowLaneSizeRcp.x * cbFI_FlowLaneSizeRcp.y)) * 0.100000001490116119384765625f);
        }
        else
        {
            _2399 = _1532;
        }
        float _1522 = 1.10000002384185791015625f - _2399;
        uint _1539_dummy_parameter;
        precise float2 _1549 = r_flow_tm1.Load(int3(int2(floor(_1255 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _1539_dummy_parameter))))), 0)).xy * cbFI_OfSizeRcp;
        precise float2 _1551 = _1549 * cbFI_OfGridSizeRcp;
        bool _1566 = (cbFI_pad0 & 1073741824u) != 0u;
        float2 _2402;
        float2 _2403;
        if (_1566)
        {
            float2 _1270 = _1255 + _1551;
            float2 _2400;
            if (_1566)
            {
                float _1603 = ((2.0f * _1270.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                float _1615 = 2.0f * cbFI_DeviceToViewDepth.z;
                float _1627 = 2.0f * cbFI_DeviceToViewDepth.w;
                float _1651 = ((2.0f * _1255.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                _2400 = (float2(atan(_1603) / _1615, atan((((2.0f * _1270.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_1603 * _1603))) / _1627) + 0.5f.xx) - (float2(atan(_1651) / _1615, atan((((2.0f * _1255.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_1651 * _1651))) / _1627) + 0.5f.xx);
            }
            else
            {
                _2400 = _1270 - _1255;
            }
            float2 _2401;
            if (_1566)
            {
                float _1731 = ((2.0f * _1255.x) - 1.0f) * cbFI_DeviceToViewDepth.z;
                float2 _1780 = clamp(((((float2(atan(_1731) / (2.0f * cbFI_DeviceToViewDepth.z), atan((((2.0f * _1255.y) - 1.0f) * cbFI_DeviceToViewDepth.w) / sqrt(1.0f + (_1731 * _1731))) / (2.0f * cbFI_DeviceToViewDepth.w)) + 0.5f.xx) + (_2400 * cbFI_Timestep)) - 0.5f.xx) * 2.0f) * float2(cbFI_DeviceToViewDepth.z, cbFI_DeviceToViewDepth.w), (-1.5499999523162841796875f).xx, 1.5499999523162841796875f.xx);
                float _1783 = tan(_1780.x);
                _2401 = (float2(_1783 / cbFI_DeviceToViewDepth.z, (tan(_1780.y) * sqrt(1.0f + (_1783 * _1783))) / cbFI_DeviceToViewDepth.w) * 0.5f) + 0.5f.xx;
            }
            else
            {
                _2401 = _1255 + (_2400 * cbFI_Timestep);
            }
            _2403 = _2400;
            _2402 = (_2401 - _1255) / max(cbFI_Timestep, 9.9999997473787516355514526367188e-05f).xx;
        }
        else
        {
            _2403 = _1551;
            _2402 = _1551;
        }
        float2 _1833;
        float2 _1834;
        bool _2407;
        int2 _2408;
        uint _2416;
        do
        {
            _1833 = float2(cbFI_FlowLaneSize);
            _1834 = _2402 * _1833;
            float2 _1838 = _2403 * _1833;
            bool _1841 = any(isnan(_1834));
            bool _1848;
            if (!_1841)
            {
                _1848 = any(isinf(_1834));
            }
            else
            {
                _1848 = _1841;
            }
            bool _1855;
            if (!_1848)
            {
                _1855 = any(isnan(_1838));
            }
            else
            {
                _1855 = _1848;
            }
            bool _1862;
            if (!_1855)
            {
                _1862 = any(isinf(_1838));
            }
            else
            {
                _1862 = _1855;
            }
            bool _1868;
            if (!_1862)
            {
                _1868 = isnan(_1522);
            }
            else
            {
                _1868 = _1862;
            }
            bool _1874;
            if (!_1868)
            {
                _1874 = isinf(_1522);
            }
            else
            {
                _1874 = _1868;
            }
            if (_1874)
            {
                _2416 = 0u;
                _2408 = int2(0, 0);
                _2407 = false;
                break;
            }
            float2 _1879 = _1834 * cbFI_Timestep;
            bool _1882 = any(isnan(_1879));
            bool _1889;
            if (!_1882)
            {
                _1889 = any(isinf(_1879));
            }
            else
            {
                _1889 = _1882;
            }
            if (_1889)
            {
                _2416 = 0u;
                _2408 = int2(0, 0);
                _2407 = false;
                break;
            }
            float2 _1896 = _1243 + floor(_1879);
            bool _1899 = any(bool2(_1896.x < 0.0f.xx.x, _1896.y < 0.0f.xx.y));
            bool _1908;
            if (!_1899)
            {
                _1908 = any(bool2(_1896.x >= _1833.x, _1896.y >= _1833.y));
            }
            else
            {
                _1908 = _1899;
            }
            if (_1908)
            {
                _2416 = 0u;
                _2408 = int2(0, 0);
                _2407 = false;
                break;
            }
            float2 _1915 = _1838 * 1.0f;
            float _1962 = _1915.x * 16.0146636962890625f;
            int _1970 = int(clamp(sign(_1962) * ceil(abs(_1962)), -16383.0f, 16383.0f));
            float _1974 = _1915.y * 16.0146636962890625f;
            int _1982 = int(clamp(sign(_1974) * ceil(abs(_1974)), -16383.0f, 16383.0f));
            int _1989 = abs(_1970);
            int _1991 = abs(_1982);
            int _1995 = clamp(firstbithigh(max(_1989, _1991)), 0, 15);
            int _1998 = max((_1995 - 6), 0);
            _2416 = (((((uint((int(round(_1522 * 1860.9090576171875f)) & 2047) << 20) | uint((_1995 & 15) << 16)) | uint(int(_1970 < 0) << 15)) | uint(int(_1982 < 0) << 14)) | uint((clamp(_1989 >> _1998, 0, 127) & 127) << 7)) | uint(clamp(_1991 >> _1998, 0, 127) & 127)) & 2147483647u;
            _2408 = int2(_1896);
            _2407 = true;
            break;
        } while(false);
        if (_2407)
        {
            uint _2080;
            InterlockedMax(rw_warped_flow_qdata_tm1[_2408], _2416, _2080);
            if ((cbFI_pad0 & 8192u) != 0u)
            {
                float2 _1309 = frac(_1834 * cbFI_Timestep);
                bool _1313 = (cbFI_pad0 & 16384u) != 0u;
                for (int _2432 = 0; _2432 < 3; _2432++)
                {
                    bool _1346;
                    if (_1313)
                    {
                        bool _1324 = _905[_2432].x != 0;
                        bool _1330;
                        if (_1324)
                        {
                            _1330 = _1309.x <= 0.001000000047497451305389404296875f;
                        }
                        else
                        {
                            _1330 = _1324;
                        }
                        bool _1344;
                        if (!_1330)
                        {
                            bool _1336 = _905[_2432].y != 0;
                            bool _1342;
                            if (_1336)
                            {
                                _1342 = _1309.y <= 0.001000000047497451305389404296875f;
                            }
                            else
                            {
                                _1342 = _1336;
                            }
                            _1344 = _1342;
                        }
                        else
                        {
                            _1344 = _1330;
                        }
                        _1346 = _1344;
                    }
                    else
                    {
                        _1346 = _1313;
                    }
                    if (_1346)
                    {
                        continue;
                    }
                    int2 _1353 = _2408 + _905[_2432];
                    if (all(bool2(_1353.x < cbFI_FlowLaneSize.x, _1353.y < cbFI_FlowLaneSize.y)))
                    {
                        uint _2089;
                        InterlockedMax(rw_warped_flow_qdata_tm1[_1353], _2416, _2089);
                    }
                }
            }
            if ((cbFI_pad0 & 2147483648u) != 0u)
            {
                float2 _1374 = _1255 + float2(cbFI_FlowLaneSizeRcp.x, 0.0f);
                float2 _1379 = _1255 + float2(0.0f, cbFI_FlowLaneSizeRcp.y);
                uint _2102_dummy_parameter;
                float4 _2109 = r_depth_tm1.Load(int3(int2(floor(_1255 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _2102_dummy_parameter))))), 0));
                float _2110 = _2109.x;
                bool _1384 = _1374.x < 1.0f;
                bool _1391;
                if (_1384)
                {
                    uint _2118_dummy_parameter;
                    float4 _2125 = r_depth_tm1.Load(int3(int2(floor(_1374 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _2118_dummy_parameter))))), 0));
                    float _2126 = _2125.x;
                    _1391 = abs(_2110 - _2126) <= ((0.0500000007450580596923828125f * max(abs(_2110), abs(_2126))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _1391 = _1384;
                }
                bool _1394 = _1379.y < 1.0f;
                bool _1401;
                if (_1394)
                {
                    uint _2148_dummy_parameter;
                    float4 _2155 = r_depth_tm1.Load(int3(int2(floor(_1379 * float2(int2(spvTextureSize(r_depth_tm1, uint(0), _2148_dummy_parameter))))), 0));
                    float _2156 = _2155.x;
                    _1401 = abs(_2110 - _2156) <= ((0.0500000007450580596923828125f * max(abs(_2110), abs(_2156))) + 1.0000000116860974230803549289703e-07f);
                }
                else
                {
                    _1401 = _1394;
                }
                float2 _2181 = (_1255 + (_1551 * cbFI_Timestep)) * _1833;
                uint _2192_dummy_parameter;
                precise float2 _2202 = r_flow_tm1.Load(int3(int2(floor(_1374 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _2192_dummy_parameter))))), 0)).xy * cbFI_OfSizeRcp;
                precise float2 _2204 = _2202 * cbFI_OfGridSizeRcp;
                uint _2234_dummy_parameter;
                precise float2 _2244 = r_flow_tm1.Load(int3(int2(floor(_1379 * float2(int2(spvTextureSize(r_flow_tm1, uint(0), _2234_dummy_parameter))))), 0)).xy * cbFI_OfSizeRcp;
                precise float2 _2246 = _2244 * cbFI_OfGridSizeRcp;
                float2 _2433;
                if (_1391)
                {
                    _2433 = ((_1374 + (_2204 * cbFI_Timestep)) * _1833) - _2181;
                }
                else
                {
                    _2433 = float2(1.0f, 0.0f);
                }
                float2 _2434;
                if (_1401)
                {
                    _2434 = ((_1379 + (_2246 * cbFI_Timestep)) * _1833) - _2181;
                }
                else
                {
                    _2434 = float2(0.0f, 1.0f);
                }
                bool _2295 = any(isnan(_2433));
                bool _2302;
                if (!_2295)
                {
                    _2302 = any(isinf(_2433));
                }
                else
                {
                    _2302 = _2295;
                }
                bool2 _2459 = _2302.xx;
                float2 _2460 = float2(_2459.x ? float2(1.0f, 0.0f).x : _2433.x, _2459.y ? float2(1.0f, 0.0f).y : _2433.y);
                bool _2307 = any(isnan(_2434));
                bool _2314;
                if (!_2307)
                {
                    _2314 = any(isinf(_2434));
                }
                else
                {
                    _2314 = _2307;
                }
                bool2 _2461 = _2314.xx;
                float2 _2462 = float2(_2461.x ? float2(0.0f, 1.0f).x : _2434.x, _2461.y ? float2(0.0f, 1.0f).y : _2434.y);
                int2 _2330 = int2(clamp(floor(min(0.0f.xx, _2460) + min(0.0f.xx, _2462)), (-3.0f).xx, 0.0f.xx));
                int2 _2336 = int2(clamp(ceil(max(0.0f.xx, _2460) + max(0.0f.xx, _2462)) - 1.0f.xx, 0.0f.xx, 3.0f.xx));
                int _1422 = _2330.y;
                for (int _2444 = _1422; _2444 <= _2336.y; _2444++)
                {
                    int _1431 = _2330.x;
                    for (int _2445 = _1431; _2445 <= _2336.x; _2445++)
                    {
                        if ((_2445 == 0) && (_2444 == 0))
                        {
                            continue;
                        }
                        int2 _1450 = _2408 + int2(_2445, _2444);
                        bool _1453 = all(bool2(_1450.x >= int2(0, 0).x, _1450.y >= int2(0, 0).y));
                        bool _1460;
                        if (_1453)
                        {
                            _1460 = all(bool2(_1450.x < cbFI_FlowLaneSize.x, _1450.y < cbFI_FlowLaneSize.y));
                        }
                        else
                        {
                            _1460 = _1453;
                        }
                        if (_1460)
                        {
                            uint _2341;
                            InterlockedMax(rw_warped_flow_qdata_tm1[_1450], _2416, _2341);
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
