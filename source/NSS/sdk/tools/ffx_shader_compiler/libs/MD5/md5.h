#ifndef __MD5_H__
#define __MD5_H__

  
                                                                     
                                                                     
                                           
   
const unsigned int MD5_SIZE = (4 * sizeof(unsigned int));           
const unsigned int MD5_STRING_SIZE = 2 * MD5_SIZE + 1;              

 namespace md5 {
      
                                                                         
                                                                       
       
    const unsigned int BLOCK_SIZE = 64;

    class md5_t {
        public:
              
                    
              
                           
              
                                                                                   
                                                                                
                                                                        
                                                                                  
                                                                          
              
                       
              
                    
              
                         
              
                    
               
            md5_t();

              
                    
              
                           
              
                                                                                 
                                                                                 
                                                              
              
                       
              
                    
              
                         
              
                                                                                
              
                                                       
              
                                                                                 
               
            md5_t(const void* input, const unsigned int input_length, void* signature_ = NULL);

              
                      
              
                           
              
                                                                                     
                                         
              
                       
              
                    
              
                         
              
                                                                                
              
                                                       
               
            void process(const void* input, const unsigned int input_length);

              
                     
              
                           
              
                                                                              
                                                                        
                                                                             
                                                                        
              
                       
              
                    
              
                         
              
                                                                                 
               
            void finish(void* signature_ = NULL);

              
                      
              
                           
              
                                                                                 
              
                       
              
                    
              
                         
              
                                                                                 
               
            void get_sig(void* signature_);

              
                         
              
                           
              
                                                                                   
                                
              
                       
              
                    
              
                         
              
                                                                                   
                                                            
               
            void get_string(void* str_);

        private:
                                    
            void initialise();
            void process_block(const unsigned char*);
            void get_result(void*);

            unsigned int A;                                                
            unsigned int B;                                                
            unsigned int C;                                                
            unsigned int D;                                                

            unsigned int message_length[2];                                 
            unsigned int stored_size;                                               
            unsigned char stored[md5::BLOCK_SIZE * 2];                    

            bool finished;                                                

            char signature[MD5_SIZE];                                         
            char str[MD5_STRING_SIZE];                                              
    };

      
                    
      
                   
      
                                                                            
                      
      
               
      
            
      
                 
      
                                                                    
      
                                                                             
                                                 
      
                                          
       
    extern void sig_to_string(const void* signature, char* str, const int str_len);

      
                      
      
                   
      
                                                                            
                        
      
               
      
            
      
                 
      
                                                                        
      
                                                                            
                                
       
    extern void sig_from_string(void* signature, const char* str);
}                 

#endif                  
