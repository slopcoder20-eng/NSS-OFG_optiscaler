/****************************************************************************
 *
 * ftsnames.h
 *
 *   Simple interface to access SFNT 'name' tables (which are used
 *   to hold font names, copyright info, notices, etc.) (specification).
 *
 *   This is _not_ used to retrieve glyph names!
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


#ifndef FTSNAMES_H_
#define FTSNAMES_H_


#include <freetype/freetype.h>
#include <freetype/ftparams.h>

#ifdef FREETYPE_H
#error "freetype.h of FreeType 1 has been loaded!"
#error "Please fix the directory search order for header files"
#error "so that freetype.h of FreeType 2 is found first."
#endif


FT_BEGIN_HEADER


  /**************************************************************************
   *
   * @section:
   *   sfnt_names
   *
   * @title:
   *   SFNT Names
   *
   * @abstract:
   *   Access the names embedded in TrueType and OpenType files.
   *
   * @description:
   *   The TrueType and OpenType specifications allow the inclusion of a
   *   special names table ('name') in font files.  This table contains
   *   textual (and internationalized) information regarding the font, like
   *   family name, copyright, version, etc.
   *
   *   The definitions below are used to access them if available.
   *
   *   Note that this has nothing to do with glyph names!
   *
   */


  /**************************************************************************
   *
   * @struct:
   *   FT_SfntName
   *
   * @description:
   *   A structure used to model an SFNT 'name' table entry.
   *
   * @fields:
   *   platform_id ::
   *     The platform ID for `string`.  See @TT_PLATFORM_XXX for possible
   *     values.
   *
   *   encoding_id ::
   *     The encoding ID for `string`.  See @TT_APPLE_ID_XXX, @TT_MAC_ID_XXX,
   *     @TT_ISO_ID_XXX, @TT_MS_ID_XXX, and @TT_ADOBE_ID_XXX for possible
   *     values.
   *
   *   language_id ::
   *     The language ID for `string`.  See @TT_MAC_LANGID_XXX and
   *     @TT_MS_LANGID_XXX for possible values.
   *
   *     Registered OpenType values for `language_id` are always smaller than
   *     0x8000; values equal or larger than 0x8000 usually indicate a
   *     language tag string (introduced in OpenType version 1.6).  Use
   *     function @FT_Get_Sfnt_LangTag with `language_id` as its argument to
   *     retrieve the associated language tag.
   *
   *   name_id ::
   *     An identifier for `string`.  See @TT_NAME_ID_XXX for possible
   *     values.
   *
   *   string ::
   *     The 'name' string.  Note that its format differs depending on the
   *     (platform,encoding) pair, being either a string of bytes (without a
   *     terminating `NULL` byte) or containing UTF-16BE entities.
   *
   *   string_len ::
   *     The length of `string` in bytes.
   *
   * @note:
   *   Please refer to the TrueType or OpenType specification for more
   *   details.
   */
  typedef struct  FT_SfntName_
  {
    FT_UShort  platform_id;
    FT_UShort  encoding_id;
    FT_UShort  language_id;
    FT_UShort  name_id;

    FT_Byte*   string;                                                 
    FT_UInt    string_len;                                             

  } FT_SfntName;


                                                                             
    
               
                             
    
                  
                                                                    
    
            
              
                                     
    
             
                                                 
    
           
                                                                
                                                                    
     
  FT_EXPORT( FT_UInt )
  FT_Get_Sfnt_Name_Count( FT_Face  face );


                                                                             
    
               
                       
    
                  
                                                                    
    
            
              
                                     
    
             
                                        
    
             
               
                                            
    
             
                                             
    
           
                                                                  
                                                                           
                                                                     
    
                                                                       
                                                                             
                             
    
                                                                    
                            
    
                                                                
                                                                    
     
  FT_EXPORT( FT_Error )
  FT_Get_Sfnt_Name( FT_Face       face,
                    FT_UInt       idx,
                    FT_SfntName  *aname );


                                                                             
    
             
                     
    
                  
                                                                           
    
             
                
                                                                       
                       
    
                    
                                             
    
           
                                                                      
               
    
            
          
     
  typedef struct  FT_SfntLangTag_
  {
    FT_Byte*  string;                                                 
    FT_UInt   string_len;                                             

  } FT_SfntLangTag;


                                                                             
    
               
                          
    
                  
                                                                         
                          
    
            
              
                                     
    
                
                                                                             
                                  
    
             
                  
                                                                           
            
    
             
                                             
    
           
                                                                     
                                                                           
                                                                     
    
                                                                       
                                                                      
                                                                      
                
    
                                                                
                                                                    
    
            
          
     
  FT_EXPORT( FT_Error )
  FT_Get_Sfnt_LangTag( FT_Face          face,
                       FT_UInt          langID,
                       FT_SfntLangTag  *alangTag );


       


FT_END_HEADER

#endif                  


         
