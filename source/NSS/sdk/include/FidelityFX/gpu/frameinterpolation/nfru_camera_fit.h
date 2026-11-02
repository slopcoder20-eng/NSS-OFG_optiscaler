                                                                                                                     
                                                                                                                      
                                                                                                                        
                                                                                                                    
                                                                                                                  
                                                                                                               
                                                                                                                 
                                                                                                              
                                                                                     
                                                                                                              
                                                                                                                     
                                                                                                                       
                                                                                                              
                                            
                                                                                                           
                                             
                                                                                                                 
                                                                                
                                                        
                                                                                              
                                                                                             
#ifndef NFRU_CAMERA_FIT_H
#define NFRU_CAMERA_FIT_H
#if defined(NFRU_DIAG_BINDING) && defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_MOTION_TP1) && defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TM1)
#define NFRU_FIT_N 768u                                
shared float nfruFitX[NFRU_FIT_N * 3u];                                  
shared float nfruFitT[NFRU_FIT_N * 2u];                     
shared float nfruFitW[NFRU_FIT_N];                                   
shared float nfruFitRes[NFRU_FIT_N];                                                     
shared float nfruFitA[6 * 7];                                                                          
shared float nfruFitStep[6];
shared float nfruFitR[9];                                       
shared float nfruFitTr[3];
shared float nfruFitRed[256];
shared float nfruFitStat[8];                                                                                              

uint NfruCamOffset() { return NfruFlowMetaOffset() + uint(FlowLaneSize().x * FlowLaneSize().y); }
void NfruFitSync() { groupMemoryBarrier(); barrier(); }
bool NfruFitUsable(uint i) { return nfruFitX[i * 3u + 2u] > 0.0; }

float2 NfruFitTan() { return float2(cbFI._DeviceToViewDepth[2], cbFI._DeviceToViewDepth[3]); }

                                                 
void NfruFitRodrigues(float3 w, out float m[9])
{
    const float th = length(w);
    const float3 k = th > 1e-12 ? w / th : float3(1.0, 0.0, 0.0);
    const float s = sin(th), c1 = 1.0 - cos(th);
    m[0] = 1.0 + c1 * (k.x * k.x - 1.0); m[1] = -s * k.z + c1 * k.x * k.y; m[2] = s * k.y + c1 * k.x * k.z;
    m[3] = s * k.z + c1 * k.x * k.y;     m[4] = 1.0 + c1 * (k.y * k.y - 1.0); m[5] = -s * k.x + c1 * k.y * k.z;
    m[6] = -s * k.y + c1 * k.x * k.z;    m[7] = s * k.x + c1 * k.y * k.z;     m[8] = 1.0 + c1 * (k.z * k.z - 1.0);
}

float3 NfruFitMul(float m[9], float3 v) { return float3(m[0] * v.x + m[1] * v.y + m[2] * v.z, m[3] * v.x + m[4] * v.y + m[5] * v.z, m[6] * v.x + m[7] * v.y + m[8] * v.z); }

                                                                               
float2 NfruFitResidual(uint i, float m[9], float3 t, float2 halfPx, out float3 RX)
{
    const float3 X = float3(nfruFitX[i * 3u], nfruFitX[i * 3u + 1u], nfruFitX[i * 3u + 2u]);
    RX = NfruFitMul(m, X);
    const float3 Y = RX + t;
    const float2 tn = NfruFitTan();
    const float2 p = Y.xy / (max(Y.z, 1e-6) * tn);
    return (p - float2(nfruFitT[i * 2u], nfruFitT[i * 2u + 1u])) * halfPx;
}

                                                                                                              
float2 NfruFitJ(uint k, float3 RX, float3 t, float2 halfPx)
{
    const float3 Y = RX + t;
    const float2 tn = NfruFitTan();
    const float iz = 1.0 / max(Y.z, 1e-6);
    const float3 du = float3(iz / tn.x, 0.0, -Y.x * iz * iz / tn.x) * halfPx.x;
    const float3 dv = float3(0.0, iz / tn.y, -Y.y * iz * iz / tn.y) * halfPx.y;
    float3 dY;
    if (k < 3u) { const float3 e = float3(k == 0u ? 1.0 : 0.0, k == 1u ? 1.0 : 0.0, k == 2u ? 1.0 : 0.0); dY = cross(e, RX); }
    else dY = float3(k == 3u ? 1.0 : 0.0, k == 4u ? 1.0 : 0.0, k == 5u ? 1.0 : 0.0);
    return float2(dot(du, dY), dot(dv, dY));
}

void NfruFitLoad(out float m[9], out float3 t)
{
    for (uint j = 0u; j < 9u; ++j) m[j] = nfruFitR[j];
    t = float3(nfruFitTr[0], nfruFitTr[1], nfruFitTr[2]);
}

                                                                                                        
void NfruFitPass(uint lid, float huber, bool cut, bool full, float2 halfPx)
{
    float m[9]; float3 t;
    NfruFitLoad(m, t);
                                        
    for (uint j = 0u; j < 3u; ++j)
    {
        const uint i = lid * 3u + j;
        float3 RX;
        nfruFitRes[i] = NfruFitUsable(i) ? length(NfruFitResidual(i, m, t, halfPx, RX)) : 1e9;
    }
    NfruFitSync();
    if (lid == 0u)
    {
        float n = 0.0, kept = 0.0;
        for (uint i = 0u; i < NFRU_FIT_N; ++i) if (NfruFitUsable(i)) { n += 1.0; if (nfruFitRes[i] < 4.0 * huber) kept += 1.0; }
        nfruFitStat[2] = (cut && kept >= 0.25 * n) ? 1.0 : 0.0;
    }
    NfruFitSync();
    const bool doCut = nfruFitStat[2] > 0.5;
    float c0 = 0.0;
    for (uint j = 0u; j < 3u; ++j)
    {
        const uint i = lid * 3u + j;
        const float r = nfruFitRes[i];
        float w = 0.0;
        if (NfruFitUsable(i) && !(doCut && r >= 4.0 * huber)) w = r < huber ? 1.0 : huber / max(r, 1e-6);
        nfruFitW[i] = w;
        c0 += w * r * r;
    }
    nfruFitRed[lid] = c0;
    NfruFitSync();
                                                 
    if (lid < 27u)
    {
        uint r = 0u, c = 0u;
        if (lid < 21u) { uint e = lid, rowLen = 6u; while (e >= rowLen) { e -= rowLen; ++r; --rowLen; } c = r + e; }
        else r = lid - 21u;
        float s = 0.0;
        for (uint i = 0u; i < NFRU_FIT_N; ++i)
        {
            const float w = nfruFitW[i];
            if (w <= 0.0) continue;
            float3 RX;
            const float2 res = NfruFitResidual(i, m, t, halfPx, RX);
            const float2 jr = NfruFitJ(r, RX, t, halfPx);
            if (lid < 21u) { const float2 jc = NfruFitJ(c, RX, t, halfPx); s += w * dot(jr, jc); }
            else s += w * dot(jr, res);
        }
        if (lid < 21u) { nfruFitA[r * 7u + c] = s; nfruFitA[c * 7u + r] = s; }
        else nfruFitA[r * 7u + 6u] = s;
    }
    NfruFitSync();
    if (lid == 0u)
    {
        float tot = 0.0;
        for (uint i = 0u; i < 256u; ++i) tot += nfruFitRed[i];
        nfruFitStat[0] = tot;
        float tr = 0.0;
        for (uint k = 0u; k < 6u; ++k) tr += nfruFitA[k * 7u + k];
        for (uint k = 0u; k < 6u; ++k) nfruFitA[k * 7u + k] += 1e-9 * tr + 1e-30;
        if (!full)                                                       
            for (uint k = 3u; k < 6u; ++k)
            {
                for (uint j = 0u; j < 7u; ++j) nfruFitA[k * 7u + j] = 0.0;
                for (uint j = 0u; j < 6u; ++j) nfruFitA[j * 7u + k] = 0.0;
                nfruFitA[k * 7u + k] = 1.0;
            }
                                                     
        for (uint k = 0u; k < 6u; ++k)
        {
            uint p = k; float best = abs(nfruFitA[k * 7u + k]);
            for (uint i = k + 1u; i < 6u; ++i) if (abs(nfruFitA[i * 7u + k]) > best) { best = abs(nfruFitA[i * 7u + k]); p = i; }
            if (p != k) for (uint j = 0u; j < 7u; ++j) { const float tmp = nfruFitA[k * 7u + j]; nfruFitA[k * 7u + j] = nfruFitA[p * 7u + j]; nfruFitA[p * 7u + j] = tmp; }
            const float piv = abs(nfruFitA[k * 7u + k]) > 1e-30 ? nfruFitA[k * 7u + k] : 1e-30;
            for (uint i = k + 1u; i < 6u; ++i)
            {
                const float f = nfruFitA[i * 7u + k] / piv;
                for (uint j = k; j < 7u; ++j) nfruFitA[i * 7u + j] -= f * nfruFitA[k * 7u + j];
            }
        }
        for (int i = 5; i >= 0; --i)
        {
            float s = nfruFitA[uint(i) * 7u + 6u];
            for (uint j = uint(i) + 1u; j < 6u; ++j) s -= nfruFitA[uint(i) * 7u + j] * nfruFitStep[j];
            const float dg = nfruFitA[uint(i) * 7u + uint(i)];
            nfruFitStep[uint(i)] = s / (abs(dg) > 1e-30 ? dg : 1e-30);
        }
        if (!full) { nfruFitStep[3] = 0.0; nfruFitStep[4] = 0.0; nfruFitStep[5] = 0.0; }
        nfruFitStat[1] = 0.0;
    }
    NfruFitSync();
                                                                                          
    for (uint trial = 0u; trial < 5u; ++trial)
    {
        const float scale = 1.0 / float(1u << trial);
        float dr[9], mt[9];
        NfruFitRodrigues(-scale * float3(nfruFitStep[0], nfruFitStep[1], nfruFitStep[2]), dr);
        for (uint a = 0u; a < 3u; ++a) for (uint b = 0u; b < 3u; ++b)
            mt[a * 3u + b] = dr[a * 3u] * m[b] + dr[a * 3u + 1u] * m[3u + b] + dr[a * 3u + 2u] * m[6u + b];
        const float3 tt = t - scale * float3(nfruFitStep[3], nfruFitStep[4], nfruFitStep[5]);
        float c = 0.0;
        for (uint j = 0u; j < 3u; ++j)
        {
            const uint i = lid * 3u + j;
            if (nfruFitW[i] > 0.0) { float3 RX; const float2 rr = NfruFitResidual(i, mt, tt, halfPx, RX); c += nfruFitW[i] * dot(rr, rr); }
        }
        nfruFitRed[lid] = c;
        NfruFitSync();
        if (lid == 0u && nfruFitStat[1] < 0.5)
        {
            float tot = 0.0;
            for (uint i = 0u; i < 256u; ++i) tot += nfruFitRed[i];
            if (tot < nfruFitStat[0] && !isnan(tot))
            {
                for (uint j = 0u; j < 9u; ++j) nfruFitR[j] = mt[j];
                nfruFitTr[0] = tt.x; nfruFitTr[1] = tt.y; nfruFitTr[2] = tt.z;
                nfruFitStat[1] = 1.0;
            }
        }
        NfruFitSync();
    }
}

                                                                                 
void NfruCameraFit(uint lid)
{
    const float2 halfPx = 0.5 * float2(RenderSize());
    const float c0 = cbFI._DeviceToViewDepth[0], e0 = cbFI._DeviceToViewDepth[1];
    const float2 tn = NfruFitTan();
                                                  
    float mvSum = 0.0;
    for (uint j = 0u; j < 3u; ++j)
    {
        const uint i = lid * 3u + j;
        const float2 uv = 0.03 + 0.94 * (float2(float(i % 32u) + 0.5, float(i / 32u) + 0.5) / float2(32.0, 24.0));
        const float2 mv = float2(LoadInputMotionTp1(uv));
        const float2 q = uv + mv;
        const float d = LoadInputDepthTp1(uv);
        const float z = e0 / (d - c0);
        const bool ok = all(greaterThan(q, float2(0.0))) && all(lessThan(q, float2(1.0))) && !any(isnan(mv)) && !any(isinf(mv))
                        && z > 0.0 && !isinf(z) && !isnan(z);
        const float2 n = float2(2.0 * uv.x - 1.0, 1.0 - 2.0 * uv.y);
        nfruFitX[i * 3u] = n.x * tn.x * z; nfruFitX[i * 3u + 1u] = n.y * tn.y * z; nfruFitX[i * 3u + 2u] = ok ? z : -1.0;
        nfruFitT[i * 2u] = 2.0 * q.x - 1.0; nfruFitT[i * 2u + 1u] = 1.0 - 2.0 * q.y;
        nfruFitRes[i] = ok ? length(mv * float2(RenderSize())) : -1.0;                                              
    }
    if (lid < 9u) nfruFitR[lid] = (lid == 0u || lid == 4u || lid == 8u) ? 1.0 : 0.0;
    if (lid < 3u) nfruFitTr[lid] = 0.0;
    NfruFitSync();
    if (lid == 0u)
    {
        float ms = 0.0, mn = 0.0, ls = 0.0;
        for (uint i = 0u; i < NFRU_FIT_N; ++i)
            if (nfruFitRes[i] >= 0.0) { ms += nfruFitRes[i]; mn += 1.0; ls += log(nfruFitX[i * 3u + 2u]); }
        nfruFitStat[4] = mn > 0.0 ? ms / mn : 0.0;
        nfruFitStat[3] = mn > 0.0 ? exp(ls / mn) : 0.0;
    }
    NfruFitSync();
    for (uint j = 0u; j < 3u; ++j)
    {
        const uint i = lid * 3u + j;
                                                                   
        if (nfruFitRes[i] < 0.25 * nfruFitStat[4] || nfruFitX[i * 3u + 2u] < 0.2 * nfruFitStat[3]) nfruFitX[i * 3u + 2u] = -1.0;
    }
    NfruFitSync();

    NfruFitPass(lid, 16.0, false, false, halfPx);
    NfruFitPass(lid, 6.0, false, false, halfPx);
    NfruFitPass(lid, 3.0, false, false, halfPx);
    NfruFitPass(lid, 8.0, false, true, halfPx);
    NfruFitPass(lid, 4.0, false, true, halfPx);
    NfruFitPass(lid, 2.0, true, true, halfPx);
    for (uint k = 0u; k < 5u; ++k) NfruFitPass(lid, 1.0, true, true, halfPx);

                      
    {
        float m[9]; float3 t;
        NfruFitLoad(m, t);
        for (uint j = 0u; j < 3u; ++j)
        {
            const uint i = lid * 3u + j;
            float3 RX;
            nfruFitRes[i] = NfruFitUsable(i) ? length(NfruFitResidual(i, m, t, halfPx, RX)) : 1e9;
        }
    }
    NfruFitSync();
    if (lid == 0u)
    {
        float inl = 0.0, cnt = 0.0, rs = 0.0;
        for (uint i = 0u; i < NFRU_FIT_N; ++i)
        {
            if (NfruFitUsable(i)) cnt += 1.0;
            if (nfruFitRes[i] < 2.0) { inl += 1.0; rs += nfruFitRes[i]; }
        }
        const float meanRes = inl > 0.0 ? rs / inl : 1e9;
                                                                                         
        float T[16], Ti[16], P[16], Pi[16], M[16], Mi[16], tmp[16];
        for (uint k = 0u; k < 16u; ++k) { T[k] = 0.0; Ti[k] = 0.0; P[k] = 0.0; Pi[k] = 0.0; }
        for (uint a = 0u; a < 3u; ++a)
            for (uint b = 0u; b < 3u; ++b) { T[a * 4u + b] = nfruFitR[a * 3u + b]; Ti[a * 4u + b] = nfruFitR[b * 3u + a]; }
        T[3] = nfruFitTr[0]; T[7] = nfruFitTr[1]; T[11] = nfruFitTr[2]; T[15] = 1.0;
        for (uint a = 0u; a < 3u; ++a) Ti[a * 4u + 3u] = -(nfruFitR[a] * nfruFitTr[0] + nfruFitR[3u + a] * nfruFitTr[1] + nfruFitR[6u + a] * nfruFitTr[2]);
        Ti[15] = 1.0;
        P[0] = 1.0 / tn.x; P[5] = 1.0 / tn.y; P[10] = c0; P[11] = e0; P[14] = 1.0;
        Pi[0] = tn.x; Pi[5] = tn.y; Pi[11] = 1.0; Pi[14] = 1.0 / e0; Pi[15] = -c0 / e0;
        for (uint a = 0u; a < 4u; ++a) for (uint b = 0u; b < 4u; ++b) { float s = 0.0; for (uint k = 0u; k < 4u; ++k) s += T[a * 4u + k] * Pi[k * 4u + b]; tmp[a * 4u + b] = s; }
        for (uint a = 0u; a < 4u; ++a) for (uint b = 0u; b < 4u; ++b) { float s = 0.0; for (uint k = 0u; k < 4u; ++k) s += P[a * 4u + k] * tmp[k * 4u + b]; M[a * 4u + b] = s; }
        for (uint a = 0u; a < 4u; ++a) for (uint b = 0u; b < 4u; ++b) { float s = 0.0; for (uint k = 0u; k < 4u; ++k) s += Ti[a * 4u + k] * Pi[k * 4u + b]; tmp[a * 4u + b] = s; }
        for (uint a = 0u; a < 4u; ++a) for (uint b = 0u; b < 4u; ++b) { float s = 0.0; for (uint k = 0u; k < 4u; ++k) s += P[a * 4u + k] * tmp[k * 4u + b]; Mi[a * 4u + b] = s; }
        const uint base = NfruCamOffset();
        bool finite = true;
        for (uint c = 0u; c < 4u; ++c)
            for (uint r = 0u; r < 4u; ++r)
            {
                rw_nfru_diagnostics.counts[base + c * 4u + r] = floatBitsToUint(M[r * 4u + c]);
                rw_nfru_diagnostics.counts[base + 16u + c * 4u + r] = floatBitsToUint(Mi[r * 4u + c]);
                finite = finite && !isnan(M[r * 4u + c]) && !isinf(M[r * 4u + c]) && !isnan(Mi[r * 4u + c]) && !isinf(Mi[r * 4u + c]);
            }
        const bool ok = finite && cnt > 250.0 && inl > 0.4 * cnt && meanRes < 1.0;
        rw_nfru_diagnostics.counts[base + 32u] = ok ? 1u : 0u;
        rw_nfru_diagnostics.counts[base + 33u] = floatBitsToUint(meanRes);
        rw_nfru_diagnostics.counts[base + 34u] = uint(inl);
        rw_nfru_diagnostics.counts[base + 35u] = uint(cnt);
    }
}
#endif
#endif
