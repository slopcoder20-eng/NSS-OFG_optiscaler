static const uint3 gl_WorkGroupSize = uint3(16u, 16u, 1u);

static const int2 _386[8] = { int2(1, 0), int2(-1, 0), int2(0, 1), int2(0, -1), int2(1, 1), int2(-1, 1), int2(1, -1), int2(-1, -1) };
static const int _396[5] = { 2, 4, 7, 11, 16 };

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
    int2 _566 = int2(gl_GlobalInvocationID.xy);
    do
    {
        if (any(bool2(_566.x >= cbFI_FlowLaneSize.x, _566.y >= cbFI_FlowLaneSize.y)))
        {
            break;
        }
        nfruWalkAvgMotion = 1000000015047466219876688855040.0f.xx;
        uint _624[9];
        _624[0] = r_warped_flow_qdata_tm1.Load(int3(_566, 0)).x;
        _624[1] = r_warped_flow_qdata_tm1.Load(int3(_566 + int2(1, 0), 0)).x;
        _624[2] = r_warped_flow_qdata_tm1.Load(int3(_566 + int2(0, 1), 0)).x;
        _624[3] = r_warped_flow_qdata_tm1.Load(int3(_566 + int2(0, -1), 0)).x;
        _624[4] = r_warped_flow_qdata_tm1.Load(int3(_566 + int2(-1, 0), 0)).x;
        _624[5] = r_warped_flow_qdata_tm1.Load(int3(_566 + int2(-1, 1), 0)).x;
        _624[6] = r_warped_flow_qdata_tm1.Load(int3(_566 + int2(1, 1), 0)).x;
        _624[7] = r_warped_flow_qdata_tm1.Load(int3(_566 + int2(-1, -1), 0)).x;
        _624[8] = r_warped_flow_qdata_tm1.Load(int3(_566 + int2(1, -1), 0)).x;
        uint _1177;
        _1177 = _624[0];
        uint _1221;
        for (int _1176 = 1; _1176 < 9; _1177 = _1221, _1176++)
        {
            _1221 = (_624[_1176] > _1177) ? _624[_1176] : _1177;
        }
        bool _716 = _1177 == 0u;
        bool _723;
        if (_716)
        {
            _723 = (cbFI_pad0 & 536870912u) != 0u;
        }
        else
        {
            _723 = _716;
        }
        uint _1185;
        if (_723)
        {
            uint _1179;
            _1179 = 4294967295u;
            uint _639[8];
            uint _1211;
            for (int _1178 = 0; _1178 < 8; _1179 = _1211, _1178++)
            {
                _639[_1178] = 0u;
                int _1202 = 0;
                for (;;)
                {
                    if (_1202 < 5)
                    {
                        int2 _746 = _566 + (_386[_1178] * _396[_1202].xx);
                        bool _749 = any(bool2(_746.x < int2(0, 0).x, _746.y < int2(0, 0).y));
                        bool _757;
                        if (!_749)
                        {
                            _757 = any(bool2(_746.x >= cbFI_FlowLaneSize.x, _746.y >= cbFI_FlowLaneSize.y));
                        }
                        else
                        {
                            _757 = _749;
                        }
                        if (_757)
                        {
                            _1211 = _1179;
                            break;
                        }
                        uint4 _970 = r_warped_flow_qdata_tm1.Load(int3(_746, 0));
                        uint _971 = _970.x;
                        if (_971 != 0u)
                        {
                            _639[_1178] = _971;
                            _1211 = min(_1179, _971);
                            break;
                        }
                        _1202++;
                        continue;
                    }
                    else
                    {
                        _1211 = _1179;
                        break;
                    }
                }
            }
            bool _781 = _1179 != 4294967295u;
            if (_781)
            {
                if ((cbFI_pad0 & 512u) != 0u)
                {
                    uint _980;
                    rw_nfru_diagnostics.InterlockedAdd(252, 1u, _980);
                }
            }
            bool _794;
            if (_781)
            {
                _794 = (cbFI_NfruT2Flags & 131072u) != 0u;
            }
            else
            {
                _794 = _781;
            }
            if (_794)
            {
                float _1183;
                float2 _1184;
                _1184 = 0.0f.xx;
                _1183 = 0.0f;
                float _1212;
                float2 _1213;
                for (int _1182 = 0; _1182 < 8; _1184 = _1213, _1183 = _1212, _1182++)
                {
                    bool _804 = _639[_1182] != 0u;
                    bool _817;
                    if (_804)
                    {
                        _817 = ((_639[_1182] >> 20u) & 2047u) <= (((_1179 >> 20u) & 2047u) + 55u);
                    }
                    else
                    {
                        _817 = _804;
                    }
                    if (_817)
                    {
                        uint _997 = _639[_1182] & 2147483647u;
                        uint _1029 = uint(max((int((_997 >> 16u) & 15u) - 6), 0));
                        _1213 = _1184 + (float2(float((1 - (2 * int((_997 >> 15u) & 1u))) * int(((_997 >> uint(7)) & 127u) << _1029)), float((1 - (2 * int((_997 >> 14u) & 1u))) * int((_997 & 127u) << _1029))) * 0.0624427758157253265380859375f);
                        _1212 = _1183 + 1.0f;
                    }
                    else
                    {
                        _1213 = _1184;
                        _1212 = _1183;
                    }
                }
                if (_1183 > 0.0f)
                {
                    nfruWalkAvgMotion = _1184 / _1183.xx;
                }
            }
            _1185 = _781 ? _1179 : _1177;
        }
        else
        {
            _1185 = _1177;
        }
        if ((cbFI_pad0 & 1024u) != 0u)
        {
            rw_nfru_diagnostics.Store<uint>(((64u + uint(cbFI_MvDepthLaneSize.x * cbFI_MvDepthLaneSize.y)) + uint((_566.y * cbFI_FlowLaneSize.x) + _566.x)) * 4 + 0, uint(_1185 != 0u));
        }
        float2 _1195;
        if (nfruWalkAvgMotion.x < 100000001504746621987668885504.0f)
        {
            _1195 = nfruWalkAvgMotion;
        }
        else
        {
            uint _1109 = _1185 & 2147483647u;
            uint _1141 = uint(max((int((_1109 >> 16u) & 15u) - 6), 0));
            _1195 = float2(float((1 - (2 * int((_1109 >> 15u) & 1u))) * int(((_1109 >> uint(7)) & 127u) << _1141)), float((1 - (2 * int((_1109 >> 14u) & 1u))) * int((_1109 & 127u) << _1141))) * 0.0624427758157253265380859375f;
        }
        rw_warped_filled_flow_tm1[_566] = float4(_1195 * cbFI_FlowLaneSizeRcp, 0.0f, 0.0f).xy;
        break;
    } while(false);
}

[numthreads(16, 16, 1)]
void main(SPIRV_Cross_Input stage_input)
{
    gl_GlobalInvocationID = stage_input.gl_GlobalInvocationID;
    comp_main();
}
