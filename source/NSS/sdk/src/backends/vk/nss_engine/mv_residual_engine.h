#pragma once
#include <vulkan/vulkan.h>
#include <algorithm>
#include <cstring>
#include <vector>
#include "mv_residual_model.h"
#include "mv_residual_spv.h"
#include "coopmat_shape.h"

                                                                                       
                                                                              
struct NfruMvResidual {
 struct Buf { VkBuffer b{}; VkDeviceMemory mem{}; VkDeviceSize bytes{}; };
 struct Layer { uint32_t ic,oc,wo,bo,act,skip; };
 struct PC { uint32_t w,h,ic,oc,wo,bo,act,skip; float radius;uint32_t nextScale; };
 VkDevice dev{}; VkPhysicalDevice pd{}; uint32_t w{},h{}; bool coop=false, force32=false;
 Buf work[3]{},out{},packed[2]{},weights{};
 VkDescriptorSetLayout nnDSL{},ppDSL{}; VkPipelineLayout nnPL{},ppPL{};
 VkPipeline dot{},pack{},matrix{},feature{},apply{}; VkDescriptorPool pool{};
 VkDescriptorSet nnSets[8]{};std::vector<VkDescriptorSet> ppSets;
 uint64_t calls=0; bool zero=false;
 ~NfruMvResidual(){destroy();}
 bool buffer(Buf& b,VkDeviceSize bytes,bool upload=false){
  b.bytes=bytes;VkBufferCreateInfo ci{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};ci.size=bytes;ci.usage=VK_BUFFER_USAGE_STORAGE_BUFFER_BIT|VK_BUFFER_USAGE_TRANSFER_SRC_BIT|VK_BUFFER_USAGE_TRANSFER_DST_BIT;
  if(vkCreateBuffer(dev,&ci,nullptr,&b.b)!=VK_SUCCESS)return false;
  VkMemoryRequirements req;vkGetBufferMemoryRequirements(dev,b.b,&req);VkPhysicalDeviceMemoryProperties mp;vkGetPhysicalDeviceMemoryProperties(pd,&mp);
  uint32_t type=UINT32_MAX;auto flags=upload?(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT|VK_MEMORY_PROPERTY_HOST_COHERENT_BIT):VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
  for(uint32_t i=0;i<mp.memoryTypeCount;i++)if((req.memoryTypeBits&(1u<<i))&&(mp.memoryTypes[i].propertyFlags&flags)==flags){type=i;break;}
  if(type==UINT32_MAX)return false;VkMemoryAllocateInfo ai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};ai.allocationSize=req.size;ai.memoryTypeIndex=type;
  return vkAllocateMemory(dev,&ai,nullptr,&b.mem)==VK_SUCCESS&&vkBindBufferMemory(dev,b.b,b.mem,0)==VK_SUCCESS;
 }
 bool pipeline(VkPipeline& dst,VkPipelineLayout pl,const uint32_t* spv,size_t bytes,uint32_t id,uint32_t mode){
  VkShaderModuleCreateInfo smc{VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO};smc.codeSize=bytes;smc.pCode=spv;VkShaderModule sm{};
  if(vkCreateShaderModule(dev,&smc,nullptr,&sm)!=VK_SUCCESS)return false;
  VkSpecializationMapEntry e{id,0,4};VkSpecializationInfo spec{1,&e,4,&mode};
  VkComputePipelineCreateInfo pc{VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO};pc.layout=pl;pc.stage.sType=VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;pc.stage.stage=VK_SHADER_STAGE_COMPUTE_BIT;pc.stage.module=sm;pc.stage.pName="main";pc.stage.pSpecializationInfo=&spec;
  VkPipelineShaderStageRequiredSubgroupSizeCreateInfo required{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_REQUIRED_SUBGROUP_SIZE_CREATE_INFO};required.requiredSubgroupSize=32;if(&dst==&matrix && force32)pc.stage.pNext=&required;
  auto result=vkCreateComputePipelines(dev,VK_NULL_HANDLE,1,&pc,nullptr,&dst);vkDestroyShaderModule(dev,sm,nullptr);return result==VK_SUCCESS;
 }
 bool init(VkDevice d,VkPhysicalDevice p,VkInstance inst,uint32_t width,uint32_t height,bool inverted,uint32_t ring,const VkSampler* samplers){
  dev=d;pd=p;w=width;h=height;ppSets.resize(ring);zero=getenv("NFRU_MV_ZERO")&&getenv("NFRU_MV_ZERO")[0]=='1';
  if(!w||!h||uint64_t(w)*h>16777216)return false;
  for(auto& b:work)if(!buffer(b,VkDeviceSize(w)*h*32*4))return false;
  if(!buffer(out,VkDeviceSize(w)*h*4*4)||!buffer(packed[0],VkDeviceSize(w)*h*32)||!buffer(packed[1],VkDeviceSize(w)*h*32)||!buffer(weights,sizeof(g_mv_weights),true))return false;
  void* ptr=nullptr;if(vkMapMemory(dev,weights.mem,0,weights.bytes,0,&ptr)!=VK_SUCCESS)return false;memcpy(ptr,g_mv_weights,sizeof(g_mv_weights));vkUnmapMemory(dev,weights.mem);
  VkDescriptorSetLayoutBinding nb[6]{};for(uint32_t i=0;i<6;i++)nb[i]={i,VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,1,VK_SHADER_STAGE_COMPUTE_BIT,nullptr};
  VkDescriptorSetLayoutCreateInfo dl{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO};dl.bindingCount=6;dl.pBindings=nb;
  if(vkCreateDescriptorSetLayout(dev,&dl,nullptr,&nnDSL)!=VK_SUCCESS)return false;
  std::vector<VkDescriptorSetLayoutBinding> pb;for(uint32_t i=0;i<13;i++)pb.push_back({i,(i<8||i==12)?VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE:(i==9?VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER:VK_DESCRIPTOR_TYPE_STORAGE_BUFFER),1,VK_SHADER_STAGE_COMPUTE_BIT,nullptr});
  for(uint32_t i=0;i<4;i++)pb.push_back({1000+i,VK_DESCRIPTOR_TYPE_SAMPLER,1,VK_SHADER_STAGE_COMPUTE_BIT,&samplers[i]});
  dl.bindingCount=uint32_t(pb.size());dl.pBindings=pb.data();if(vkCreateDescriptorSetLayout(dev,&dl,nullptr,&ppDSL)!=VK_SUCCESS)return false;
  VkPushConstantRange range{VK_SHADER_STAGE_COMPUTE_BIT,0,sizeof(PC)};VkPipelineLayoutCreateInfo pl{VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};pl.setLayoutCount=1;pl.pSetLayouts=&nnDSL;pl.pushConstantRangeCount=1;pl.pPushConstantRanges=&range;
  if(vkCreatePipelineLayout(dev,&pl,nullptr,&nnPL)!=VK_SUCCESS)return false;pl.pSetLayouts=&ppDSL;if(vkCreatePipelineLayout(dev,&pl,nullptr,&ppPL)!=VK_SUCCESS)return false;
  if(!pipeline(dot,nnPL,g_mv_dot,sizeof(g_mv_dot),0,0)||!pipeline(pack,nnPL,g_mv_dot,sizeof(g_mv_dot),0,1))return false;
  VkPhysicalDeviceSubgroupProperties sg{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_PROPERTIES};VkPhysicalDeviceProperties2 props{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2,&sg};vkGetPhysicalDeviceProperties2(pd,&props);
  VkPhysicalDeviceVulkan13Features f13{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES};VkPhysicalDeviceFeatures2 features{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2,&f13};vkGetPhysicalDeviceFeatures2(pd,&features);
  VkPhysicalDeviceSubgroupSizeControlProperties sc{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_PROPERTIES};props.pNext=&sc;vkGetPhysicalDeviceProperties2(pd,&props);force32=sg.subgroupSize!=32 && f13.subgroupSizeControl && sc.minSubgroupSize<=32 && sc.maxSubgroupSize>=32 && (sc.requiredSubgroupSizeStages & VK_SHADER_STAGE_COMPUTE_BIT);
  NssCoopShape shape;coop=(sg.subgroupSize==32||force32)&&nssQueryCoopShape(inst,pd,shape)&&shape.native16();
  if(getenv("NFRU_FORCE_BACKEND")&&!strcmp(getenv("NFRU_FORCE_BACKEND"),"dp4a"))coop=false;
  if(coop&&!pipeline(matrix,nnPL,g_mv_coop,sizeof(g_mv_coop),0,0))return false;
  const uint32_t* shader=inverted?g_mv_pp1:g_mv_pp0;size_t size=inverted?sizeof(g_mv_pp1):sizeof(g_mv_pp0);
  if(!pipeline(feature,ppPL,shader,size,10,1)||!pipeline(apply,ppPL,shader,size,10,0))return false;
  VkDescriptorPoolSize sizes[]={{VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,48+ring*3},{VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER,ring},{VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE,ring*9},{VK_DESCRIPTOR_TYPE_SAMPLER,ring*4}};
  VkDescriptorPoolCreateInfo dp{VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO};dp.maxSets=8+ring;dp.poolSizeCount=4;dp.pPoolSizes=sizes;if(vkCreateDescriptorPool(dev,&dp,nullptr,&pool)!=VK_SUCCESS)return false;
  std::vector<VkDescriptorSetLayout> ls(8,nnDSL);VkDescriptorSetAllocateInfo da{VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO};da.descriptorPool=pool;da.descriptorSetCount=8;da.pSetLayouts=ls.data();if(vkAllocateDescriptorSets(dev,&da,nnSets)!=VK_SUCCESS)return false;
  ls.assign(ring,ppDSL);da.descriptorSetCount=ring;da.pSetLayouts=ls.data();if(vkAllocateDescriptorSets(dev,&da,ppSets.data())!=VK_SUCCESS)return false;
                                                                                                             
  const int ins[]={0,1,2,0,2,1,2,0},outs[]={1,2,0,2,1,2,0,3},skips[]={0,0,1,0,0,0,1,0};
  for(uint32_t i=0;i<8;i++){
   Buf refs[]={work[ins[i]],weights,outs[i]==3?out:work[outs[i]],work[skips[i]],packed[i%2],packed[(i+1)%2]};VkDescriptorBufferInfo infos[6];VkWriteDescriptorSet wr[6]{};
   for(uint32_t j=0;j<6;j++){infos[j]={refs[j].b,0,refs[j].bytes};wr[j]={VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};wr[j].dstSet=nnSets[i];wr[j].dstBinding=j;wr[j].descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;wr[j].descriptorCount=1;wr[j].pBufferInfo=&infos[j];}vkUpdateDescriptorSets(dev,6,wr,0,nullptr);
  }
  nss_trace("NFRU MV residual: initialized INT8 %ux%u backend=%s memory=%.1fMiB zero=%d",w,h,coop?"CoopMat(first7)+DP4a(head)":"DP4a",double(uint64_t(w)*h*464+sizeof(g_mv_weights))/1048576,zero);return true;
 }
 static void barrier(VkCommandBuffer cb){VkMemoryBarrier b{VK_STRUCTURE_TYPE_MEMORY_BARRIER};b.srcAccessMask=VK_ACCESS_SHADER_WRITE_BIT;b.dstAccessMask=VK_ACCESS_SHADER_READ_BIT|VK_ACCESS_SHADER_WRITE_BIT;vkCmdPipelineBarrier(cb,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,0,1,&b,0,nullptr,0,nullptr);}
 void linear(VkCommandBuffer cb,uint64_t groups){uint32_t x=uint32_t(std::min<uint64_t>(groups,65535));vkCmdDispatch(cb,x,uint32_t((groups+x-1)/x),1);}
 bool record(VkCommandBuffer cb,uint32_t ringIndex,const VkWriteDescriptorSet* input,uint32_t count,uint32_t tensorW,uint32_t tensorH,const VkDescriptorImageInfo& motion){
  VkDescriptorSet set=ppSets[ringIndex%ppSets.size()];std::vector<VkWriteDescriptorSet> wr(input,input+count);
  for(auto& v:wr){if(v.dstBinding>9)return false;v.dstSet=set;}
  VkDescriptorBufferInfo extra[]={{work[0].b,0,work[0].bytes},{out.b,0,out.bytes}};
  for(uint32_t i=0;i<2;i++){VkWriteDescriptorSet v{VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};v.dstSet=set;v.dstBinding=10+i;v.descriptorType=VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;v.descriptorCount=1;v.pBufferInfo=&extra[i];wr.push_back(v);}
  VkWriteDescriptorSet motionWrite{VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET};motionWrite.dstSet=set;motionWrite.dstBinding=12;motionWrite.descriptorType=VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE;motionWrite.descriptorCount=1;motionWrite.pImageInfo=&motion;wr.push_back(motionWrite);
  vkUpdateDescriptorSets(dev,uint32_t(wr.size()),wr.data(),0,nullptr);
  PC p{w,h,0,0,0,0,0,0,1};
  if(zero){vkCmdFillBuffer(cb,out.b,0,out.bytes,0);VkMemoryBarrier b{VK_STRUCTURE_TYPE_MEMORY_BARRIER};b.srcAccessMask=VK_ACCESS_TRANSFER_WRITE_BIT;b.dstAccessMask=VK_ACCESS_SHADER_READ_BIT;vkCmdPipelineBarrier(cb,VK_PIPELINE_STAGE_TRANSFER_BIT,VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT,0,1,&b,0,nullptr,0,nullptr);}
  else{
   vkCmdBindPipeline(cb,VK_PIPELINE_BIND_POINT_COMPUTE,feature);vkCmdBindDescriptorSets(cb,VK_PIPELINE_BIND_POINT_COMPUTE,ppPL,0,1,&set,0,nullptr);vkCmdPushConstants(cb,ppPL,VK_SHADER_STAGE_COMPUTE_BIT,0,sizeof(p),&p);vkCmdDispatch(cb,(w+7)/8,(h+7)/8,1);barrier(cb);
   recordNetwork(cb);
  }
  p={w,h,0,0,0,0,0,0,1};vkCmdBindPipeline(cb,VK_PIPELINE_BIND_POINT_COMPUTE,apply);vkCmdBindDescriptorSets(cb,VK_PIPELINE_BIND_POINT_COMPUTE,ppPL,0,1,&set,0,nullptr);vkCmdPushConstants(cb,ppPL,VK_SHADER_STAGE_COMPUTE_BIT,0,sizeof(p),&p);vkCmdDispatch(cb,(tensorW+7)/8,(tensorH+7)/8,1);barrier(cb);
  if(calls++<6)nss_trace("NFRU MV residual: dispatch #%llu (3x/4x only, endpoint UV correction)",static_cast<unsigned long long>(calls));return true;
 }
 void recordNetwork(VkCommandBuffer cb,VkQueryPool queries=VK_NULL_HANDLE,uint32_t queryBase=0){
  PC p{};
   const Layer* layers=reinterpret_cast<const Layer*>(g_mv_layout+2);float radius;uint32_t nextScale;memcpy(&radius,g_mv_layout+1,4);
   for(uint32_t i=0;i<8;i++){const auto& l=layers[i];p={w,h,l.ic,l.oc,l.wo,l.bo,l.act,l.skip?1u:0u,radius,i<7?layers[i+1].bo+2*layers[i+1].oc:0u};
    vkCmdBindDescriptorSets(cb,VK_PIPELINE_BIND_POINT_COMPUTE,nnPL,0,1,&nnSets[i],0,nullptr);vkCmdPushConstants(cb,nnPL,VK_SHADER_STAGE_COMPUTE_BIT,0,sizeof(p),&p);
    if(!coop||i==0){vkCmdBindPipeline(cb,VK_PIPELINE_BIND_POINT_COMPUTE,pack);linear(cb,(uint64_t(w)*h*(l.ic/4)+63)/64);barrier(cb);}if(queries)vkCmdWriteTimestamp(cb,VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,queries,queryBase+i*2);
    bool cm=coop&&i<7;vkCmdBindPipeline(cb,VK_PIPELINE_BIND_POINT_COMPUTE,cm?matrix:dot);
    if(cm){uint64_t g=(uint64_t(w)*h+15)/16;uint32_t x=uint32_t(std::min<uint64_t>(g,65535));vkCmdDispatch(cb,x,(l.oc+31)/32,uint32_t((g+x-1)/x));}else linear(cb,(uint64_t(w)*h*l.oc+63)/64);barrier(cb);if(queries)vkCmdWriteTimestamp(cb,VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,queries,queryBase+i*2+1);
   }
 }
 void destroy(){if(!dev)return;for(auto p:{dot,pack,matrix,feature,apply})if(p)vkDestroyPipeline(dev,p,nullptr);if(pool)vkDestroyDescriptorPool(dev,pool,nullptr);for(auto p:{nnPL,ppPL})if(p)vkDestroyPipelineLayout(dev,p,nullptr);for(auto p:{nnDSL,ppDSL})if(p)vkDestroyDescriptorSetLayout(dev,p,nullptr);for(auto b:{work[0],work[1],work[2],out,packed[0],packed[1],weights}){if(b.b)vkDestroyBuffer(dev,b.b,nullptr);if(b.mem)vkFreeMemory(dev,b.mem,nullptr);}dev=VK_NULL_HANDLE;}
};
