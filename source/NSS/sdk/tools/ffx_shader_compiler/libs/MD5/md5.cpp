#include <cassert>
#include <cstring>
#include <iostream>

#include "md5.h"
#include "md5_loc.h"

namespace md5 {
                                                                                    

      
            
      
                   
      
                                                                           
                                                                        
                                                                
                                                                     
                                                                       
      
               
      
            
      
                 
      
            
       
    md5_t::md5_t() {
        initialise();
    }

      
            
      
                   
      
                                                                         
                                                                         
                                                      
      
               
      
            
      
                 
      
                                                                         
      
                                               
      
                                                                        
       
    md5_t::md5_t(const void* input, const unsigned int input_length, void* signature) {
                                                
        initialise();

                                                                          
        process(input, input_length);

                                               
        finish(signature);
    }

      
              
      
                   
      
                                                                            
                                 
      
               
      
            
      
                 
      
                                                                         
      
                                               
       
    void md5_t::process(const void* input, const unsigned int input_length) {
        if (!finished) {
            unsigned int processed = 0;

              
                                                                                           
                                                                                            
                                            
               
            if (stored_size && input_length + stored_size >= md5::BLOCK_SIZE) {
                unsigned char block[md5::BLOCK_SIZE];
                memcpy(block, stored, stored_size);
                memcpy(block + stored_size, input, md5::BLOCK_SIZE - stored_size);
                processed = md5::BLOCK_SIZE - stored_size;
                stored_size = 0;
                process_block(block);
            }

              
                                                                                 
               
            while (processed + md5::BLOCK_SIZE <= input_length) {
                process_block((unsigned char*)input + processed);
                processed += md5::BLOCK_SIZE;
            }

              
                                                                                               
                                                                  
               
            if (processed != input_length) {
                memcpy(stored + stored_size, (char*)input + processed, input_length - processed);
                stored_size += input_length - processed;
            } else {
                stored_size = 0;
            }
        } else {
                                                                   
        }
    }

      
             
      
                   
      
                                                                      
                                                                
                                                                     
                     
      
               
      
            
      
                 
      
                                                                        
       
    void md5_t::finish(void* signature_) {
        if (!finished) {
            if (message_length[0] + stored_size < message_length[0])
                message_length[1]++;
            message_length[0] += stored_size;

            int pad = md5::BLOCK_SIZE - (sizeof(unsigned int) * 2) - stored_size;
            if (pad <= 0)
                pad += md5::BLOCK_SIZE;

              
                                                                              
                                                            
               
            if (pad > 0) {
                stored[stored_size] = 0x80;
                if (pad > 1)
                    memset(stored + stored_size + 1, 0, pad - 1);
                stored_size += pad;
            }

              
                                                                               
                                                                        
               
            unsigned int size_low = ((message_length[0] & 0x1FFFFFFF) << 3);
            memcpy(stored + stored_size, &size_low, sizeof(unsigned int));
            stored_size += sizeof(unsigned int);

                                                                                      
            unsigned int size_high = (message_length[1] << 3) | ((message_length[0] & 0xE0000000) >> 29);
            memcpy(stored + stored_size, &size_high, sizeof(unsigned int));
            stored_size += sizeof(unsigned int);

              
                                              
                                                                                   
                                    
               
            process_block(stored);
            if (stored_size > md5::BLOCK_SIZE)
                process_block(stored + md5::BLOCK_SIZE);

                                                      
            get_result(static_cast<void*>(signature));

                                                           
            sig_to_string(signature, str, MD5_STRING_SIZE);

            if (signature_ != NULL) {
                memcpy(signature_, static_cast<void*>(signature), MD5_SIZE);
            }

            finished = true;
        } else {
                         
        }
    }

      
              
      
                   
      
                                                                         
      
               
      
            
      
                 
      
                                                                         
       
    void md5_t::get_sig(void* signature_) {
        if (finished) {
            memcpy(signature_, signature, MD5_SIZE);
        } else {
                    
        }
    }

      
                 
      
                   
      
                                                                           
                        
      
               
      
            
      
                 
      
                                                                           
                                                    
       
    void md5_t::get_string(void* str_) {
        if (finished) {
            memcpy(str_, str, MD5_STRING_SIZE);
        } else {
                     
        }
    }

                                                                                     

      
                 
      
                   
      
                                                                           
                    
      
               
      
            
      
                 
      
            
       
    void md5_t::initialise() {
          
                                                                                     
                                                          
           
        assert(MD5_SIZE == 16);

        A = 0x67452301;
        B = 0xefcdab89;
        C = 0x98badcfe;
        D = 0x10325476;

        message_length[0] = 0;
        message_length[1] = 0;
        stored_size = 0;

        finished = false;
    }

      
                    
      
                   
      
                                                           
      
               
      
            
      
                 
      
                                                                         
      
                                               
       
    void md5_t::process_block(const unsigned char* block) {
                                     

          
                                                                         
                                                                             
                                                                             
           
        if (message_length[0] + md5::BLOCK_SIZE < message_length[0])
            message_length[1]++;
        message_length[0] += BLOCK_SIZE;

                                    
        unsigned int X[16];
        for (unsigned int i = 0; i < 16; i++) {
            memcpy(X + i, block + 4 * i, 4);
        }

                                                          
        unsigned int AA = A, BB = B, CC = C, DD = D;

                  
                                                
                                                       
                                         
                                                                             
                                                                             
                                                                             
                                                                             
           
        md5::FF(A, B, C, D, X[0 ], 0, 0 );
        md5::FF(D, A, B, C, X[1 ], 1, 1 );
        md5::FF(C, D, A, B, X[2 ], 2, 2 );
        md5::FF(B, C, D, A, X[3 ], 3, 3 );
        md5::FF(A, B, C, D, X[4 ], 0, 4 );
        md5::FF(D, A, B, C, X[5 ], 1, 5 );
        md5::FF(C, D, A, B, X[6 ], 2, 6 );
        md5::FF(B, C, D, A, X[7 ], 3, 7 );
        md5::FF(A, B, C, D, X[8 ], 0, 8 );
        md5::FF(D, A, B, C, X[9 ], 1, 9 );
        md5::FF(C, D, A, B, X[10], 2, 10);
        md5::FF(B, C, D, A, X[11], 3, 11);
        md5::FF(A, B, C, D, X[12], 0, 12);
        md5::FF(D, A, B, C, X[13], 1, 13);
        md5::FF(C, D, A, B, X[14], 2, 14);
        md5::FF(B, C, D, A, X[15], 3, 15);

                  
                                                
                                                       
                                         
                                                                             
                                                                             
                                                                             
                                                                             
           
        md5::GG(A, B, C, D, X[1 ], 0, 16);
        md5::GG(D, A, B, C, X[6 ], 1, 17);
        md5::GG(C, D, A, B, X[11], 2, 18);
        md5::GG(B, C, D, A, X[0 ], 3, 19);
        md5::GG(A, B, C, D, X[5 ], 0, 20);
        md5::GG(D, A, B, C, X[10], 1, 21);
        md5::GG(C, D, A, B, X[15], 2, 22);
        md5::GG(B, C, D, A, X[4 ], 3, 23);
        md5::GG(A, B, C, D, X[9 ], 0, 24);
        md5::GG(D, A, B, C, X[14], 1, 25);
        md5::GG(C, D, A, B, X[3 ], 2, 26);
        md5::GG(B, C, D, A, X[8 ], 3, 27);
        md5::GG(A, B, C, D, X[13], 0, 28);
        md5::GG(D, A, B, C, X[2 ], 1, 29);
        md5::GG(C, D, A, B, X[7 ], 2, 30);
        md5::GG(B, C, D, A, X[12], 3, 31);

                  
                                                
                                                       
                                         
                                                                             
                                                                             
                                                                             
                                                                             
           
        md5::HH(A, B, C, D, X[5 ], 0, 32);
        md5::HH(D, A, B, C, X[8 ], 1, 33);
        md5::HH(C, D, A, B, X[11], 2, 34);
        md5::HH(B, C, D, A, X[14], 3, 35);
        md5::HH(A, B, C, D, X[1 ], 0, 36);
        md5::HH(D, A, B, C, X[4 ], 1, 37);
        md5::HH(C, D, A, B, X[7 ], 2, 38);
        md5::HH(B, C, D, A, X[10], 3, 39);
        md5::HH(A, B, C, D, X[13], 0, 40);
        md5::HH(D, A, B, C, X[0 ], 1, 41);
        md5::HH(C, D, A, B, X[3 ], 2, 42);
        md5::HH(B, C, D, A, X[6 ], 3, 43);
        md5::HH(A, B, C, D, X[9 ], 0, 44);
        md5::HH(D, A, B, C, X[12], 1, 45);
        md5::HH(C, D, A, B, X[15], 2, 46);
        md5::HH(B, C, D, A, X[2 ], 3, 47);

                  
                                                
                                                       
                                         
                                                                             
                                                                             
                                                                             
                                                                             
           
        md5::II(A, B, C, D, X[0 ], 0, 48);
        md5::II(D, A, B, C, X[7 ], 1, 49);
        md5::II(C, D, A, B, X[14], 2, 50);
        md5::II(B, C, D, A, X[5 ], 3, 51);
        md5::II(A, B, C, D, X[12], 0, 52);
        md5::II(D, A, B, C, X[3 ], 1, 53);
        md5::II(C, D, A, B, X[10], 2, 54);
        md5::II(B, C, D, A, X[1 ], 3, 55);
        md5::II(A, B, C, D, X[8 ], 0, 56);
        md5::II(D, A, B, C, X[15], 1, 57);
        md5::II(C, D, A, B, X[6 ], 2, 58);
        md5::II(B, C, D, A, X[13], 3, 59);
        md5::II(A, B, C, D, X[4 ], 0, 60);
        md5::II(D, A, B, C, X[11], 1, 61);
        md5::II(C, D, A, B, X[2 ], 2, 62);
        md5::II(B, C, D, A, X[9 ], 3, 63);

                                                                        
                                                                   
                        
        A += AA;
        B += BB;
        C += CC;
        D += DD;
    }

      
                 
      
                   
      
                                                                          
                            
      
               
      
            
      
                 
      
                                                                     
       
    void md5_t::get_result(void *result) {
        memcpy((char*)result, &A, sizeof(unsigned int));
        memcpy((char*)result + sizeof(unsigned int), &B, sizeof(unsigned int));
        memcpy((char*)result + 2 * sizeof(unsigned int), &C, sizeof(unsigned int));
        memcpy((char*)result + 3 * sizeof(unsigned int), &D, sizeof(unsigned int));
    }

                                                                                      

      
                    
      
                   
      
                                                                            
                      
      
               
      
            
      
                 
      
                                                                     
      
                                                                             
                                                 
      
                                          
       
    void sig_to_string(const void* signature_, char* str_, const int str_len) {
        unsigned char* sig_p;
        char* str_p;
        char* max_p;
        unsigned int high, low;

        str_p = str_;
        max_p = str_ + str_len;

        for (sig_p = (unsigned char*)signature_; sig_p < (unsigned char*)signature_ + MD5_SIZE; sig_p++) {
            high = *sig_p / 16;
            low = *sig_p % 16;
                                     
            if (str_p + 1 >= max_p) {
                break;
            }
            *str_p++ = md5::HEX_STRING[high];
            *str_p++ = md5::HEX_STRING[low];
        }
                                 
        if (str_p < max_p) {
            *str_p++ = '\0';
        }
    }

      
                      
      
                   
      
                                                                            
                        
      
               
      
            
      
                 
      
                                                                         
      
                                                                             
                                
       
    void sig_from_string(void* signature_, const char* str_) {
        unsigned char *sig_p;
        const char *str_p;
        char* hex;
        unsigned int high, low, val;

        hex = (char*)md5::HEX_STRING;
        sig_p = static_cast<unsigned char*>(signature_);

        for (str_p = str_; str_p < str_ + MD5_SIZE * 2; str_p += 2) {
            high = strchr(hex, *str_p) - hex;
            low = strchr(hex, *(str_p + 1)) - hex;
            val = high * 16 + low;
            *sig_p++ = val;
        }
    }
}                 

