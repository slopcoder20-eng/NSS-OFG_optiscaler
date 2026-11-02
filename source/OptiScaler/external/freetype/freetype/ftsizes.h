/****************************************************************************
 *
 * ftsizes.h
 *
 *   FreeType size objects management (specification).
 *
 * Copyright (C) 1996-2024 by
 * David Turner, Robert Wilhelm, and Werner Lemberg.
 *
 * This file is part of the FreeType project, and may only be used,
 * modified, and distributed under the terms of the FreeType project
 * license, LICENSE.TXT.  By continuing to use, modify, or distribute
 * this file you indicate that you have read the license and
 * understand and accept it fully.
 *
 */


  /**************************************************************************
   *
   * Typical application would normally not need to use these functions.
   * However, they have been placed in a public API for the rare cases where
   * they are needed.
   *
   */


#ifndef FTSIZES_H_
#define FTSIZES_H_


#include <freetype/freetype.h>

#ifdef FREETYPE_H
#error "freetype.h of FreeType 1 has been loaded!"
#error "Please fix the directory search order for header files"
#error "so that freetype.h of FreeType 2 is found first."
#endif


FT_BEGIN_HEADER


                                                                             
    
              
                       
    
            
                      
    
               
                                        
    
                  
                                                                             
                                                                       
                                                                  
    
                                                                           
                                                                        
                                                             
    
                                                                          
                                                                  
                                      
    
                                                                             
                                                                           
    
     


                                                                             
    
               
                  
    
                  
                                                         
    
            
              
                                          
    
             
               
                                       
    
             
                                             
    
           
                                                                             
                                                                
                                          
     
  FT_EXPORT( FT_Error )
  FT_New_Size( FT_Face   face,
               FT_Size*  size );


                                                                             
    
               
                   
    
                  
                                                                          
                                                             
    
            
              
                                          
    
             
                                             
     
  FT_EXPORT( FT_Error )
  FT_Done_Size( FT_Size  size );


                                                                             
    
               
                       
    
                  
                                                                            
                                                                            
                                                                     
                                                    
    
                                                                        
              
    
            
              
                                          
    
             
                                             
    
           
                                                                            
                                                      
     
  FT_EXPORT( FT_Error )
  FT_Activate_Size( FT_Size  size );

       


FT_END_HEADER

#endif                 


         
