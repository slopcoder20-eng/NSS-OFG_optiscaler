/****************************************************************************
 *
 * ftparams.h
 *
 *   FreeType API for possible FT_Parameter tags (specification only).
 *
 * Copyright (C) 2017-2024 by
 * David Turner, Robert Wilhelm, and Werner Lemberg.
 *
 * This file is part of the FreeType project, and may only be used,
 * modified, and distributed under the terms of the FreeType project
 * license, LICENSE.TXT.  By continuing to use, modify, or distribute
 * this file you indicate that you have read the license and
 * understand and accept it fully.
 *
 */


#ifndef FTPARAMS_H_
#define FTPARAMS_H_

#include <freetype/freetype.h>

#ifdef FREETYPE_H
#error "freetype.h of FreeType 1 has been loaded!"
#error "Please fix the directory search order for header files"
#error "so that freetype.h of FreeType 2 is found first."
#endif


FT_BEGIN_HEADER


                                                                             
    
              
                     
    
            
                     
    
               
                                                                  
    
                  
                                                                            
                                                                            
                                                             
    
     


                                                                             
    
           
                                             
    
                  
                                                                       
                                                                             
                                                                          
                                         
    
            
          
    
     
#define FT_PARAM_TAG_IGNORE_TYPOGRAPHIC_FAMILY \
          FT_MAKE_TAG( 'i', 'g', 'p', 'f' )


                                   
#define FT_PARAM_TAG_IGNORE_PREFERRED_FAMILY \
          FT_PARAM_TAG_IGNORE_TYPOGRAPHIC_FAMILY


                                                                             
    
           
                                                
    
                  
                                                                       
                                                                          
                                                                          
                                                
    
            
          
    
     
#define FT_PARAM_TAG_IGNORE_TYPOGRAPHIC_SUBFAMILY \
          FT_MAKE_TAG( 'i', 'g', 'p', 's' )


                                   
#define FT_PARAM_TAG_IGNORE_PREFERRED_SUBFAMILY \
          FT_PARAM_TAG_IGNORE_TYPOGRAPHIC_SUBFAMILY


                                                                             
    
           
                               
    
                  
                                                                     
                                 
    
     
#define FT_PARAM_TAG_INCREMENTAL \
          FT_MAKE_TAG( 'i', 'n', 'c', 'r' )


                                                                             
    
           
                               
    
                  
                                                                           
                                                                           
                                                     
    
     
#define FT_PARAM_TAG_IGNORE_SBIX \
          FT_MAKE_TAG( 'i', 's', 'b', 'x' )


                                                                             
    
           
                                      
    
                  
                                                                     
                                                                         
                                                                             
                                                      
                                       
    
            
          
    
     
#define FT_PARAM_TAG_LCD_FILTER_WEIGHTS \
          FT_MAKE_TAG( 'l', 'c', 'd', 'f' )


                                                                             
    
           
                               
    
                  
                                                                     
                                                                     
                                                                             
    
            
          
    
     
#define FT_PARAM_TAG_RANDOM_SEED \
          FT_MAKE_TAG( 's', 'e', 'e', 'd' )


                                                                             
    
           
                                  
    
                  
                                                                     
                                                                     
                                                                           
                                                      
    
                                                                             
                                                                          
                                                                         
            
    
            
          
    
     
#define FT_PARAM_TAG_STEM_DARKENING \
          FT_MAKE_TAG( 'd', 'a', 'r', 'k' )


                                                                             
    
           
                                      
    
                  
                             
    
                                                                           
                                                                     
                                                                            
    
     
#define FT_PARAM_TAG_UNPATENTED_HINTING \
          FT_MAKE_TAG( 'u', 'n', 'p', 'a' )


       


FT_END_HEADER


#endif                  


         
