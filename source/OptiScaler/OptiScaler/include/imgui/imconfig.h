                                                                               
                                  
                                                                                                                         
                                                                                                                          
                                                                               
                                                                                                                                               
                                                                                                                                                 
                                                                               
                                                                                                                                           
                                                                                                                                       
                                                                                                                       
                                                                                                                                                  
                                                                               

#pragma once

                                                              
                                                                                                                                          
                                           
                                                                  

                                                                                    
                                                                                                                                                                     
                                                                                                                                                   
                                                                                                                                   
                                                                                       
                                                                                       
                                                                                                                

                                                                                                                                                         
#define IMGUI_DISABLE_OBSOLETE_FUNCTIONS

                                                                           
                                                                                                                                                                                           
                                                                                                                              
                                                                                                                                      
                                                                                                                                                                                                   

                                                                     
                                                                                                                                                                                                                             
                                                                                                                                                                                                                        
                                                                                                                                                                                  
                                                                                                                                   
                                                                                                                                                                                                       
                                                                                                                                                                                                               
                                                                                                                                                                                                
                                                                                                                                                                        
                                                                                                                                                                                
                                                                                                                                                                                                                                                                                          
                                                                                                                                                                                                           
                                                                                                                                                                                
                                                                                                              

                                                
                                                                                                                                                                                       

                                                                  
                                                                                                             
                                    
                                                                   

                                                                                                                              
                                     

                                                                                                                                   
                                      

                                                                                                                                                                                 
                           

                                                                                                             
                                                                                                                     
                                                                  
                                                                   
                                                                                                                      
                                                   
                                                    
                                                                                                                          

                                                                                                                                                         
                                                                                                                                                        
                               

                                                                                                                              
                                                                                                                                                                                                     
                                                                                                                
#define IMGUI_ENABLE_FREETYPE

//---- Use FreeType + plutosvg or lunasvg to render OpenType SVG fonts (SVGinOT)
// Only works in combination with IMGUI_ENABLE_FREETYPE.
// - plutosvg is currently easier to install, as e.g. it is part of vcpkg. It will support more fonts and may load them faster. See misc/freetype/README for instructions.
// - Both require headers to be available in the include path + program to be linked with the library code (not provided).
// - (note: lunasvg implementation is based on Freetype's rsvg-port.c which is licensed under CeCILL-C Free Software License Agreement)
//#define IMGUI_ENABLE_FREETYPE_PLUTOSVG
//#define IMGUI_ENABLE_FREETYPE_LUNASVG

//---- Use stb_truetype to build and rasterize the font atlas (default)
// The only purpose of this define is if you want force compilation of the stb_truetype backend ALONG with the FreeType backend.
//#define IMGUI_ENABLE_STB_TRUETYPE

//---- Define constructor and implicit cast operators to convert back<>forth between your math types and ImVec2/ImVec4.
// This will be inlined as part of ImVec2 and ImVec4 class declarations.
/*
#define IM_VEC2_CLASS_EXTRA                                                     \
        constexpr ImVec2(const MyVec2& f) : x(f.x), y(f.y) {}                   \
        operator MyVec2() const { return MyVec2(x,y); }

#define IM_VEC4_CLASS_EXTRA                                                     \
        constexpr ImVec4(const MyVec4& f) : x(f.x), y(f.y), z(f.z), w(f.w) {}   \
        operator MyVec4() const { return MyVec4(x,y,z,w); }
*/
//---- ...Or use Dear ImGui's own very basic math operators.
#define IMGUI_DEFINE_MATH_OPERATORS

                                                                                                                  
                                                                                                                 
                                                                                                                     
                                                                 
                                

                                                                                            
                    
                   
                                                                                                                   
                                         

                                                                                                            
                                                                                                             
                                      
                                        

                                         
                              

                                                                                                                       
  
               
 
                                                       
 
  
