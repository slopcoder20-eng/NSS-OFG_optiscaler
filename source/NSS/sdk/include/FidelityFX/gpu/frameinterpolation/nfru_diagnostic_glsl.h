#ifndef NFRU_DIAGNOSTIC_GLSL
#define NFRU_DIAGNOSTIC_GLSL
#ifdef NFRU_DIAG_BINDING
layout(set=0,binding=NFRU_DIAG_BINDING,std430) buffer NfruDiag { uint counts[]; } rw_nfru_diagnostics;
void NfruDiagAdd(uint counter){if((cbFI._pad0 & 0x200u)!=0u)atomicAdd(rw_nfru_diagnostics.counts[counter],1u);}
uint nfruHoleFlags=0u;uint nfruCandidateFlags=0u;
void NfruDiagReason(ivec2 p,uint reason){NfruDiagAdd(6u);NfruDiagAdd(7u+reason);if((nfruHoleFlags&32u)!=0u){NfruDiagAdd(reason==2u||reason==3u?30u:31u);}
uint view=(cbFI._pad0>>16u)&255u;if((cbFI._pad0&0x400u)!=0u||view>=9u&&view<=11u){
    bool valid=(nfruHoleFlags&32u)==0u||reason==2u||reason==3u;
    rw_nfru_diagnostics.counts[64u+uint(p.y*MvDepthLaneSize().x+p.x)]=reason|nfruHoleFlags|nfruCandidateFlags|(valid?65536u:0u);
}}
bool NfruHoleGuardEnabled(){return (cbFI._pad0&0x400u)!=0u;}
uint NfruFlowMetaOffset(){return 64u+uint(MvDepthLaneSize().x*MvDepthLaneSize().y);}
bool NfruMotionValid(ivec2 p){return !NfruHoleGuardEnabled()||(rw_nfru_diagnostics.counts[64u+uint(p.y*MvDepthLaneSize().x+p.x)]&65536u)!=0u;}
bool NfruFlowValid(ivec2 p){return !NfruHoleGuardEnabled()||rw_nfru_diagnostics.counts[NfruFlowMetaOffset()+uint(p.y*FlowLaneSize().x+p.x)]!=0u;}
void NfruStoreFlowValidity(ivec2 p,bool valid){if(NfruHoleGuardEnabled())rw_nfru_diagnostics.counts[NfruFlowMetaOffset()+uint(p.y*FlowLaneSize().x+p.x)]=valid?1u:0u;}
                                                                                                                      
bool NfruFittedMotion(uint which,out FfxFloat32x4x4 m)
{
    m=FfxFloat32x4x4(1.0);
    if((cbFI._NfruT2Flags&524288u)==0u)return false;
    const uint base=NfruFlowMetaOffset()+uint(FlowLaneSize().x*FlowLaneSize().y);
    if(rw_nfru_diagnostics.counts[base+32u]!=1u)return false;
    for(uint c=0u;c<4u;++c)for(uint r=0u;r<4u;++r)m[c][r]=uintBitsToFloat(rw_nfru_diagnostics.counts[base+which*16u+c*4u+r]);
    return true;
}
#else
uint nfruHoleFlags=0u;uint nfruCandidateFlags=0u;
void NfruDiagAdd(uint counter){}
void NfruDiagReason(ivec2 p,uint reason){}
bool NfruHoleGuardEnabled(){return false;}
bool NfruMotionValid(ivec2 p){return true;}
bool NfruFlowValid(ivec2 p){return true;}
void NfruStoreFlowValidity(ivec2 p,bool valid){}
#endif
#endif
