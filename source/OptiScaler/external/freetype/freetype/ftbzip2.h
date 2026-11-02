/****************************************************************************
 *
 * ftbzip2.h
 *
 *   Bzip2-compressed stream support.
 *
 * Copyright (C) 2010-2024 by
 * Joel Klinghed.
 *
 * This file is part of the FreeType project, and may only be used,
 * modified, and distributed under the terms of the FreeType project
 * license, LICENSE.TXT.  By continuing to use, modify, or distribute
 * this file you indicate that you have read the license and
 * understand and accept it fully.
 *
 */


#ifndef FTBZIP2_H_
#define FTBZIP2_H_

#include <freetype/freetype.h>

#ifdef FREETYPE_H
#error "freetype.h of FreeType 1 has been loaded!"
#error "Please fix the directory search order for header files"
#error "so that freetype.h of FreeType 2 is found first."
#endif


FT_BEGIN_HEADER

                                                                             
    
              
            
    
            
                    
    
               
                                         
    
                  
                                                                         
                                                                        
                                                                       
                                                                       
                                                   
    
                                                                           
                                                                       
                                                      
    
                                                                         
    
     


                                                                             
    
               
                          
    
                  
                                                                       
                                                                             
               
    
            
                
                                     
    
                
                           
    
             
                                             
    
           
                                                                       
    
                                                                             
                                                                        
                                                   
    
                                                                            
                                                       
     
  FT_EXPORT( FT_Error )
  FT_Stream_OpenBzip2( FT_Stream  stream,
                       FT_Stream  source );

       


FT_END_HEADER

#endif                 


         
