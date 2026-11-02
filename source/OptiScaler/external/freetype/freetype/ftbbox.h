/****************************************************************************
 *
 * ftbbox.h
 *
 *   FreeType exact bbox computation (specification).
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
   * This component has a _single_ role: to compute exact outline bounding
   * boxes.
   *
   * It is separated from the rest of the engine for various technical
   * reasons.  It may well be integrated in 'ftoutln' later.
   *
   */


#ifndef FTBBOX_H_
#define FTBBOX_H_


#include <freetype/freetype.h>

#ifdef FREETYPE_H
#error "freetype.h of FreeType 1 has been loaded!"
#error "Please fix the directory search order for header files"
#error "so that freetype.h of FreeType 2 is found first."
#endif


FT_BEGIN_HEADER


                                                                             
    
              
                         
    
     


                                                                             
    
               
                          
    
                  
                                                                         
                                                                         
                                                                           
                                                                      
    
            
                 
                                         
    
             
               
                                          
    
             
                                             
    
           
                                                               
                                                                    
                                                                            
                                                                            
                                                                       
                                               
     
  FT_EXPORT( FT_Error )
  FT_Outline_Get_BBox( FT_Outline*  outline,
                       FT_BBox     *abbox );

       


FT_END_HEADER

#endif                


         


                      
                      
                      
