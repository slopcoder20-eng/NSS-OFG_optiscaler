#pragma once
#ifndef NFRU_STATS_CONTROL_ONLY
#include <vulkan/vulkan.h>
#endif
#include <chrono>
#include <array>
#include <cstdio>
#include <cstring>
#include "nss_env.h"
inline uint64_t nfruStatsClock(){return uint64_t(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count());}
inline bool nfruStatsEnabled(){
 const char* env=getenv("NFRU_GPU_STATS");if(env)return atoi(env)!=0;
#ifdef _WIN32
 static uint64_t last=0;static bool enabled=false;auto now=nfruStatsClock();if(last&&now-last<250)return enabled;last=now;
 HMODULE self{};wchar_t path[MAX_PATH]{};enabled=false;
 if(GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,reinterpret_cast<LPCWSTR>(&nfruStatsEnabled),&self)){
  DWORD n=GetModuleFileNameW(self,path,MAX_PATH);if(n&&n<MAX_PATH){wchar_t* p=wcsrchr(path,L'\\');if(p&&size_t(p-path)+26<MAX_PATH){wcscpy(p+1,L"nfru_stats_enabled.txt");if(FILE* f=_wfopen(path,L"rt")){int v=0;if(fscanf(f,"%d",&v)==1)enabled=v!=0;fclose(f);}}}
 }
 return enabled;
#else
 return false;
#endif
}
inline void nfruStatsLog(const char* text){
#ifdef _WIN32
 HMODULE self{};wchar_t path[MAX_PATH]{};
 if(GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,reinterpret_cast<LPCWSTR>(&nfruStatsLog),&self)){
  DWORD n=GetModuleFileNameW(self,path,MAX_PATH);if(n&&n<MAX_PATH){auto p=wcsrchr(path,L'\\');if(p&&size_t(p-path)+26<MAX_PATH){wcscpy(p+1,L"nfru_gpu_stats.log");if(FILE* f=_wfopen(path,L"at")){fputs(text,f);fputc('\n',f);fclose(f);}}}
 }
 if(auto sink=nss_trace_sink())sink(1,text);
#else
 fprintf(stderr,"%s\n",text);
#endif
}
#ifndef NFRU_STATS_CONTROL_ONLY
                                                                                      
struct NfruGpuStats {
 static constexpr uint32_t count=64,bytes=count*4;
 struct Slot {VkBuffer buffer{};VkDeviceMemory memory{};void* mapped{};bool coherent=false,busy=false;uint64_t seq=0,recordMs=0,lastTimestamp=0;uint32_t w=0,h=0;float timestep=0;};
 VkDevice dev{};VkPhysicalDevice pd{};VkQueryPool queries{};std::array<Slot,4> slots{};VkBuffer own{};VkDeviceMemory ownMemory{};uint64_t sequence=0,lastSample=0,skipped=0;bool disabled=false;
 ~NfruGpuStats(){for(auto&s:slots){if(s.mapped)vkUnmapMemory(dev,s.memory);if(s.buffer)vkDestroyBuffer(dev,s.buffer,nullptr);if(s.memory)vkFreeMemory(dev,s.memory,nullptr);}if(queries)vkDestroyQueryPool(dev,queries,nullptr);if(own)vkDestroyBuffer(dev,own,nullptr);if(ownMemory)vkFreeMemory(dev,ownMemory,nullptr);}
 bool makeBuffer(VkBuffer& b,VkDeviceMemory& m,bool host,Slot* slot=nullptr){
  VkBufferCreateInfo ci{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};ci.size=bytes;ci.usage=VK_BUFFER_USAGE_STORAGE_BUFFER_BIT|VK_BUFFER_USAGE_TRANSFER_SRC_BIT|VK_BUFFER_USAGE_TRANSFER_DST_BIT;
  if(vkCreateBuffer(dev,&ci,nullptr,&b)!=VK_SUCCESS)return false;VkMemoryRequirements req;vkGetBufferMemoryRequirements(dev,b,&req);VkPhysicalDeviceMemoryProperties mp;vkGetPhysicalDeviceMemoryProperties(pd,&mp);uint32_t type=UINT32_MAX;
  for(unsigned pass=0;pass<2&&type==UINT32_MAX;pass++)for(uint32_t i=0;i<mp.memoryTypeCount;i++){auto f=mp.memoryTypes[i].propertyFlags;VkMemoryPropertyFlags wanted=host?VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT:VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;if(pass==0&&host)wanted|=VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;if((req.memoryTypeBits&(1u<<i))&&(f&wanted)==wanted){type=i;break;}}
  if(type==UINT32_MAX)return false;VkMemoryAllocateInfo ai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};ai.allocationSize=req.size;ai.memoryTypeIndex=type;
  if(vkAllocateMemory(dev,&ai,nullptr,&m)!=VK_SUCCESS||vkBindBufferMemory(dev,b,m,0)!=VK_SUCCESS)return false;
  if(slot){slot->coherent=(mp.memoryTypes[type].propertyFlags&VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)!=0;if(vkMapMemory(dev,m,0,VK_WHOLE_SIZE,0,&slot->mapped)!=VK_SUCCESS)return false;}
  return true;
 }
 bool init(VkDevice d,VkPhysicalDevice p,bool ownBuffer=false){dev=d;pd=p;VkPhysicalDeviceProperties props;vkGetPhysicalDeviceProperties(pd,&props);if(ownBuffer&&!makeBuffer(own,ownMemory,false))return false; if(!props.limits.timestampComputeAndGraphics){disabled=true;if(nfruStatsEnabled())nfruStatsLog("[NFRU GPU stats] disabled: compute timestamps unavailable");return true;}
  VkQueryPoolCreateInfo qi{VK_STRUCTURE_TYPE_QUERY_POOL_CREATE_INFO};qi.queryType=VK_QUERY_TYPE_TIMESTAMP;qi.queryCount=4;if(vkCreateQueryPool(dev,&qi,nullptr,&queries)!=VK_SUCCESS)return false;
  for(auto&s:slots)if(!makeBuffer(s.buffer,s.memory,true,&s))return false;
  return true;
 }
 static void barrier(VkCommandBuffer cb,VkBuffer b,VkAccessFlags src,VkAccessFlags dst,VkPipelineStageFlags a,VkPipelineStageFlags z){VkBufferMemoryBarrier mb{VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER};mb.srcAccessMask=src;mb.dstAccessMask=dst;mb.srcQueueFamilyIndex=mb.dstQueueFamilyIndex=VK_QUEUE_FAMILY_IGNORED;mb.buffer=b;mb.offset=0;mb.size=bytes;vkCmdPipelineBarrier(cb,a,z,0,0,nullptr,1,&mb,0,nullptr);}
 void clear(VkCommandBuffer cb,VkBuffer source){barrier(cb,source,VK_ACCESS_SHADER_READ_BIT|VK_ACCESS_SHADER_WRITE_BIT,VK_ACCESS_TRANSFER_WRITE_BIT,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,VK_PIPELINE_STAGE_TRANSFER_BIT);vkCmdFillBuffer(cb,source,0,bytes,0);barrier(cb,source,VK_ACCESS_TRANSFER_WRITE_BIT,VK_ACCESS_SHADER_READ_BIT|VK_ACCESS_SHADER_WRITE_BIT,VK_PIPELINE_STAGE_TRANSFER_BIT,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);}
 bool due(){auto now=nfruStatsClock();if(now-lastSample<1000)return false;lastSample=now;return true;}
 void poll(const char* kind){if(disabled||!queries)return;for(unsigned i=0;i<slots.size();i++){auto&s=slots[i];if(!s.busy)continue;uint64_t data[2]{};auto result=vkGetQueryPoolResults(dev,queries,i,1,sizeof(data),data,sizeof(data),VK_QUERY_RESULT_64_BIT|VK_QUERY_RESULT_WITH_AVAILABILITY_BIT);if(result!=VK_SUCCESS||!data[1]||data[0]==s.lastTimestamp)continue;
  if(!s.coherent){VkMappedMemoryRange r{VK_STRUCTURE_TYPE_MAPPED_MEMORY_RANGE};r.memory=s.memory;r.offset=0;r.size=VK_WHOLE_SIZE;if(vkInvalidateMappedMemoryRanges(dev,1,&r)!=VK_SUCCESS)continue;}
  uint32_t c[count];memcpy(c,s.mapped,bytes);char line[1000];
  if(!strcmp(kind,"FI"))snprintf(line,sizeof(line),"[NFRU GPU stats FI] sample=%llu recorded_ms=%llu lane=%ux%u t=%.4f input_samples=%u input_zero=%u input_nearzero=%u repair_total=%u nonzero=%u stationary=%u camera=%u of=%u no_candidate=%u offscreen=%u patch_reject=%u invalid_candidate=%u hud_total=%u hud_copy=%u skipped=%llu",(unsigned long long)s.seq,(unsigned long long)s.recordMs,s.w,s.h,s.timestep,c[0],c[1],c[2],c[6],c[7],c[8],c[9],c[10],c[11],c[12],c[13],c[14],c[20],c[21],(unsigned long long)skipped);
  else snprintf(line,sizeof(line),"[NFRU GPU stats OF] sample=%llu recorded_ms=%llu grid=%ux%u total=%u game_valid=%u accepted_zero=%u game_rejected=%u final_zero=%u no_game_mv=%u skipped=%llu",(unsigned long long)s.seq,(unsigned long long)s.recordMs,s.w,s.h,c[0],c[1],c[2],c[3],c[4],c[5],(unsigned long long)skipped);
  nfruStatsLog(line);
  if(strcmp(kind,"FI")){snprintf(line,sizeof(line),"[NFRU GPU stats OFREJ] sample=%llu recorded_ms=%llu other=%u iter_offscreen=%u nan=%u final_offscreen=%u residual=%u luma=%u mv_lt8=%u mv_8_32=%u mv_ge32=%u exit_camera=%u hybrid_original=%u",(unsigned long long)s.seq,(unsigned long long)s.recordMs,c[6],c[7],c[8],c[9],c[10],c[11],c[12],c[13],c[14],c[15],c[16]);nfruStatsLog(line);}
  if(!strcmp(kind,"FI")){
    snprintf(line,sizeof(line),"[NFRU GPU stats DYN] sample=%llu recorded_ms=%llu lane_total=%u cur_dynamic=%u cur_behind_cam=%u prev_skipped=%u mv_gt4=%u ratio_lt95=%u ratio_gt105=%u angle_gt5=%u",(unsigned long long)s.seq,(unsigned long long)s.recordMs,c[0],c[15],c[16],c[17],c[18],c[19],c[62],c[63]);nfruStatsLog(line);
    snprintf(line,sizeof(line),"[NFRU GPU stats HOLES] sample=%llu recorded_ms=%llu warp_ok=%u warp_reject=%u warp_zero_packed=%u center_empty=%u all9_empty=%u all9_empty_interior=%u selected_zero=%u selected_nearzero=%u border=%u center_filled=%u all9_repaired=%u all9_unrepaired=%u original_zero=%u original_nearzero=%u",(unsigned long long)s.seq,(unsigned long long)s.recordMs,c[3],c[4],c[5],c[22],c[23],c[24],c[25],c[26],c[27],c[28],c[30],c[31],c[53],c[54]);nfruStatsLog(line);
    snprintf(line,sizeof(line),"[NFRU GPU stats HOLECAM] sample=%llu recorded_ms=%llu solved_current=%u solved_previous=%u unsolved=%u t2_used=%u t2_rejected=%u prev_offscreen=%u prev_noconv=%u background_fill=%u",(unsigned long long)s.seq,(unsigned long long)s.recordMs,c[1],c[2],c[5],c[19],c[21],c[29],c[62],c[63]);nfruStatsLog(line);
    snprintf(line,sizeof(line),"[NFRU GPU stats VALIDITY] sample=%llu recorded_ms=%llu post_mv_invalid=%u post_of_invalid=%u current_fallback=%u mv_only=%u of_only=%u pre_mv_invalid=%u pre_of_invalid=%u",(unsigned long long)s.seq,(unsigned long long)s.recordMs,c[55],c[56],c[57],c[58],c[59],c[60],c[61]);nfruStatsLog(line);
    snprintf(line,sizeof(line),"[NFRU GPU stats CANDIDATES] sample=%llu recorded_ms=%llu camera_bad_w=%u cam_eval=%u cam_invalid=%u cam_subpixel=%u cam_offscreen=%u cam_tested=%u cam_rejected=%u cam_improved=%u cam_winner=%u cam_gt256=%u cam_gtframe=%u of_eval=%u of_invalid=%u of_subpixel=%u of_offscreen=%u of_tested=%u of_rejected=%u of_improved=%u of_winner=%u of_gt256=%u of_gtframe=%u",(unsigned long long)s.seq,(unsigned long long)s.recordMs,c[52],c[32],c[33],c[34],c[35],c[36],c[37],c[38],c[39],c[40],c[41],c[42],c[43],c[44],c[45],c[46],c[47],c[48],c[49],c[50],c[51]);nfruStatsLog(line);
  }
  s.lastTimestamp=data[0];s.busy=false;
 }}
 bool snapshot(VkCommandBuffer cb,VkBuffer source,uint32_t w,uint32_t h,float t){if(disabled||!queries)return false;unsigned i=0;for(;i<slots.size();i++)if(!slots[i].busy)break;if(i==slots.size()){skipped++;return false;}auto&s=slots[i];vkCmdResetQueryPool(cb,queries,i,1);barrier(cb,source,VK_ACCESS_SHADER_WRITE_BIT,VK_ACCESS_TRANSFER_READ_BIT,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,VK_PIPELINE_STAGE_TRANSFER_BIT);
  VkBufferCopy copy{0,0,bytes};vkCmdCopyBuffer(cb,source,s.buffer,1,&copy);barrier(cb,s.buffer,VK_ACCESS_TRANSFER_WRITE_BIT,VK_ACCESS_HOST_READ_BIT,VK_PIPELINE_STAGE_TRANSFER_BIT,VK_PIPELINE_STAGE_HOST_BIT);vkCmdWriteTimestamp(cb,VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,queries,i);barrier(cb,source,VK_ACCESS_TRANSFER_READ_BIT,VK_ACCESS_SHADER_READ_BIT|VK_ACCESS_SHADER_WRITE_BIT,VK_PIPELINE_STAGE_TRANSFER_BIT,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT);
  s.busy=true;s.seq=++sequence;s.recordMs=nfruStatsClock();s.w=w;s.h=h;s.timestep=t;return true;
 }
};

#endif
