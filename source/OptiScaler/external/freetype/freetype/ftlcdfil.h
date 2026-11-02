/****************************************************************************
 *
 * ftlcdfil.h
 *
 *   FreeType API for color filtering of subpixel bitmap glyphs
 *   (specification).
 *
 * Copyright (C) 2006-2024 by
 * David Turner, Robert Wilhelm, and Werner Lemberg.
 *
 * This file is part of the FreeType project, and may only be used,
 * modified, and distributed under the terms of the FreeType project
 * license, LICENSE.TXT.  By continuing to use, modify, or distribute
 * this file you indicate that you have read the license and
 * understand and accept it fully.
 *
 */


#ifndef FTLCDFIL_H_
#define FTLCDFIL_H_

#include <freetype/freetype.h>
#include <freetype/ftparams.h>

#ifdef FREETYPE_H
#error "freetype.h of FreeType 1 has been loaded!"
#error "Please fix the directory search order for header files"
#error "so that freetype.h of FreeType 2 is found first."
#endif


FT_BEGIN_HEADER

                                                                             
    
              
                    
    
            
                         
    
               
                                         
    
                  
                                                                         
                                                                      
                                                                 
                                                                           
                                                                      
                                                                          
                                  
    
                                                                            
                                                                          
                                                                       
                                                                    
                                                                   
                                                                     
                                                                           
                                                                           
                        
    
                                                                    
                                   
    
                                                                         
                                                                           
                                
    
                                                                        
                             
    
                                                                     
                                                                            
                                                     
    
                                                                          
                                                                 
                                                                    
    
                                                                            
                                                                           
                                                                        
                                                                           
                                                                            
                                                                         
                                                          
    
                                                                         
                                                                          
                                                                        
                                                           
    
                                                                            
                                                                             
                                                                            
                                                                        
                                                                     
                                   
    
                                                                          
                                                                         
                                                                     
                                                                           
                                                                            
                                                                             
                                                           
    
                                                                         
                                                                            
                                                                             
                                                                      
                              
    
                                                                          
                                                                             
                                                                             
                                                                            
                                                          
     


                                                                             
    
           
                   
    
                  
                                                                 
    
             
                            
                                                                           
                                                   
    
                               
                                                                          
                                                                   
    
                             
                                                                             
                                                              
    
                              
                               
                                                                         
                                                                       
                                                                           
                                                                           
                                                                        
                                                                            
                                                                            
    
            
                                                  
     
  typedef enum  FT_LcdFilter_
  {
    FT_LCD_FILTER_NONE    = 0,
    FT_LCD_FILTER_DEFAULT = 1,
    FT_LCD_FILTER_LIGHT   = 2,
    FT_LCD_FILTER_LEGACY1 = 3,
    FT_LCD_FILTER_LEGACY  = 16,

    FT_LCD_FILTER_MAX                      

  } FT_LcdFilter;


                                                                             
    
               
                              
    
                  
                                                                      
                                                                     
                                                    
    
            
                 
                                                 
    
                
                         
    
                                                                         
                                                                             
                             
    
             
                                             
    
           
                                                                             
                                                                        
                                                                        
                           
    
                                                                            
                                                                          
                                                
    
            
            
     
  FT_EXPORT( FT_Error )
  FT_Library_SetLcdFilter( FT_Library    library,
                           FT_LcdFilter  filter );


                                                                             
    
               
                                     
    
                  
                                                                          
                                                            
    
            
                 
                                                 
    
                 
                                                                            
                                                                
    
             
                                             
    
           
                                                                            
                                                                          
                                                
    
                                                                            
                                             
    
            
            
     
  FT_EXPORT( FT_Error )
  FT_Library_SetLcdFilterWeights( FT_Library      library,
                                  unsigned char  *weights );


                                                                             
    
           
                          
    
                  
                                                           
                                                             
    
            
          
    
     
#define FT_LCD_FILTER_FIVE_TAPS  5

  typedef FT_Byte  FT_LcdFiveTapFilter[FT_LCD_FILTER_FIVE_TAPS];


                                                                             
    
               
                                
    
                  
                                                                     
                                                       
    
            
                 
                                                 
    
             
                                                                            
                                                                      
    
             
                                             
    
           
                                  
    
                                                                             
                                                                         
    
                                                                          
                                                                        
                     
    
                                                                        
                                
    
                                                                           
    
                                                                            
                                                                
                                                                            
               
    
            
             
     
  FT_EXPORT( FT_Error )
  FT_Library_SetLcdGeometry( FT_Library  library,
                             FT_Vector   sub[3] );

       


FT_END_HEADER

#endif                  


         
