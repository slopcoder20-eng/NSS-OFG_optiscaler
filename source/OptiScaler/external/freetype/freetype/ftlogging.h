/****************************************************************************
 *
 * ftlogging.h
 *
 *   Additional debugging APIs.
 *
 * Copyright (C) 2020-2024 by
 * David Turner, Robert Wilhelm, and Werner Lemberg.
 *
 * This file is part of the FreeType project, and may only be used,
 * modified, and distributed under the terms of the FreeType project
 * license, LICENSE.TXT.  By continuing to use, modify, or distribute
 * this file you indicate that you have read the license and
 * understand and accept it fully.
 *
 */


#ifndef FTLOGGING_H_
#define FTLOGGING_H_


#include <ft2build.h>
#include FT_CONFIG_CONFIG_H


FT_BEGIN_HEADER


                                                                             
    
              
                     
    
            
                              
    
               
                                                           
    
                  
                                                                      
                                                                         
    
     


                                                                             
    
               
                         
    
                  
                                                                       
    
            
                       
                           
    
              
                                                                          
                 
    
          
                                              
          
    
           
                                                                          
                 
    
            
           
    
     
  FT_EXPORT( void )
  FT_Trace_Set_Level( const char*  tracing_level );


                                                                             
    
               
                                 
    
                  
                                                                        
                                                                          
                                  
    
           
                                                                          
                 
    
            
           
    
     
  FT_EXPORT( void )
  FT_Trace_Set_Default_Level( void );


                                                                             
    
               
                            
    
                  
                                                                           
                                       
    
            
                      
                                                                         
                             
    
             
                                         
    
             
                                                
    
            
           
    
     
  typedef void
  (*FT_Custom_Log_Handler)( const char*  ft_component,
                            const char*  fmt,
                            va_list      args );


                                                                             
    
               
                         
    
                  
                                              
    
            
                 
                              
    
           
                                                                          
                 
    
            
           
    
     
  FT_EXPORT( void )
  FT_Set_Log_Handler( FT_Custom_Log_Handler  handler );


                                                                             
    
               
                                 
    
                  
                                                                          
                                                  
    
           
                                                                          
                 
    
            
           
    
     
  FT_EXPORT( void )
  FT_Set_Default_Log_Handler( void );

       


FT_END_HEADER

#endif                   


         
