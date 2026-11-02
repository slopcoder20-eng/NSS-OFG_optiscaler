#include <framegen/nfru/SubmittedRateTracker.h>
#include <cmath>
#include <cstdio>
int main(){SubmittedRateTracker r;for(unsigned n=1;n<=4;++n){r.Reset();for(int i=0;i<=10;++i)r.Record(i*10,n);auto x=r.Rates(100);if(std::abs(x.first-100)>0.001||std::abs(x.second-100*n)>0.001)return 1;}r.Reset();for(int i=0;i<=10;++i)r.Record(i*10,i<5?4:2);auto x=r.Rates(100);if(std::abs(x.first-100)>0.001||std::abs(x.second-280)>0.001)return 2;if(r.Rates(700).first!=0)return 3;r.Record(1,4);if(r.Rates(1).first!=0)return 4;puts("SUBMITTED_RATES_PASS: independent base/output; 1x/2x/3x/4x; mixed multipliers; stale and reset clocks");}
