/****************************************************************************
 *
 * ftpfr.h
 *
 *   FreeType API for accessing PFR-specific data (specification only).
 *
 * Copyright (C) 2002-2024 by
 * David Turner, Robert Wilhelm, and Werner Lemberg.
 *
 * This file is part of the FreeType project, and may only be used,
 * modified, and distributed under the terms of the FreeType project
 * license, LICENSE.TXT.  By continuing to use, modify, or distribute
 * this file you indicate that you have read the license and
 * understand and accept it fully.
 *
 */


#ifndef FTPFR_H_
#define FTPFR_H_

#include <freetype/freetype.h>

#ifdef FREETYPE_H
#error "freetype.h of FreeType 1 has been loaded!"
#error "Please fix the directory search order for header files"
#error "so that freetype.h of FreeType 2 is found first."
#endif


FT_BEGIN_HEADER


                                                                             
    
              
                
    
            
                
    
               
                                
    
                  
                                                                       
    
     


                                                                             
    
               
                          
    
                  
                                                                       
    
            
               
                                                              
    
             
                              
                                                                             
                                                             
    
                              
                                                                             
                                                             
    
                           
                                                                        
                                                                   
                                                                           
                         
    
                           
                                                                    
                                             
    
             
                                              
    
           
                                                                          
                                                          
     
  FT_EXPORT( FT_Error )
  FT_Get_PFR_Metrics( FT_Face    face,
                      FT_UInt   *aoutline_resolution,
                      FT_UInt   *ametrics_resolution,
                      FT_Fixed  *ametrics_x_scale,
                      FT_Fixed  *ametrics_y_scale );


                                                                             
    
               
                          
    
                  
                                                                          
                                                                        
                        
    
            
               
                                     
    
               
                                  
    
                
                                   
    
             
                  
                           
    
             
                                              
    
           
                                                                            
                                                                          
                                                                  
    
                                                                       
                                                                           
     
  FT_EXPORT( FT_Error )
  FT_Get_PFR_Kerning( FT_Face     face,
                      FT_UInt     left,
                      FT_UInt     right,
                      FT_Vector  *avector );


                                                                             
    
               
                          
    
                  
                                                                          
                        
    
            
               
                                     
    
                 
                          
    
             
                   
                                             
    
             
                                              
    
           
                                                                             
                                                                          
     
  FT_EXPORT( FT_Error )
  FT_Get_PFR_Advance( FT_Face   face,
                      FT_UInt   gindex,
                      FT_Pos   *aadvance );

       


FT_END_HEADER

#endif               


         
