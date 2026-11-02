#ifndef NFRU_ZERO_MV_REPAIR_H
#define NFRU_ZERO_MV_REPAIR_H
#include "nfru_angular.h"
                                                                             
                                                                           
float NfruPatchError(float2 a, float2 b)
{
    float total=0.0;
    const int32_t2 taps[5]=int32_t2[5](int32_t2(0),int32_t2(1,0),int32_t2(-1,0),int32_t2(0,1),int32_t2(0,-1));
    for(int i=0;i<5;++i) {
        float2 offset=float2(taps[i])*MvDepthLaneSizeRcp();
        float3 previous=float3(SamplePreviousBackbuffer(a+offset));
        float3 current=float3(SampleCurrentBackbuffer(b+offset));
        total+=dot(abs(previous-current),float3(1.0/3.0));
    }
    return total/5.0;
}
bool NfruPatchOnScreen(float2 a,float2 b)
{
    float2 margin=MvDepthLaneSizeRcp();
    return all(greaterThan(a,margin))&&all(lessThan(a,1.0-margin))&&
           all(greaterThan(b,margin))&&all(lessThan(b,1.0-margin));
}
                                                                                                         
                                                                                                           
float2 NfruCameraDisplacement(float2 p,mat4 motion,out bool ok)
{
    float2 pT=float2(p.x,1.0-p.y);
    float4 r=motion*float4(2.0*pT-1.0,LoadInputDepthTp1(p),1.0);
    ok=r.w>1e-6;
    if(!ok)return float2(0.0);
    float2 q=(r.xy/r.w+1.0)*0.5;
    float2 d=float2(q.x-pT.x,pT.y-q.y);
    ok=!(any(isnan(d))||any(isinf(d)));
    return ok?d:float2(0.0);
}
                                                                                                                      
float2 NfruSplatTarget(float2 x, float2 d, float s) { return NfruMove(x, NfruVec(x, x + d), s); }
                                                                                                              
                                                                                            
                                                                                                            
uint NfruSolveSplatSource(float2 uv,mat4 motion,float s,out float2 x,out float2 d)
{
    bool ok;
    d=NfruCameraDisplacement(uv,motion,ok);
    if(!ok)return 3u;
    x=uv-s*d;
    float2 h=MvDepthLaneSizeRcp();
    for(int i=0;i<8;++i){
                                                                                                         
        x=clamp(x,float2(-1.0),float2(2.0));
        bool okx,oky;
        d=NfruCameraDisplacement(x,motion,ok);
        float2 dx=NfruCameraDisplacement(x+float2(h.x,0.0),motion,okx);
        float2 dy=NfruCameraDisplacement(x+float2(0.0,h.y),motion,oky);
        if(!(ok&&okx&&oky))return 3u;
        float2 g=NfruSplatTarget(x,d,s);
        float2 r=g-uv;
        if(length(r*float2(MvDepthLaneSize()))<0.25)break;
                                                         
        float2 c0=(NfruSplatTarget(x+float2(h.x,0.0),dx,s)-g)/h.x;
        float2 c1=(NfruSplatTarget(x+float2(0.0,h.y),dy,s)-g)/h.y;
        float det=c0.x*c1.y-c1.x*c0.y;
        if(abs(det)<1e-4)return 3u;
        x-=float2(c1.y*r.x-c1.x*r.y,-c0.y*r.x+c0.x*r.y)/det;
    }
    d=NfruCameraDisplacement(x,motion,ok);
    if(!ok)return 3u;
    if(length((NfruSplatTarget(x,d,s)-uv)*float2(MvDepthLaneSize()))>=0.5)return 2u;
    float2 margin=MvDepthLaneSizeRcp();
    return all(greaterThan(x,margin))&&all(lessThan(x,1.0-margin))?0u:1u;
}
FFX_MIN16_F2 NfruRepairZeroMotionDetailed(float2 uv,FFX_MIN16_F2 original,FFX_MIN16_F2 forwardFlow,out uint reason)
{
    nfruCandidateFlags=0u;
    reason=0u;
                                                                                                         
                                                                                              
                                                                                                              
                                         
    if((cbFI._pad0&0x20000000u)!=0u&&(nfruHoleFlags&32u)!=0u&&(cbFI._NfruT2Flags&2u)==0u){
        float2 x,d;
        float t=Timestep();
                                                                                                                    
                                               
        uint rc=NfruSolveSplatSource(uv,GetMotionTP1ToTM1(),1.0-t,x,d);
        if(rc==0u){NfruDiagAdd(1u);reason=2u;return FFX_MIN16_F2(NfruVec(x,x+d));}
        uint rp=NfruSolveSplatSource(uv,GetMotionTM1ToTP1(),t,x,d);
        if(rp==0u){NfruDiagAdd(2u);reason=2u;return FFX_MIN16_F2(-NfruVec(x,x+d));}
        NfruDiagAdd(5u);
        if(rp==1u)NfruDiagAdd(29u);else if(rp==2u)NfruDiagAdd(62u);
    }
    if(length(float2(original)*float2(DisplaySize()))>0.25) return original;
    NfruDiagAdd(54u);if(all(equal(original,FFX_MIN16_F2(0.0))))NfruDiagAdd(53u);
    reason=1u;
    float stationary=NfruPatchError(uv,uv);
    if(stationary<0.02) return original;
    float2 uvT=float2(uv.x,1.0-uv.y);
    float4 clip=float4(uvT*2.0-1.0,LoadInputDepthTp1(uv),1.0);
    float4 previous=GetMotionTP1ToTM1()*clip;
    float2 camera=float2(0.0);
    if(previous.w>1e-6) {
        float2 reprojected=(previous.xy/previous.w+1.0)*0.5;
        camera=float2(reprojected.x-uvT.x,uvT.y-reprojected.y);
    }
    if(!(previous.w>1e-6))NfruDiagAdd(52u);
    camera=NfruVec(uv,uv+camera);
                                                                                   
    if((cbFI._NfruT2Flags&8192u)!=0u)camera=float2(0.0);
    float2 candidates[2]=float2[2](camera,-float2(forwardFlow));
    float best=stationary; float2 motion=float2(original);
    bool invalid=false,moving=false,onScreen=false,tested=false;uint winner=0u;
    for(int i=0;i<2;++i) {
        uint base=i==0?32u:42u;uint stateShift=i==0?8u:12u;
        NfruDiagAdd(base);
        float2 candidate=candidates[i];
        if(any(isnan(candidate))||any(isinf(candidate))){NfruDiagAdd(base+1u);nfruCandidateFlags|=1u<<stateShift;invalid=true;continue;}
        float candidatePixels=length(candidate*float2(DisplaySize()));
        if(candidatePixels<1.0){NfruDiagAdd(base+2u);nfruCandidateFlags|=2u<<stateShift;continue;}
        if(candidatePixels>256.0)NfruDiagAdd(base+8u);
        if(candidatePixels>float(max(DisplaySize().x,DisplaySize().y)))NfruDiagAdd(base+9u);
        moving=true;
        float2 a=NfruMove(uv,candidate,Timestep()),b=NfruMove(uv,candidate,-(1.0-Timestep()));
        if(!NfruPatchOnScreen(a,b)){NfruDiagAdd(base+3u);nfruCandidateFlags|=3u<<stateShift;continue;}
        NfruDiagAdd(base+4u);onScreen=true;tested=true;
        float error=NfruPatchError(a,b);
        if(error<best && error<stationary*0.6 && stationary-error>0.02 && error<0.12) {
            NfruDiagAdd(base+6u);nfruCandidateFlags|=5u<<stateShift;
            best=error;motion=candidate;winner=uint(i)+2u;
        } else {NfruDiagAdd(base+5u);nfruCandidateFlags|=4u<<stateShift;}
    }
    if(winner==2u)NfruDiagAdd(39u);else if(winner==3u)NfruDiagAdd(49u);
    reason=winner!=0u?winner:(!moving?(invalid?7u:4u):(!onScreen?5u:6u));
    return FFX_MIN16_F2(motion);
}
FFX_MIN16_F2 NfruRepairZeroMotion(float2 uv,FFX_MIN16_F2 original,FFX_MIN16_F2 forwardFlow){uint reason;return NfruRepairZeroMotionDetailed(uv,original,forwardFlow,reason);}

#endif
