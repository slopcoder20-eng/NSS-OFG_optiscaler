/****************************************************************************
 *
 * ftgasp.h
 *
 *   Access of TrueType's 'gasp' table (specification).
 *
 * Copyright (C) 2007-2024 by
 * David Turner, Robert Wilhelm, and Werner Lemberg.
 *
 * This file is part of the FreeType project, and may only be used,
 * modified, and distributed under the terms of the FreeType project
 * license, LICENSE.TXT.  By continuing to use, modify, or distribute
 * this file you indicate that you have read the license and
 * understand and accept it fully.
 *
 */


#ifndef FTGASP_H_
#define FTGASP_H_

#include <freetype/freetype.h>

#ifdef FREETYPE_H
#error "freetype.h of FreeType 1 has been loaded!"
#error "Please fix the directory search order for header files"
#error "so that freetype.h of FreeType 2 is found first."
#endif


FT_BEGIN_HEADER


                                                                             
    
              
                 
    
            
                 
    
               
                                                
    
                  
                                                                            
                                                                             
                                                                         
                                                                   
     

                                                                             
    
           
                  
    
                  
                                                                     
                
    
             
                          
                                                                           
                                                     
    
                            
                                                                            
                                                                             
                                             
    
                         
                                                                          
                                             
    
                                     
                                                                           
    
                                   
                                                                        
    
           
                                                                         
                                                                         
                                                                           
                                                                    
                                                   
    
                                                                         
                            
    
            
            
     
#define FT_GASP_NO_TABLE               -1
#define FT_GASP_DO_GRIDFIT           0x01
#define FT_GASP_DO_GRAY              0x02
#define FT_GASP_SYMMETRIC_GRIDFIT    0x04
#define FT_GASP_SYMMETRIC_SMOOTHING  0x08


                                                                             
    
               
                  
    
                  
                                                                            
                                                                            
                  
    
            
              
                                
    
              
                                           
    
             
                                                                        
                                
    
           
                                                                          
                                                                          
                                                                         
              
    
            
            
     
  FT_EXPORT( FT_Int )
  FT_Get_Gasp( FT_Face  face,
               FT_UInt  ppem );

       


FT_END_HEADER

#endif                


         
