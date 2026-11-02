static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _396[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _413[12] = { 2, 4, 7, 11, 16, 24, 36, 54, 80, 120, 180, 384 };

cbuffer cbFI_t : register(b2, space0)
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

RWByteAddressBuffer rw_nfru_diagnostics : register(u3, space0);
Texture2D<uint4> r_warped_flow_qdata_tm1 : register(t0, space0);
RWTexture2D<float2> rw_warped_filled_flow_tm1 : register(u1, space0);

static uint3 gl_GlobalInvocationID;
struct SPIRV_Cross_Input
{
    uint3 gl_GlobalInvocationID : SV_DispatchThreadID;
};

static float2 nfruWalkAvgMotion;

void comp_main()
{
    int2 _582 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_582.x >= cbFI_FlowLaneSize.x, _582.y >= cbFI_FlowLaneSize.y)))
        {
            break;
        }
        nfruWalkAvgMotion = 1000000015047466219876688855040.0f.xx;
        uint _641[9];
        _641[0] = r_warped_flow_qdata_tm1.Load(int3(_582, 0)).x;
        _641[1] = r_warped_flow_qdata_tm1.Load(int3(_582 + int2(1, 0), 0)).x;
        _641[2] = r_warped_flow_qdata_tm1.Load(int3(_582 + int2(0, 1), 0)).x;
        _641[3] = r_warped_flow_qdata_tm1.Load(int3(_582 + int2(0, -1), 0)).x;
        _641[4] = r_warped_flow_qdata_tm1.Load(int3(_582 + int2(-1, 0), 0)).x;
        _641[5] = r_warped_flow_qdata_tm1.Load(int3(_582 + int2(-1, 1), 0)).x;
        _641[6] = r_warped_flow_qdata_tm1.Load(int3(_582 + int2(1, 1), 0)).x;
        _641[7] = r_warped_flow_qdata_tm1.Load(int3(_582 + int2(-1, -1), 0)).x;
        _641[8] = r_warped_flow_qdata_tm1.Load(int3(_582 + int2(1, -1), 0)).x;
        uint _1201;
        _1201 = _641[0];
        uint _1245;
        for (int _1200 = 1; _1200 < 9; _1201 = _1245, _1200++)
        {
            _1245 = (_641[_1200] > _1201) ? _641[_1200] : _1201;
        }
        bool _734 = _1201 == 0u;
        bool _741;
        if (_734)
        {
            _741 = (cbFI_pad0 & 536870912u) != 0u;
        }
        else
        {
            _741 = _734;
        }
        uint _1209;
        if (_741)
        {
            int _747 = ((cbFI_NfruT2Flags & 1048576u) != 0u) ? 12 : 5;
            uint _1203;
            _1203 = 4294967295u;
            uint _657[8];
            uint _1235;
            for (int _1202 = 0; _1202 < 8; _1203 = _1235, _1202++)
            {
                _657[_1202] = 0u;
                int _1226 = 0;
                for (;;)
                {
                    if (_1226 < _747)
                    {
                        int2 _770 = _582 + (_396[_1202] * _413[_1226].xx);
                        bool _773 = any(bool2(_770.x < int2(0, 0).x, _770.y < int2(0, 0).y));
                        bool _781;
                        if (!_773)
                        {
                            _781 = any(bool2(_770.x >= cbFI_FlowLaneSize.x, _770.y >= cbFI_FlowLaneSize.y));
                        }
                        else
                        {
                            _781 = _773;
                        }
                        if (_781)
                        {
                            _1235 = _1203;
                            break;
                        }
                        uint4 _994 = r_warped_flow_qdata_tm1.Load(int3(_770, 0));
                        uint _995 = _994.x;
                        if (_995 != 0u)
                        {
                            _657[_1202] = _995;
                            _1235 = min(_1203, _995);
                            break;
                        }
                        _1226++;
                        continue;
                    }
                    else
                    {
                        _1235 = _1203;
                        break;
                    }
                }
            }
            bool _805 = _1203 != 4294967295u;
            if (_805)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _1004;
                    rw_nfru_diagnostics.InterlockedAdd(252, 1u, _1004);
                }
            }
            bool _818;
            if (_805)
            {
                _818 = (cbFI_NfruT2Flags & 131072u) != 0u;
            }
            else
            {
                _818 = _805;
            }
            if (_818)
            {
                float _1207;
                float2 _1208;
                _1208 = 0.0f.xx;
                _1207 = 0.0f;
                float _1236;
                float2 _1237;
                for (int _1206 = 0; _1206 < 8; _1208 = _1237, _1207 = _1236, _1206++)
                {
                    bool _828 = _657[_1206] != 0u;
                    bool _841;
                    if (_828)
                    {
                        _841 = ((_657[_1206] >> 20u) & 2047u) <= (((_1203 >> 20u) & 2047u) + 55u);
                    }
                    else
                    {
                        _841 = _828;
                    }
                    if (_841)
                    {
                        uint _1021 = _657[_1206] & 2147483647u;
                        uint _1053 = uint(max((int((_1021 >> 16u) & 15u) - 6), 0));
                        _1237 = _1208 + (float2(float((1 - (2 * int((_1021 >> 15u) & 1u))) * int(((_1021 >> uint(7)) & 127u) << _1053)), float((1 - (2 * int((_1021 >> 14u) & 1u))) * int((_1021 & 127u) << _1053))) * 0.0624427758157253265380859375f);
                        _1236 = _1207 + 1.0f;
                    }
                    else
                    {
                        _1237 = _1208;
                        _1236 = _1207;
                    }
                }
                if (_1207 > 0.0f)
                {
                    nfruWalkAvgMotion = _1208 / _1207.xx;
                }
            }
            _1209 = _805 ? _1203 : _1201;
        }
        else
        {
            _1209 = _1201;
        }
        if ((cbFI_pad0 & 1024u) != 0u)
        {
            rw_nfru_diagnostics.Store<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_582.y * cbFI_FlowLaneSize.x) + _582.x)) * 4 + 0, uint(_1209 != 0u));
        }
        float2 _1219;
        if (nfruWalkAvgMotion.x < 100000001504746621987668885504.0f)
        {
            _1219 = nfruWalkAvgMotion;
        }
        else
        {
            uint _1133 = _1209 & 2147483647u;
            uint _1165 = uint(max((int((_1133 >> 16u) & 15u) - 6), 0));
            _1219 = float2(float((1 - (2 * int((_1133 >> 15u) & 1u))) * int(((_1133 >> uint(7)) & 127u) << _1165)), float((1 - (2 * int((_1133 >> 14u) & 1u))) * int((_1133 & 127u) << _1165))) * 0.0624427758157253265380859375f;
        }
        rw_warped_filled_flow_tm1[_582] = float4(_1219 * cbFI_FlowLaneSizeRcp, 0.0f, 0.0f).xy;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
