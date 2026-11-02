/****************************************************************************
 *
 * ftadvanc.h
 *
 *   Quick computation of advance widths (specification only).
 *
 * Copyright (C) 2008-2024 by
 * David Turner, Robert Wilhelm, and Werner Lemberg.
 *
 * This file is part of the FreeType project, and may only be used,
 * modified, and distributed under the terms of the FreeType project
 * license, LICENSE.TXT.  By continuing to use, modify, or distribute
 * this file you indicate that you have read the license and
 * understand and accept it fully.
 *
 */


#ifndef FTADVANC_H_
#define FTADVANC_H_


#include <freetype/freetype.h>

#ifdef FREETYPE_H
#error "freetype.h of FreeType 1 has been loaded!"
#error "Please fix the directory search order for header files"
#error "so that freetype.h of FreeType 2 is found first."
#endif


FT_BEGIN_HEADER


                                                                             
    
              
                    
    
            
                                        
    
               
                                                                         
                                   
    
                  
                                                                        
                                                    
    
            
                     
                      
    
     


                                                                             
    
           
                                
    
                  
                                                               
                                                      
    
                                                                        
                                                                             
                           
    
                                                                          
                                                                       
    
                                                                          
                                                                      
     
#define FT_ADVANCE_FLAG_FAST_ONLY  0x20000000L


                                                                             
    
               
                     
    
                  
                                                                          
    
            
              
                                    
    
                
                         
    
                    
                                                              
                                                                          
    
             
                  
                                                                           
                                                                            
                          
    
                                                                         
                                                                             
                                        
    
             
                                             
    
           
                                                                          
                                                                          
                    
    
                                                                            
                                                                
     
  FT_EXPORT( FT_Error )
  FT_Get_Advance( FT_Face    face,
                  FT_UInt    gindex,
                  FT_Int32   load_flags,
                  FT_Fixed  *padvance );


                                                                             
    
               
                      
    
                  
                                                                            
    
            
              
                                    
    
               
                               
    
               
                                                           
    
                    
                                                              
                        
    
             
                  
                                                                            
                                           
    
                                                                          
                                                                         
               
    
                                                                            
                                                                     
                                                    
    
             
                                             
    
           
                                                                          
                                                                          
                    
    
                                                                             
                                                                
     
  FT_EXPORT( FT_Error )
  FT_Get_Advances( FT_Face    face,
                   FT_UInt    start,
                   FT_UInt    count,
                   FT_Int32   load_flags,
                   FT_Fixed  *padvances );

       


FT_END_HEADER

#endif                  


         
