#pragma once
#include <cmath>
#include <algorithm>

                                                                          
                                                                                
                                                                                    
inline bool NfruBuildCameraViewProjection(const float projection[16], const float position[3],
    const float right[3], const float up[3], const float forward[3], const float origin[3], float out[16])
{
    for(int i=0;i<16;++i) if(!std::isfinite(projection[i])) return false;
    if(std::abs(projection[0])<1e-6f || std::abs(projection[5])<1e-6f ||
       std::abs(std::abs(projection[11])-1.0f)>1e-3f || std::abs(projection[15])>1e-5f)
        return false;                                                              
    float basis[3][3]; const float* input[3]={right,up,forward};
    for(int r=0;r<3;++r){
        double len=0;
        for(int c=0;c<3;++c){if(!std::isfinite(input[r][c]) || !std::isfinite(position[c]) || !std::isfinite(origin[c])) return false;len+=double(input[r][c])*input[r][c];}
        if(len<0.25 || len>4.0) return false;
        for(int c=0;c<3;++c) basis[r][c]=float(input[r][c]/std::sqrt(len));
    }
    for(int r=0;r<3;++r)for(int t=r+1;t<3;++t){
        float dot=0;for(int c=0;c<3;++c)dot+=basis[r][c]*basis[t][c];if(std::abs(dot)>0.02f)return false;
    }
    float view[16]={};view[15]=1;
    for(int r=0;r<3;++r){
        double translation=0;
        for(int c=0;c<3;++c){view[c*4+r]=basis[r][c];translation-=double(basis[r][c])*(double(position[c])-origin[c]);}
        view[12+r]=float(translation);
    }
    for(int col=0;col<4;++col)for(int row=0;row<4;++row){
        double sum=0;for(int k=0;k<4;++k)sum+=double(projection[k*4+row])*view[col*4+k];
        out[col*4+row]=float(sum);if(!std::isfinite(out[col*4+row]))return false;
    }
    return true;
}
