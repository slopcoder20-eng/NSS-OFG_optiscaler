/****************************************************************************
 *
 * ftcid.h
 *
 *   FreeType API for accessing CID font information (specification).
 *
 * Copyright (C) 2007-2024 by
 * Dereg Clegg and Michael Toftdal.
 *
 * This file is part of the FreeType project, and may only be used,
 * modified, and distributed under the terms of the FreeType project
 * license, LICENSE.TXT.  By continuing to use, modify, or distribute
 * this file you indicate that you have read the license and
 * understand and accept it fully.
 *
 */


#ifndef FTCID_H_
#define FTCID_H_

#include <freetype/freetype.h>

#ifdef FREETYPE_H
#error "freetype.h of FreeType 1 has been loaded!"
#error "Please fix the directory search order for header files"
#error "so that freetype.h of FreeType 2 is found first."
#endif


FT_BEGIN_HEADER


                                                                             
    
              
                
    
            
                
    
               
                                   
    
                  
                                                                       
                 
    
     


                                                                             
    
               
                                               
    
                  
                                                                           
                                       
    
            
               
                                     
    
             
                   
                                                         
    
                   
                                                         
    
                     
                         
    
             
                                              
    
           
                                                                   
                  
    
            
             
     
  FT_EXPORT( FT_Error )
  FT_Get_CID_Registry_Ordering_Supplement( FT_Face       face,
                                           const char*  *registry,
                                           const char*  *ordering,
                                           FT_Int       *supplement );


                                                                             
    
               
                                          
    
                  
                                                                           
                                                                             
                                               
    
            
               
                                     
    
             
                 
                                              
    
             
                                              
    
           
                                                                             
                           
    
            
             
     
  FT_EXPORT( FT_Error )
  FT_Get_CID_Is_Internally_CID_Keyed( FT_Face   face,
                                      FT_Bool  *is_cid );


                                                                             
    
               
                                   
    
                  
                                                  
    
            
               
                                     
    
                      
                                
    
             
              
                                 
    
             
                                              
    
           
                                                                             
                           
    
            
             
     
  FT_EXPORT( FT_Error )
  FT_Get_CID_From_Glyph_Index( FT_Face   face,
                               FT_UInt   glyph_index,
                               FT_UInt  *cid );

       


FT_END_HEADER

#endif               


         
