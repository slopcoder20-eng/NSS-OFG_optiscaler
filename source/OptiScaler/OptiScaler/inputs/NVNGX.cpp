#include "pch.h"
#include "Config.h"
#include "proxies/NVNGX_Proxy.h"

#pragma region Out of NVNGX Scope

                                   
  
                      
                                                                                                                             
  
                                                   
   
              
             
   
  
                                                      
   
              
                                                
   
  
                                                      
   
              
                                                      
   
  
                                                                                                                        
                           
   
              
  
                                             
    
                                    
                                                  
    
  
                               
                                 
  
                                          
    
                               
  
                               
                     
    
  
                                   
   
  
                                                        
   
              
                                    
   
  
                                                       
   
              
                  
   
  
                                                                                                                 
   
                                                                                                   
                                   
   
  
                                                                           
   
              
                                   
   
  
                                                                                        
   
              
                                   
   

#pragma endregion

NVSDK_NGX_API NVSDK_NGX_Result NVSDK_NGX_UpdateFeature(const NVSDK_NGX_Application_Identifier* ApplicationId,
                                                       const NVSDK_NGX_Feature FeatureID)
{
    LOG_DEBUG("FeatureId: {0}", (UINT) FeatureID);

                                 
                                                        
       
                                                  
        
                                                                            
                                                                                              
                      
        
           
        
                                                                      
                                     
        
       

    if (ApplicationId != nullptr)
    {
        if (ApplicationId->IdentifierType == NVSDK_NGX_Application_Identifier_Type_Application_Id)
        {
            auto appId = Config::Instance()->UseGenericAppIdWithDlss.value_or_default()
                             ? app_id_override
                             : ApplicationId->v.ApplicationId;
            LOG_INFO("Update ApplicationId: {0:X}", appId);
            State::Instance().NVNGX_ApplicationId = appId;
        }
        else if (ApplicationId->IdentifierType == NVSDK_NGX_Application_Identifier_Type_Project_Id)
        {
            auto projectId = Config::Instance()->UseGenericAppIdWithDlss.value_or_default()
                                 ? project_id_override
                                 : std::string(ApplicationId->v.ProjectDesc.ProjectId);
            State::Instance().NVNGX_ProjectId = projectId;
            State::Instance().NVNGX_Engine = ApplicationId->v.ProjectDesc.EngineType;
            State::Instance().NVNGX_EngineVersion = std::string(ApplicationId->v.ProjectDesc.EngineVersion);

            LOG_INFO("Update InProjectId: {0}", projectId);
            LOG_INFO("Update InEngineType: {0}", (int) State::Instance().NVNGX_Engine);
            LOG_INFO("Update InEngineVersion: {0}", State::Instance().NVNGX_EngineVersion);
        }
        else
        {
            LOG_ERROR("Unknown IdentifierType ({0})!", (int) ApplicationId->IdentifierType);
        }
    }

                                 
    LOG_DEBUG("FeatureId finished, returning NVSDK_NGX_Result_Success");
    return NVSDK_NGX_Result_Success;
}
