// SPDX-FileCopyrightText: Copyright 2026 Arm Limited and/or its affiliates <open-source-office@arm.com>
// SPDX-License-Identifier: MIT

#ifndef GPU_FFX_FRAMEINTERPOLATION_40_POSTPROCESS_PASS_H
#define GPU_FFX_FRAMEINTERPOLATION_40_POSTPROCESS_PASS_H

#define HALF_MIN 0.00006103515625HF

#include "ffx_frameinterpolation_callbacks_glsl.h"
#include "nfru_diagnostic_glsl.h"
#include "nfru_angular.h"
#include "quant.h"

          

#ifdef NFRU_SELECT_BINDING
                                                                                                                          
                                                                                                                            
layout(set=0,binding=NFRU_SELECT_BINDING,std430) buffer NfruSelectCand { uint cand[]; } rw_nfru_select;
uint NfruPackR11G11B10(float3 c)
{
    const uint rg=packHalf2x16(float2(clamp(c.rg,0.0,65000.0)));
    const uint b_h=packHalf2x16(float2(clamp(c.b,0.0,65000.0),0.0));
    const uint r=(rg&0x7fffu)>>4u;
    const uint g=((rg>>16u)&0x7fffu)>>4u;
    const uint b=(b_h&0x7fffu)>>5u;
    return r|(g<<11u)|(b<<22u);
}
#endif

FFX_MIN16_F max4(FFX_MIN16_F4 x)
{
    return max(max(max(x.x, x.y), x.z), x.w);
}

FFX_MIN16_F4 Stable_Softmax(FFX_MIN16_F4 tensor)
{
                                                            
    FFX_MIN16_F4 stable_ten     = tensor - max4(tensor);
    FFX_MIN16_F4 e_ten          = exp(stable_ten);
    FFX_MIN16_F  sum            = dot(e_ten, FFX_MIN16_F4(1.0HF));
    FFX_MIN16_F4 smax_activated = e_ten / (sum + HALF_MIN);
    return smax_activated;
}

#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1)
bool NfruInside(float2 p){return all(greaterThan(p,float2(0)))&&all(lessThan(p,float2(1)));}
float NfruPairDepthConfidence(float2 a,float2 b){
    if(!NfruInside(a)||!NfruInside(b))return 0.0;
    float da=LoadInputDepthTm1(a),db=LoadInputDepthTp1(b);
    float4 q=FFX_TRANSFORM_VECTOR(GetMotionTM1ToTP1(),float4(2.0*float2(a.x,1.0-a.y)-1.0,da,1.0));
    if(abs(q.w)<1e-6)return 0.0;
    float za=abs(ConvertFromDeviceDepthToViewSpace(q.z/q.w));
    float zb=abs(ConvertFromDeviceDepthToViewSpace(db));
    float error=abs(za-zb)/max(max(za,zb),1e-4);
    return 1.0-smoothstep(0.02,0.10,error);
}
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_MOTION_QDATA_TP1)
                                                                                                                
                                                                                                             
float NfruQDataNearness(uint q){return q==0u?-1.0:float((q>>20u)&2047u)*(1.1/2047.0);}
float NfruSourceNearness(int32_t2 p)
{
    int32_t2 lane=MvDepthLaneSize();
                                                                                                     
    uint best=LoadWarpedMotionQDataTP1(p);
    if(best!=0u)return NfruQDataNearness(best);
    for(int dy=-1;dy<=1;++dy)for(int dx=-1;dx<=1;++dx){
        int32_t2 q=clamp(p+int32_t2(dx,dy),int32_t2(0),lane-1);
        best=max(best,LoadWarpedMotionQDataTP1(q));
    }
    if(best!=0u)return NfruQDataNearness(best);
    const int32_t2 dirs[8]=int32_t2[8](int32_t2(1,0),int32_t2(-1,0),int32_t2(0,1),int32_t2(0,-1),int32_t2(1,1),int32_t2(-1,1),int32_t2(1,-1),int32_t2(-1,-1));
    const int radii[5]=int[5](2,4,7,11,16);
    uint background=0xffffffffu;
    for(int d=0;d<8;++d)for(int r=0;r<5;++r){
        int32_t2 q=p+dirs[d]*radii[r];
        if(any(lessThan(q,int32_t2(0)))||any(greaterThanEqual(q,lane)))break;
        uint tap=LoadWarpedMotionQDataTP1(q);
        if(tap!=0u){background=min(background,tap);break;}
    }
    return background==0xffffffffu?-1.0:NfruQDataNearness(background);
}
                                               
float NfruDeviceNearness(float device){return 1.0-NormalizeDepth(device);}
                                                                                                                
                                                                                                      
float NfruDeviceQ(float device)
{
#if FFX_ARM_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH
    return device;
#else
    return 1.0 - device;
#endif
}
float NfruNearnessThresholdQ(float nearness){return (exp(nearness*log(DEPTH_LOG_K+1.0))-1.0)/DEPTH_LOG_K;}
                                                                                                           
                                                                                                        
float NfruBackgroundNearness(float2 uv,bool previous)
{
    float nearest=2.0;
    for(int k=0;k<24;++k){
        float a=float(k&7)*0.7853982;
        float2 ring=float((k>>3)==0?16:((k>>3)==1?48:96))*MvDepthLaneSizeRcp();
        float2 p=clamp(uv+ring*float2(cos(a),sin(a)),float2(0.0),float2(1.0));
        nearest=min(nearest,NfruDeviceNearness(previous?LoadInputDepthTm1(p):LoadInputDepthTp1(p)));
    }
    return nearest;
}
#endif
                                                                                                                
float2 NfruCameraDisp(float2 p,float depth,mat4 motion){
    float2 pT=float2(p.x,1.0-p.y);
    float4 r=motion*float4(2.0*pT-1.0,depth,1.0);
    if(!(r.w>1e-6))return float2(1e6);
    float2 q=(r.xy/r.w+1.0)*0.5;
    return float2(q.x-pT.x,pT.y-q.y);
}
#endif
                                                                                                                
                                                                          
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1)
bool NfruLockedTexel(float2 p,float2 displayPx)
{
    if(!NfruInside(p))return false;
    const float2 cam=NfruCameraDisp(p,LoadInputDepthTp1(p),GetMotionTP1ToTM1());
    if(any(greaterThan(abs(cam),float2(1e5))))return false;
    const float camLen=length(cam*displayPx),mvLen=length(float2(LoadInputMotionTp1(p))*displayPx);
    return camLen>8.0*displayPx.x/float(MvDepthLaneSize().x)&&mvLen<0.2*camLen;
}
#endif

                                                                                                                            
                                                                                                                           
                                                        
                                                                                                                            
                                                                                                                         
                                                                                                                         
                                                                                                                         
                                                                                                                          
                                  
                                                                                                                        
                                                                                                                       
                                                                                                                       
                                                             
#if defined(NFRU_SELECT_BINDING) && defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1) && defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TM1) && defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_MOTION_TP1)
#define NFRU_BIREPROJ_AVAILABLE 1
#if FFX_ARM_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH
#define NFRU_BI_FAR_DEPTH 1e-7
#else
#define NFRU_BI_FAR_DEPTH 0.9999999
#endif
float2 NfruBiCurV(float2 p) { return float2(LoadInputMotionTp1(clamp(p, float2(0.0), float2(1.0)))); }                         
float2 NfruBiPrevV(float2 q, float2 displayPx, mat4 prevToCur)                                                                  
{
    q = clamp(q, float2(0.0), float2(1.0));
    if (NfruLockedTexel(q, displayPx)) return -float2(LoadInputMotionTp1(q));
    const float2 d = NfruCameraDisp(q, LoadInputDepthTm1(q), prevToCur);
    return any(greaterThan(abs(d), float2(4.0))) ? float2(0.0) : d;
}
                                                                                           
float NfruBiSolve(float2 x, float w, bool cur, float2 seed, float2 displayPx, mat4 prevToCur, out float2 p)
{
    p = seed;
    for (int k = 0; k < 30; ++k)
    {
        const float2 v = cur ? NfruBiCurV(p) : NfruBiPrevV(p, displayPx, prevToCur);
        p += 0.7 * (x - w * v - p);
    }
    const float2 v = cur ? NfruBiCurV(p) : NfruBiPrevV(p, displayPx, prevToCur);
    return NfruInside(p) ? length((p + w * v - x) * float2(RenderSize())) : 1e9;
}
                                                                               
float NfruBiBest(float2 x, float w, bool cur, float2 displayPx, float2 vBackground, mat4 prevToCur, out float2 pBest)
{
    float2 seeds[3];
    seeds[0] = x;
    seeds[1] = x - w * (cur ? NfruBiCurV(x) : NfruBiPrevV(x, displayPx, prevToCur));
    seeds[2] = x - w * vBackground;
    float bestR = 1e9, bestN = -1.0;
    pBest = x;
    for (int s = 0; s < 3; ++s)
    {
        float2 p;
        const float r = NfruBiSolve(x, w, cur, seeds[s], displayPx, prevToCur, p);
        const float n = NfruDeviceNearness(cur ? LoadInputDepthTp1(clamp(p, float2(0.0), float2(1.0))) : LoadInputDepthTm1(clamp(p, float2(0.0), float2(1.0))));
        const bool ok = r < 0.35, bestOk = bestR < 0.35;
        if ((ok && (!bestOk || n > bestN)) || (!ok && !bestOk && r < bestR)) { bestR = r; bestN = n; pBest = p; }
    }
    return bestR;
}
float3 NfruBireproj(float2 x, float t, float2 displayPx, uint view, out float conf)
{
                                                                                                                       
                                                                                                                      
    const mat4 curToPrev = GetMotionTP1ToTM1();
    const mat4 prevToCur = inverse(curToPrev);
    if (view == 35u)                                                                                                                     
    {
        conf = 2.0;
        const int32_t2 px = int32_t2(x * displayPx);
        if (px.y != int(displayPx.y) / 2 || px.x >= 80) return float3(0.0);                                     
        const int k = px.x / 2;
        float v = 0.0;
        if (k < 16) v = curToPrev[k / 4][k % 4];
        else if (k < 32) v = prevToCur[(k - 16) / 4][(k - 16) % 4];
        else if (k < 36) v = cbFI._DeviceToViewDepth[k - 32];
        else if (k == 36) v = float(RenderSize().x);
        else if (k == 37) v = float(RenderSize().y);
        const uint b = floatBitsToUint(v);
        const uint h = (px.x & 1) == 0 ? (b >> 16u) : (b & 0xffffu);
        return float3(float(h >> 8u) / 255.0, float(h & 255u) / 255.0, 0.0);
    }
    if (view == 33u || view == 34u)                                                                                            
    {
        const float2 mv = NfruBiCurV(x);
        float2 e;
        if (view == 33u) e = NfruCameraDisp(x, LoadInputDepthTp1(x), curToPrev) - mv;
        else { const float2 q = x + mv; e = NfruInside(q) ? NfruCameraDisp(q, LoadInputDepthTm1(q), prevToCur) + mv : float2(0.0); }
        conf = 2.0;
        return float3(clamp(length(e * float2(RenderSize())) / 4.0, 0.0, 1.0), NfruLockedTexel(x, displayPx) ? 1.0 : 0.0, 0.0);
    }
    float2 vbc = NfruCameraDisp(x, NFRU_BI_FAR_DEPTH, curToPrev);                                       
    float2 vbp = NfruCameraDisp(x, NFRU_BI_FAR_DEPTH, prevToCur);
    if (any(greaterThan(abs(vbc), float2(4.0)))) vbc = float2(0.0);
    if (any(greaterThan(abs(vbp), float2(4.0)))) vbp = float2(0.0);
    float2 pc, pp;
    const float rc = NfruBiBest(x, 1.0 - t, true, displayPx, vbc, prevToCur, pc);
    const float rp = NfruBiBest(x, t, false, displayPx, vbp, prevToCur, pp);
    const float3 cc = float3(SampleCurrentBackbuffer(pc)), cp = float3(SamplePreviousBackbuffer(pp));
    const float zc = abs(ConvertFromDeviceDepthToViewSpace(LoadInputDepthTp1(clamp(pc, float2(0.0), float2(1.0)))));
    const float zp = abs(ConvertFromDeviceDepthToViewSpace(LoadInputDepthTm1(clamp(pp, float2(0.0), float2(1.0)))));
    const float ac = exp(-(rc / 0.5) * (rc / 0.5)), ap = exp(-(rp / 0.5) * (rp / 0.5));
                                                                                                                     
    const float occ = 1.0 / (1.0 + exp(-clamp((log(max(zp, 1e-6)) - log(max(zc, 1e-6))) / 0.15, -60.0, 60.0)));
    const float wc = ac * t * ((1.0 - ap) + ap * 2.0 * occ) + 1e-4 * t;
    const float wp = ap * (1.0 - t) * ((1.0 - ac) + ac * 2.0 * (1.0 - occ)) + 1e-4 * (1.0 - t);
    const float pair = ac * ap * 4.0 * occ * (1.0 - occ);
    const float diff = abs(dot(cp - cc, float3(0.299, 0.587, 0.114)));
    conf = pair * (1.0 - smoothstep(0.02, 0.12, diff)) + 0.35 * (1.0 - pair) * max(ac, ap);
    if (view == 30u) return cc;                                                          
    if (view == 31u) return cp;                                                           
    if (view == 32u) return float3(ac, ap, occ);                                                             
    return (wc * cc + wp * cp) / (wc + wp);
}
float4 NfruBiLoad(int32_t2 p, int32_t2 size)
{
    p = clamp(p, int32_t2(0), size - 1);
    const uint b = uint(p.y * size.x + p.x) * 2u;
    return float4(unpackHalf2x16(rw_nfru_select.cand[b]), unpackHalf2x16(rw_nfru_select.cand[b + 1u]));
}
void NfruBiStore(int32_t2 p, int32_t2 size, float3 c, float conf)
{
    const uint b = uint(p.y * size.x + p.x) * 2u;
    rw_nfru_select.cand[b] = packHalf2x16(c.rg);
    rw_nfru_select.cand[b + 1u] = packHalf2x16(float2(c.b, conf));
}
                                                                  
void NfruDidyk(int32_t2 px, int32_t2 size)
{
    const float4 c0 = NfruBiLoad(px, size);
    if (c0.w > 1.5) { StoreFrameinterpolationOutput(px, FFX_MIN16_F4(c0.rgb, 1.0)); return; }
    float3 lo = float3(0.0); float wl = 0.0, cs = 0.0, wcs = 0.0;
    for (int j = -2; j <= 2; ++j)
        for (int i = -2; i <= 2; ++i)
        {
            const float r2 = float(i * i + j * j);
            const float w1 = exp(-r2 * 4.0 / (2.0 * 6.25));                                    
            lo += w1 * NfruBiLoad(px + int32_t2(i, j) * 2, size).rgb; wl += w1;
            const float w2 = exp(-r2 * 36.0 / (2.0 * 36.0));                                 
            cs += w2 * min(NfruBiLoad(px + int32_t2(i, j) * 6, size).w, 1.0); wcs += w2;
        }
    lo /= wl;
    const float c = clamp(cs / wcs, 0.0, 1.0);
    StoreFrameinterpolationOutput(px, FFX_MIN16_F4(lo + c * (c0.rgb - lo), 1.0));
}
#endif

void postprocess(int32_t2 output_pixel)
{
    int32_t2 displaySize = DisplaySize();
    if (any(greaterThanEqual(output_pixel, displaySize)))
        return;

                                                                              
                                                                                
    if (cbFI._Reset != 0u) {
        StoreFrameinterpolationOutput(output_pixel, FFX_MIN16_F4(LoadPresentBackbuffer(output_pixel).rgb, 1.0f));
#if FFX_ARM_FRAMEINTERPOLATION_OPTION_MANAGE_PREVIOUS_COLOR
        StorePreviousInterpolationSource(output_pixel, FFX_MIN16_F4(LoadCurrentBackbuffer(output_pixel), 1.0f));
#endif
        return;
    }

#ifdef NFRU_BIREPROJ_AVAILABLE
                                                                                      
    if ((cbFI._NfruT2Flags & 4194304u) != 0u) { NfruDidyk(output_pixel, displaySize); return; }
#endif
    float2 uv = (float2(output_pixel.xy) + 0.5f) * DisplaySizeRcp();

    float2   mvDepthLanef = float2(MvDepthLaneSize());
    float2   flowLanef    = float2(FlowLaneSize());
    float2   ofSizef      = float2(GetOpticalFlowResolution());
    int32_t2 iMvCoord     = int32_t2(floor(uv * mvDepthLanef));
    int32_t2 iFlowCoord   = int32_t2(floor(uv * flowLanef));

                                                                
    float2       tensor_uv = uv * ofSizef * InputTensorSizeRcp();
    FFX_MIN16_F4 params    = Dequantize(FFX_MIN16_F4(SampleOutParamsTensor(tensor_uv)), QuantParamsSNORM().zw);

                                                             
    FFX_MIN16_F2 flow_t_f30_p1 = LoadWarpedFilledFlowTM1(iFlowCoord);
    FFX_MIN16_F2 mv_t_f30_m1   = LoadWarpedFilledMotionTP1(iMvCoord);

                                         
    float  timestep = Timestep();
    const float2 uvSpace = NfruSpace(uv);
    bool edgeRefined=false;
    float3 edgeDebug=float3(0.0);                                                           
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1) && defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_MOTION_QDATA_TP1)
                                                                                                                   
                                                                                                                      
                                                                                                                      
                                                                                                                   
                                                                                                             
                                                                                                                  
    if((cbFI._NfruT2Flags&8u)!=0u){
        const int32_t2 lane=MvDepthLaneSize();
        edgeRefined=false;
        uint qs[9];
        float lo=2.0,hi=-1.0;
        for(int i=0;i<9;++i){
            qs[i]=LoadWarpedMotionQDataTP1(clamp(iMvCoord+int32_t2(i%3-1,i/3-1),int32_t2(0),lane-1));
            if(qs[i]!=0u){float n=NfruQDataNearness(qs[i]);lo=min(lo,n);hi=max(hi,n);}
        }
        edgeDebug.y=hi>=0.0?1.0:0.0;
        if(hi-lo>0.02){
            edgeDebug.x=1.0;
                                                                                                                  
                                                                                                                
                                                                                                         
            float bestN=-1.0,bestCost=1e9;
            int32_t2 bestCoord=iMvCoord,fallbackCoord=iMvCoord;
            float2 bestV=float2(mv_t_f30_m1),fallbackV=bestV;
            for(int i=0;i<9;++i){
                if(qs[i]==0u)continue;
                const int32_t2 c=clamp(iMvCoord+int32_t2(i%3-1,i/3-1),int32_t2(0),lane-1);
                const float2 v=dqFloatMv(qs[i])*MvDepthLaneSizeRcp();
                                                                                                           
                const float n=NfruQDataNearness(qs[i])-FFX_ARM_FRAMEINTERPOLATION_FAR_PLANE_DEPTH_BIAS;
                const float2 endPrev=NfruMoveFrom(uvSpace,v,timestep),endCur=NfruMoveFrom(uvSpace,v,-(1.0f-timestep));
                float contradiction=0.0;
                if(NfruInside(endPrev))contradiction+=max(n-NfruDeviceNearness(LoadInputDepthTm1(endPrev))-0.02,0.0);
                if(NfruInside(endCur))contradiction+=max(n-NfruDeviceNearness(LoadInputDepthTp1(endCur))-0.02,0.0);
                if(contradiction==0.0){if(n>bestN){bestN=n;bestCoord=c;bestV=v;}}
                else if(contradiction<bestCost){bestCost=contradiction;fallbackCoord=c;fallbackV=v;}
            }
            if(bestN<0.0){bestCoord=fallbackCoord;bestV=fallbackV;}
            else edgeRefined=true;
            edgeDebug.z=any(notEqual(bestCoord,iMvCoord))?1.0:0.0;
            iMvCoord=bestCoord;mv_t_f30_m1=FFX_MIN16_F2(bestV);
        }
    }
#endif
    float2 uv_m1_mv =NfruMoveFrom(uvSpace, float2(mv_t_f30_m1), timestep);
    float2 uv_p1_mv = NfruMoveFrom(uvSpace, float2(mv_t_f30_m1), -(1.0f - timestep));

                                              
    float2 uv_m1_flow = NfruMoveFrom(uvSpace, float2(flow_t_f30_p1), -timestep);
    float2 uv_p1_flow = NfruMoveFrom(uvSpace, float2(flow_t_f30_p1), 1.0f - timestep);

                                                            
    FFX_MIN16_F3 rgb_m1_warp_t_mv   = SamplePreviousBackbuffer(uv_m1_mv);
    FFX_MIN16_F3 rgb_p1_warp_t_mv   = SampleCurrentBackbuffer(uv_p1_mv);
    FFX_MIN16_F3 rgb_m1_warp_t_flow = SamplePreviousBackbuffer(uv_m1_flow);
    FFX_MIN16_F3 rgb_p1_warp_t_flow = SampleCurrentBackbuffer(uv_p1_flow);

                                                    
    params = Stable_Softmax(params);
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1)
                                                                                                                       
                                                                                                             
    const bool layers=(cbFI._NfruT2Flags&262144u)!=0u;
    float lockedCoverage=0.0;
    if(layers){
        const float2 h=0.5/float2(MvDepthLaneSize());
        lockedCoverage=0.25*(float(NfruLockedTexel(uv+float2(-h.x,-h.y),float2(displaySize)))+float(NfruLockedTexel(uv+float2(h.x,-h.y),float2(displaySize)))
                            +float(NfruLockedTexel(uv+float2(-h.x,h.y),float2(displaySize)))+float(NfruLockedTexel(uv+float2(h.x,h.y),float2(displaySize))));
        if(lockedCoverage<1.0){
            FFX_MIN16_F4 keepL=FFX_MIN16_F4(NfruLockedTexel(uv_m1_mv,float2(displaySize))?0.0:1.0,NfruLockedTexel(uv_p1_mv,float2(displaySize))?0.0:1.0,
                                           NfruLockedTexel(uv_m1_flow,float2(displaySize))?0.0:1.0,NfruLockedTexel(uv_p1_flow,float2(displaySize))?0.0:1.0);
            FFX_MIN16_F4 kept=params*keepL;
            FFX_MIN16_F mass=dot(kept,FFX_MIN16_F4(1.0));
            if(mass>FFX_MIN16_F(1e-3))params=kept/mass;
        }
    }
#endif
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1)
                                                                                                                   
                                                                                                                    
                                                                                                                  
                                                                                                                   
    bool ofContradicts=false;
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_MOTION_QDATA_TP1)
    if((cbFI._NfruT2Flags&8u)!=0u&&!edgeRefined&&params.z+params.w>FFX_MIN16_F(0.02)
       &&length((uv_m1_flow-uv_m1_mv)*float2(displaySize))>1.5){
        const uint q=LoadWarpedMotionQDataTP1(iMvCoord);
        if(q!=0u){
            const float n=NfruQDataNearness(q)-FFX_ARM_FRAMEINTERPOLATION_FAR_PLANE_DEPTH_BIAS-0.02;
            ofContradicts=(NfruInside(uv_m1_flow)&&NfruDeviceNearness(LoadInputDepthTm1(uv_m1_flow))<n)
                        ||(NfruInside(uv_p1_flow)&&NfruDeviceNearness(LoadInputDepthTp1(uv_p1_flow))<n);
        }
    }
#endif
    if((edgeRefined||ofContradicts)&&NfruInside(uv_m1_mv)&&NfruInside(uv_p1_mv)){
        FFX_MIN16_F mvMass=params.x+params.y,ofMass=params.z+params.w;
        FFX_MIN16_F prevShare=mvMass>FFX_MIN16_F(1e-3)?params.x/mvMass:FFX_MIN16_F(1.0-timestep);
        params=FFX_MIN16_F4(params.x+ofMass*prevShare,params.y+ofMass*(FFX_MIN16_F(1.0)-prevShare),0.0,0.0);
    }
#endif

    bool mvValid=NfruMotionValid(iMvCoord),flowValid=NfruFlowValid(iFlowCoord);
    bool fallbackCurrent=false;
    float3 guardDebug=float3(mvValid?1.0:0.0,flowValid?1.0:0.0,0.0);
    float3 holeDebug=float3(0.0,0.0,0.5);                                                                                                                                                                                          
    if(NfruHoleGuardEnabled()){
        bool mvPrevious=mvValid&&all(greaterThan(uv_m1_mv,float2(0.0)))&&all(lessThan(uv_m1_mv,float2(1.0)));
        bool mvCurrent=mvValid&&all(greaterThan(uv_p1_mv,float2(0.0)))&&all(lessThan(uv_p1_mv,float2(1.0)));
        bool ofPrevious=flowValid&&all(greaterThan(uv_m1_flow,float2(0.0)))&&all(lessThan(uv_m1_flow,float2(1.0)));
        bool ofCurrent=flowValid&&all(greaterThan(uv_p1_flow,float2(0.0)))&&all(lessThan(uv_p1_flow,float2(1.0)));
        if(!mvValid)NfruDiagAdd(55u);if(!flowValid)NfruDiagAdd(56u);
        if(mvValid&&!flowValid)NfruDiagAdd(58u);if(!mvValid&&flowValid)NfruDiagAdd(59u);
        guardDebug=float3(mvPrevious?1.0:0.0,mvCurrent?1.0:0.0,ofPrevious&&ofCurrent?1.0:(ofPrevious||ofCurrent?0.5:0.0));
                                                                                                                 
                                                                                                               
                                                                                                                
        bool ofAlone=true;
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1)
        if((cbFI._NfruT2Flags&32u)!=0u&&!mvPrevious&&!mvCurrent){
            ofAlone=ofPrevious&&ofCurrent&&NfruPairDepthConfidence(uv_m1_flow,uv_p1_flow)>=0.5;
                                                                                                              
                                                                                                           
            if(ofAlone&&(cbFI._NfruT2Flags&8192u)==0u){
                const float2 d=NfruCameraDisp(uv_m1_flow,LoadInputDepthTm1(uv_m1_flow),GetMotionTM1ToTP1());
                ofAlone=length((uv_m1_flow+d-uv_p1_flow)*float2(displaySize))<=0.1*length(d*float2(displaySize))+8.0;
            }
        }
#endif
        if(!ofAlone){ofPrevious=false;ofCurrent=false;}
        if(!(mvPrevious&&mvCurrent&&ofPrevious&&ofCurrent)){
            params*=FFX_MIN16_F4(mvPrevious?1.0:0.0,mvCurrent?1.0:0.0,ofPrevious?1.0:0.0,ofCurrent?1.0:0.0);
            FFX_MIN16_F mass=dot(params,FFX_MIN16_F4(1.0));
            fallbackCurrent=!(mass>0.0);
            if(!fallbackCurrent)params/=mass;
            else {params=FFX_MIN16_F4(0.0);NfruDiagAdd(57u);}
        }
    }

#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1)&&defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_MOTION_QDATA_TP1)
                                                                                                                
    if((cbFI._NfruT2Flags&65536u)!=0u&&!fallbackCurrent){
        FFX_MIN16_F mvMass=params.x+params.y;
        if(mvMass>FFX_MIN16_F(1e-3))params=FFX_MIN16_F4(params.x/mvMass,params.y/mvMass,0.0,0.0);
        else params=FFX_MIN16_F4(FFX_MIN16_F(1.0)-FFX_MIN16_F(timestep),FFX_MIN16_F(timestep),0.0,0.0);
    }
                                                                                                                     
                                                                                                                       
                                                                                                        
    if((cbFI._NfruT2Flags&(16384u|32768u))!=0u&&!fallbackCurrent&&mvValid){
        const float source=NfruSourceNearness(iMvCoord);
        const float bias=(cbFI._NfruT2Flags&64u)!=0u?FFX_ARM_FRAMEINTERPOLATION_FAR_PLANE_DEPTH_BIAS:0.0;
        FFX_MIN16_F4 keepEnd=FFX_MIN16_F4(1.0);
                                                                                                                     
                                                                                                                  
                                                                                                                    
                                                                                                                 
                                                                             
        const bool hole=LoadWarpedMotionQDataTP1(iMvCoord)==0u;
        bool forced=false;
        if(hole&&NfruInside(uv_m1_mv)&&NfruInside(uv_p1_mv)){
            const float nPrev=NfruDeviceNearness(LoadInputDepthTm1(uv_m1_mv)),nCur=NfruDeviceNearness(LoadInputDepthTp1(uv_p1_mv));
            if((cbFI._NfruT2Flags&16384u)!=0u&&nCur>nPrev+0.08){params=FFX_MIN16_F4(1.0,0.0,0.0,0.0);forced=true;}
            else if((cbFI._NfruT2Flags&32768u)!=0u&&nPrev>nCur+0.08){params=FFX_MIN16_F4(0.0,1.0,0.0,0.0);forced=true;}
        }
        if(forced){}
        else if((cbFI._NfruT2Flags&16384u)!=0u&&params.y>FFX_MIN16_F(0.01)&&NfruInside(uv_p1_mv)){
            const float s=source>=0.0?source-bias:NfruBackgroundNearness(uv_p1_mv,false);
            if(NfruDeviceQ(LoadInputDepthTp1(uv_p1_mv))>NfruNearnessThresholdQ(s+0.08))keepEnd.y=FFX_MIN16_F(0.0);
        }
        if(!forced&&source>=0.0&&(cbFI._NfruT2Flags&32768u)!=0u&&params.x>FFX_MIN16_F(0.01)&&NfruInside(uv_m1_mv)){
            const float s=source>=0.0?source-bias:NfruBackgroundNearness(uv_m1_mv,true);
            if(NfruDeviceQ(LoadInputDepthTm1(uv_m1_mv))>NfruNearnessThresholdQ(s+0.08))keepEnd.x=FFX_MIN16_F(0.0);
        }
                                                                                                                         
        if(!forced&&source>=0.0){
            const float sq=NfruNearnessThresholdQ(source-bias+0.08);
            if((cbFI._NfruT2Flags&16384u)!=0u&&params.w>FFX_MIN16_F(0.01)&&NfruInside(uv_p1_flow)&&NfruDeviceQ(LoadInputDepthTp1(uv_p1_flow))>sq)keepEnd.w=FFX_MIN16_F(0.0);
            if((cbFI._NfruT2Flags&32768u)!=0u&&params.z>FFX_MIN16_F(0.01)&&NfruInside(uv_m1_flow)&&NfruDeviceQ(LoadInputDepthTm1(uv_m1_flow))>sq)keepEnd.z=FFX_MIN16_F(0.0);
        }
        if(any(lessThan(keepEnd,FFX_MIN16_F4(1.0)))){
            FFX_MIN16_F4 kept=params*keepEnd;
            FFX_MIN16_F keptMass=dot(kept,FFX_MIN16_F4(1.0));
            if(keptMass>FFX_MIN16_F(0.0))params=kept/keptMass;
                                                                                              
            else if(keepEnd.y==FFX_MIN16_F(0.0)&&keepEnd.x>FFX_MIN16_F(0.0)&&NfruInside(uv_m1_mv))params=FFX_MIN16_F4(1.0,0.0,0.0,0.0);
            else if(keepEnd.x==FFX_MIN16_F(0.0)&&keepEnd.y>FFX_MIN16_F(0.0)&&NfruInside(uv_p1_mv))params=FFX_MIN16_F4(0.0,1.0,0.0,0.0);
        }
    }
#endif
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1)
                                                                                                                
                                                                                                                   
                                                                                                  
    if((cbFI._pad0&0x8000u)!=0u&&!fallbackCurrent){
        FFX_MIN16_F4 keep=FFX_MIN16_F4(1.0);
                                                               
                                                                                                                
        const bool usesPrevMv=params.x>FFX_MIN16_F(0.01), usesCurMv=params.y>FFX_MIN16_F(0.01);
        const bool usesMv=usesPrevMv||usesCurMv, usesOf=params.z+params.w>FFX_MIN16_F(0.02);
#if !defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_MOTION_QDATA_TP1)
                                                                                                                      
        if(usesMv&&NfruInside(uv_m1_mv)&&NfruInside(uv_p1_mv)&&NfruPairDepthConfidence(uv_m1_mv,uv_p1_mv)<0.5){
            float zm=abs(ConvertFromDeviceDepthToViewSpace(LoadInputDepthTm1(uv_m1_mv)));
            float zp=abs(ConvertFromDeviceDepthToViewSpace(LoadInputDepthTp1(uv_p1_mv)));
            if(zm<zp)keep.x=FFX_MIN16_F(0.0);else keep.y=FFX_MIN16_F(0.0);
        }
#endif
        if(usesOf&&NfruInside(uv_m1_flow)&&NfruInside(uv_p1_flow)&&NfruPairDepthConfidence(uv_m1_flow,uv_p1_flow)<0.5){
            float zm=abs(ConvertFromDeviceDepthToViewSpace(LoadInputDepthTm1(uv_m1_flow)));
            float zp=abs(ConvertFromDeviceDepthToViewSpace(LoadInputDepthTp1(uv_p1_flow)));
            if(zm<zp)keep.z=FFX_MIN16_F(0.0);else keep.w=FFX_MIN16_F(0.0);
        }
                                                                                                                    
                                                                                                                  
                                                                                                           
        bool mvPrev=mvValid&&NfruInside(uv_m1_mv),mvCur=mvValid&&NfruInside(uv_p1_mv);
        bool ofPrev=flowValid&&NfruInside(uv_m1_flow),ofCur=flowValid&&NfruInside(uv_p1_flow);
        if(ofPrev!=ofCur&&(mvPrev||mvCur)){keep.z=FFX_MIN16_F(0.0);keep.w=FFX_MIN16_F(0.0);}
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_MOTION_QDATA_TP1)
                                                                                                                  
                                                                                                                
                                                   
        const bool checkPrev=mvPrev&&usesPrevMv, checkCur=mvCur&&usesCurMv;
        if(checkPrev||checkCur){
            float source=NfruSourceNearness(iMvCoord);
                                                                                                                     
                                                                                                                       
                                                                                                                        
                                                  
            holeDebug=float3(source<0.0?0.0:source-((cbFI._NfruT2Flags&64u)!=0u?FFX_ARM_FRAMEINTERPOLATION_FAR_PLANE_DEPTH_BIAS:0.0),NfruDeviceNearness(LoadInputDepthTm1(uv_m1_mv)),NfruDeviceNearness(LoadInputDepthTp1(uv_p1_mv)));
            if(source<0.0&&checkPrev&&checkCur){
                const float nPrev=NfruDeviceNearness(LoadInputDepthTm1(uv_m1_mv)),nCur=NfruDeviceNearness(LoadInputDepthTp1(uv_p1_mv));
                if(nPrev>nCur+0.08)keep.x=FFX_MIN16_F(0.0);
                else if(nCur>nPrev+0.08)keep.y=FFX_MIN16_F(0.0);
            }
                                                                                                                      
                                                                                                                       
            const float bias=(cbFI._NfruT2Flags&64u)!=0u?FFX_ARM_FRAMEINTERPOLATION_FAR_PLANE_DEPTH_BIAS:0.0;
            float sourcePrev=source>=0.0?source-bias:(checkPrev?NfruBackgroundNearness(uv_m1_mv,true):0.0);
            float sourceCur=source>=0.0?source-bias:(checkCur?NfruBackgroundNearness(uv_p1_mv,false):0.0);
                                                                                      
            const float qPrev=checkPrev?NfruDeviceQ(LoadInputDepthTm1(uv_m1_mv)):0.0,qCur=checkCur?NfruDeviceQ(LoadInputDepthTp1(uv_p1_mv)):0.0;
            if(checkPrev&&qPrev>NfruNearnessThresholdQ(sourcePrev+0.08))keep.x=FFX_MIN16_F(0.0);
            if(checkCur&&qCur>NfruNearnessThresholdQ(sourceCur+0.08))keep.y=FFX_MIN16_F(0.0);
                                                                                                                   
                                                                                                                  
                                                                                                                    
            if((cbFI._NfruT2Flags&128u)!=0u&&source>=0.0){
                if(checkPrev&&qPrev<NfruNearnessThresholdQ(sourcePrev-0.04))keep.x=FFX_MIN16_F(0.0);
                if(checkCur&&qCur<NfruNearnessThresholdQ(sourceCur-0.04))keep.y=FFX_MIN16_F(0.0);
            }
        }
                                                                                                                    
                                                                                                                     
                                                                                                                    
                                                                                             
                                                                                                                              
        if((cbFI._NfruT2Flags&16u)!=0u&&usesOf&&(ofPrev||ofCur)){
            const float source=NfruSourceNearness(iMvCoord);
            if(source>=0.0){
                const float threshold=NfruNearnessThresholdQ(source-FFX_ARM_FRAMEINTERPOLATION_FAR_PLANE_DEPTH_BIAS+0.08);
                if(ofPrev&&NfruDeviceQ(LoadInputDepthTm1(uv_m1_flow))>threshold)keep.z=FFX_MIN16_F(0.0);
                if(ofCur&&NfruDeviceQ(LoadInputDepthTp1(uv_p1_flow))>threshold)keep.w=FFX_MIN16_F(0.0);
            }
        }
#endif
                                                                                                                  
                                                                                                                   
                                                                                                               
        if(mvPrev!=mvCur&&(mvPrev?usesPrevMv:usesCurMv)&&(cbFI._NfruT2Flags&8192u)==0u){
            float2 end=mvPrev?uv_m1_mv:uv_p1_mv, other=mvPrev?uv_p1_mv:uv_m1_mv;
            float2 d=NfruCameraDisp(end,mvPrev?LoadInputDepthTm1(end):LoadInputDepthTp1(end),mvPrev?GetMotionTM1ToTP1():GetMotionTP1ToTM1());
            float err=length((end+d-other)*float2(displaySize)), tol=0.1*length(d*float2(displaySize))+8.0;
            if(!(err<=tol)){if(mvPrev)keep.x=FFX_MIN16_F(0.0);else keep.y=FFX_MIN16_F(0.0);}
        }
        FFX_MIN16_F4 kept=params*keep;
        FFX_MIN16_F keptMass=dot(kept,FFX_MIN16_F4(1.0));
        if(keptMass>FFX_MIN16_F(0.0))params=kept/keptMass;
                                                                                                 
        else if(any(lessThan(keep,FFX_MIN16_F4(1.0)))){params=FFX_MIN16_F4(0.0);fallbackCurrent=true;NfruDiagAdd(57u);}
    }
#endif

    float depthConfidence=1.0,cycleConfidence=1.0,ofConfidence=1.0;
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1)
    uint confidenceMode=(cbFI._pad0>>24u)&31u;
    uint confidenceView=(cbFI._pad0>>16u)&255u;
    if(confidenceMode!=0u||confidenceView==12u||confidenceView==13u){
        depthConfidence=NfruPairDepthConfidence(uv_m1_flow,uv_p1_flow);
        float cycleError=1e6;
        if(NfruInside(uv_p1_flow))cycleError=length((float2(flow_t_f30_p1)+float2(LoadInputMotionTp1(uv_p1_flow)))*float2(displaySize));
                                                                                            
                                                                                        
        cycleConfidence=1.0-smoothstep(2.0,8.0,cycleError);
        if((confidenceMode&1u)!=0u)ofConfidence*=depthConfidence;
        if((confidenceMode&2u)!=0u)ofConfidence*=cycleConfidence;
        if((confidenceMode&4u)!=0u){
                                                                                                     
            float ofError=length(float3(rgb_m1_warp_t_flow)-float3(rgb_p1_warp_t_flow));
            float mvError=length(float3(rgb_m1_warp_t_mv)-float3(rgb_p1_warp_t_mv));
            ofConfidence*=1.0-smoothstep(0.02,0.12,max(0.0,ofError-mvError));
        }
        if((confidenceMode&8u)!=0u){
            float mvError=length(float3(rgb_m1_warp_t_mv)-float3(rgb_p1_warp_t_mv));
            float mvReliability=1.0-smoothstep(0.03,0.15,mvError);
            ofConfidence=mix(1.0,ofConfidence,mvReliability);
        }
                                                                                   
                                                                            
        if((confidenceMode&16u)!=0u&&length(float2(mv_t_f30_m1)*float2(displaySize))<0.25)ofConfidence=1.0;
                                                                                                
                                                                            
        if(confidenceMode!=0u&&mvValid&&NfruInside(uv_m1_mv)&&NfruInside(uv_p1_mv)){
            float mvMass=float(params.x+params.y),ofMass=float(params.z+params.w);
            float rejected=ofMass*(1.0-ofConfidence);
            float previousRatio=mvMass>1e-5?float(params.x)/mvMass:1.0-timestep;
            params.x+=FFX_MIN16_F(rejected*previousRatio);
            params.y+=FFX_MIN16_F(rejected*(1.0-previousRatio));
            params.zw*=FFX_MIN16_F(ofConfidence);
        }
    }
#endif

                       
    FFX_MIN16_F3 rgb_t = FFX_MIN16_F3(0.HF);
    rgb_t += rgb_m1_warp_t_mv * params.x;
    rgb_t += rgb_p1_warp_t_mv * params.y;
    rgb_t += rgb_m1_warp_t_flow * params.z;
    rgb_t += rgb_p1_warp_t_flow * params.w;
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1)
                                                                                                                    
                                                                                                  
    if(layers&&lockedCoverage>0.0){
        const float2 m=float2(LoadInputMotionTp1(uv));
        const FFX_MIN16_F3 lockedPrev=SamplePreviousBackbuffer(NfruMoveFrom(uvSpace,m,timestep));
        const FFX_MIN16_F3 lockedCur=SampleCurrentBackbuffer(NfruMoveFrom(uvSpace,m,-(1.0f-timestep)));
        const FFX_MIN16_F3 lockedColour=mix(lockedPrev,lockedCur,FFX_MIN16_F(timestep));
        rgb_t=mix(rgb_t,lockedColour,FFX_MIN16_F(lockedCoverage));
    }
#endif

    if(fallbackCurrent){
        rgb_t=LoadCurrentBackbuffer(output_pixel);
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_COLOUR_M2) && defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TM1)
                                                                                                                 
                                                                                                            
                                                                                                                   
                                                                                                                  
        if((cbFI._NfruT2Flags&1u)!=0u&&mvValid){
            float2 pm1=uv_m1_mv;
            float dBg=LoadInputDepthTm1(pm1);
                                                                                           
            for(int k=0;k<24;++k){
                float a=float(k&7)*0.7853982;
                float2 ring=float((k>>3)==0?16:((k>>3)==1?48:96))*MvDepthLaneSizeRcp();
                float d=LoadInputDepthTm1(clamp(pm1+ring*float2(cos(a),sin(a)),float2(0.0),float2(1.0)));
#if FFX_ARM_FRAMEINTERPOLATION_OPTION_INVERTED_DEPTH
                dBg=min(dBg,d);
#else
                dBg=max(dBg,d);
#endif
            }
            float2 pm2=pm1+NfruCameraDisp(pm1,dBg,cbFI._MotionTM1ToTM2);
            if(NfruInside(pm2)){
                float zExpected=abs(ConvertFromDeviceDepthToViewSpace(dBg));
                float zFound=abs(ConvertFromDeviceDepthToViewSpace(LoadDepthM2(pm2)));
                if(abs(zFound-zExpected)<=0.2*max(zFound,zExpected)){
                    rgb_t=FFX_MIN16_F3(LoadColourM2(pm2));
                    NfruDiagAdd(19u);
                }else NfruDiagAdd(21u);
            }else NfruDiagAdd(21u);
        }
#endif
    }

#ifdef NFRU_BIREPROJ_AVAILABLE
                                                                                                                      
    float nfruBiConf = 1.0;
    const bool nfruBi = (cbFI._NfruT2Flags & 2097152u) != 0u;
    if (nfruBi) rgb_t = FFX_MIN16_F3(NfruBireproj(uv, timestep, float2(displaySize), (cbFI._pad0 >> 16u) & 0xffu, nfruBiConf));
#endif
    bool diagnosticHudPixel=false;
    uint diagnosticView=(cbFI._pad0 >> 16u) & 0xffu;

                                                                              
                                                                              
                                                                               
    if ((cbFI._pad0 & 0xffu) != 0u) {
        float3 fullColor = LoadPresentBackbuffer(output_pixel).rgb;
        float3 sceneColor = texelFetch(r_current_interpolation_source, output_pixel, 0).rgb;
        float3 delta = abs(fullColor - sceneColor);
                                                                          
                                                                          
                                                                             
                                                                             
        float3 tolerance = (cbFI._pad0 & 0xffu) == 2u ?
            abs(sceneColor) * float3(1.0f/64.0f, 1.0f/64.0f, 1.0f/32.0f) + float3(1.0f/255.0f) :
            float3(1.0f/4096.0f);
        diagnosticHudPixel=any(greaterThan(delta,tolerance));
        if (diagnosticHudPixel)
            rgb_t = FFX_MIN16_F3(fullColor);
    }
    NfruDiagAdd(20u);

                                                                                     
    if(diagnosticView==1u) rgb_t=mix(rgb_m1_warp_t_mv,rgb_p1_warp_t_mv,FFX_MIN16_F(timestep));
    else if(diagnosticView==2u) rgb_t=mix(rgb_m1_warp_t_flow,rgb_p1_warp_t_flow,FFX_MIN16_F(timestep));
    else if(diagnosticView==3u) rgb_t=FFX_MIN16_F3(diagnosticHudPixel?1.0f:0.0f);
    else if(diagnosticView==4u) rgb_t=FFX_MIN16_F3(float2(mv_t_f30_m1)*float2(displaySize)/64.0+0.5,0.0);
    else if(diagnosticView==5u) rgb_t=FFX_MIN16_F3(float2(flow_t_f30_p1)*float2(displaySize)/64.0+0.5,0.0);
    else if(diagnosticView==6u) rgb_t=FFX_MIN16_F3(params.x,params.y,params.z+params.w);
    else if(diagnosticView==7u) rgb_t=LoadCurrentBackbuffer(output_pixel);
    else if(diagnosticView==8u) rgb_t=SamplePreviousBackbuffer(uv);
                                                                                                                          
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_DEPTH_TP1)
    else if(diagnosticView==12u) rgb_t=FFX_MIN16_F3(NfruDeviceNearness(LoadInputDepthTp1(uv)),NfruDeviceNearness(LoadInputDepthTm1(uv)),0.0);
#endif
    else if(diagnosticView==13u) rgb_t=FFX_MIN16_F3(rgb_m1_warp_t_flow);
                                                                                                
    else if(diagnosticView==20u) rgb_t=FFX_MIN16_F3(rgb_m1_warp_t_mv);
    else if(diagnosticView==21u) rgb_t=FFX_MIN16_F3(rgb_p1_warp_t_mv);
    else if(diagnosticView==22u) rgb_t=FFX_MIN16_F3(rgb_p1_warp_t_flow);
    else if(diagnosticView==18u) rgb_t=FFX_MIN16_F3(edgeDebug);
    else if(diagnosticView==19u) rgb_t=FFX_MIN16_F3(guardDebug);
    else if(diagnosticView==23u) rgb_t=FFX_MIN16_F3(holeDebug);
#ifdef NFRU_DIAG_BINDING
                                                                                                               
    else if(diagnosticView==24u){
        const uint cb=NfruFlowMetaOffset()+uint(FlowLaneSize().x*FlowLaneSize().y);
        const float n=float(rw_nfru_diagnostics.counts[cb+35u]);
        rgb_t=FFX_MIN16_F3(rw_nfru_diagnostics.counts[cb+32u]==1u?1.0:0.0,clamp(uintBitsToFloat(rw_nfru_diagnostics.counts[cb+33u])*0.5,0.0,1.0),
                           n>0.0?float(rw_nfru_diagnostics.counts[cb+34u])/n:0.0);
    }
#endif


#ifdef NFRU_DIAG_BINDING
    if(diagnosticView>=9u&&diagnosticView<=11u){
        uint meta=rw_nfru_diagnostics.counts[64u+uint(iMvCoord.y*MvDepthLaneSize().x+iMvCoord.x)];
        float3 colors[8]=float3[8](float3(.08),float3(0,.8,0),float3(0,1,1),float3(0,.3,1),float3(1,1,0),float3(1,0,1),float3(1,0,0),float3(1,1,1));
        uint reason=meta&15u;
        rgb_t=FFX_MIN16_F3(colors[min(reason,7u)]);
        if(diagnosticView==10u){
            float3 color=(meta&32u)!=0u?float3(1,0,0):((meta&16u)!=0u?float3(1,1,0):((meta&64u)!=0u?float3(0,1,1):float3(.08)));
            rgb_t=FFX_MIN16_F3(color);
        } else if(diagnosticView==11u){
            uint cam=(meta>>8u)&15u,of=(meta>>12u)&15u;
            float3 color=float3(.08);
            if(reason==2u||reason==3u)color=colors[reason];
            else if(cam==3u&&of==3u)color=float3(1,1,1);
            else if(cam==3u)color=float3(1,0,1);
            else if(of==3u)color=float3(1,1,0);
            else if(cam==4u||of==4u)color=float3(1,0,0);
            else if(cam==1u||of==1u)color=float3(1,.5,0);
            else if(reason==1u)color=float3(0,.8,0);
            rgb_t=FFX_MIN16_F3(color);
        }
    }
#endif
                                    
    FFX_MIN16_F4 diagnosticOutput=FFX_MIN16_F4(rgb_t,1.0f);
#if defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_INPUT_FLOW_TM1) && defined(FFX_ARM_FRAMEINTERPOLATION_BIND_SRV_WARP_FLOW_QDATA_TM1)
                                                                            
                                                                             
    if(diagnosticView>=14u&&diagnosticView<=16u){
        float2 fieldPixels;
        if(diagnosticView==14u){
            int32_t2 rawCoord=clamp(int32_t2(floor(uv*float2(textureSize(r_flow_tm1,0)))),int32_t2(0),textureSize(r_flow_tm1,0)-1);
            fieldPixels=texelFetch(r_flow_tm1,rawCoord,0).xy;
        }else if(diagnosticView==16u){
            fieldPixels=dqFloatMv(LoadWarpedFlowQDataTM1(iFlowCoord))*FlowLaneSizeRcp()*float2(displaySize);
        }else fieldPixels=float2(flow_t_f30_p1)*float2(displaySize);
        uvec2 packed=uvec2(clamp(round(fieldPixels*2.0)+2048.0,float2(0),float2(4095)));
        diagnosticOutput=FFX_MIN16_F4(float4(packed.x&255u,(packed.x>>8u)|((packed.y&15u)<<4u),packed.y>>4u,255u)/255.0);
    }else if(diagnosticView==17u){
        diagnosticOutput=FFX_MIN16_F4(LoadWarpedFlowQDataTM1(iFlowCoord)!=0u?1.0:0.0,flowValid?1.0:0.0,0.0,1.0);
    }
#endif
    StoreFrameinterpolationOutput(output_pixel, diagnosticOutput);
#ifdef NFRU_BIREPROJ_AVAILABLE
                                                                                  
    if (nfruBi) NfruBiStore(output_pixel, displaySize, float3(diagnosticOutput.rgb), (diagnosticHudPixel || diagnosticView != 0u) ? 2.0 : nfruBiConf);
#endif
#ifdef NFRU_SELECT_BINDING
                                                                                                              
    if((cbFI._NfruT2Flags&256u)!=0u){
        const uint base=(uint(output_pixel.y)*uint(displaySize.x)+uint(output_pixel.x))*6u;
        rw_nfru_select.cand[base+0u]=NfruPackR11G11B10(float3(rgb_m1_warp_t_mv));
        rw_nfru_select.cand[base+1u]=NfruPackR11G11B10(float3(rgb_p1_warp_t_mv));
        rw_nfru_select.cand[base+2u]=NfruPackR11G11B10(float3(rgb_m1_warp_t_flow));
        rw_nfru_select.cand[base+3u]=NfruPackR11G11B10(float3(rgb_p1_warp_t_flow));
        rw_nfru_select.cand[base+4u]=NfruPackR11G11B10(float3(LoadCurrentBackbuffer(output_pixel)));
                                                                   
        rw_nfru_select.cand[base+5u]=(diagnosticHudPixel||diagnosticView!=0u)?0xffffffffu:NfruPackR11G11B10(float3(diagnosticOutput.rgb));
    }
#endif

                                                                                  
                                                                                  
                                                                    
#if FFX_ARM_FRAMEINTERPOLATION_OPTION_MANAGE_PREVIOUS_COLOR
                                                                                                            
    if ((cbFI._NfruT2Flags & 4u) == 0u)
        StorePreviousInterpolationSource(output_pixel, FFX_MIN16_F4(LoadCurrentBackbuffer(output_pixel), 1.0f));
#endif
}

#endif